#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM_PATH="${PLATFORM_PATH:-}"
PORT="${PORT:-8089}"
TIMEOUT="${TIMEOUT:-1500}"

NAME="forumify-smoke-test"
IMAGE="$NAME:latest"
WORKDIR="$(mktemp -d)"

cleanup() {
    local status=$?
    if docker inspect "$NAME" >/dev/null 2>&1; then
        echo "::group::forumify container logs"
        docker logs "$NAME" 2>&1 | grep -v 'webpack.Progress' || true
        echo "::endgroup::"
    fi
    docker rm -f "$NAME" "$NAME-mysql" >/dev/null 2>&1 || true
    docker network rm "$NAME" >/dev/null 2>&1 || true
    rm -rf "$WORKDIR"
    exit "$status"
}
trap cleanup EXIT

fail() {
    echo "::error::$1"
    exit 1
}

echo "==> Building image"
docker build -t "$IMAGE" "$ROOT"

echo "==> Starting MySQL"
docker network create "$NAME" >/dev/null
docker run -d --name "$NAME-mysql" --network "$NAME" \
    -e MYSQL_ROOT_PASSWORD=root \
    --health-cmd='mysqladmin ping -proot' --health-interval=2s --health-retries=60 \
    mysql:8.4 >/dev/null

until [ "$(docker inspect -f '{{.State.Health.Status}}' "$NAME-mysql")" = "healthy" ]; do
    sleep 2
done

echo "==> Creating forumify container"
env_args=(
    -e APP_SECRET=smoke-test-secret
    -e "DATABASE_URL=mysql://root:root@$NAME-mysql:3306/forumify?serverVersion=8.4.0"
    -e MAILER_DSN=null://null
)
if [ -n "${GITHUB_TOKEN:-}" ]; then
    env_args+=(-e "COMPOSER_AUTH={\"github-oauth\":{\"github.com\":\"$GITHUB_TOKEN\"}}")
fi
docker create --name "$NAME" --network "$NAME" -p "$PORT:80" "${env_args[@]}" "$IMAGE" >/dev/null

if [ -n "$PLATFORM_PATH" ]; then
    PLATFORM_PATH="$(cd "$PLATFORM_PATH" && pwd)"
    version="$(jq -r '.extra["branch-alias"]["dev-master"]' "$PLATFORM_PATH/composer.json")"
    echo "==> Installing forumify-platform from $PLATFORM_PATH as $version"

    jq --arg version "$version" '
        .repositories = [{
            "type": "path",
            "url": "/platform",
            "options": {"symlink": false, "versions": {"forumify/forumify-platform": $version}}
        }]
        | .require["forumify/forumify-platform"] = $version
    ' "$ROOT/composer.json" > "$WORKDIR/composer.json"
    docker cp "$WORKDIR/composer.json" "$NAME:/usr/src/app.bak/composer.json"

    tar -C "$PLATFORM_PATH" \
        --exclude=./.git --exclude=./vendor --exclude=./node_modules --exclude=./assets/node_modules --exclude=./var \
        --transform='s,^\./,platform/,;s,^\.$,platform,' \
        -cf - . | docker cp - "$NAME:/"
fi

echo "==> Launching forumify"
docker start "$NAME" >/dev/null

deadline=$((SECONDS + TIMEOUT))
while true; do
    if [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" != "true" ]; then
        fail "forumify container exited during startup"
    fi

    code="$(curl -s -o "$WORKDIR/index.html" -w '%{http_code}' "http://localhost:$PORT/" || true)"
    case "$code" in
        200) break ;;
        000 | 502 | 503 | 504) ;;
        *) fail "GET / returned HTTP $code" ;;
    esac

    if [ "$SECONDS" -ge "$deadline" ]; then
        fail "forumify did not come up within ${TIMEOUT}s"
    fi
    sleep 5
done
echo "==> GET / returned HTTP 200"

assets="$(grep -o '/build/[^"]*' "$WORKDIR/index.html" | sort -u || true)"
if [ -z "$assets" ]; then
    fail "the page does not reference any compiled assets"
fi

for asset in $assets; do
    code="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT$asset")"
    if [ "$code" != "200" ]; then
        fail "GET $asset returned HTTP $code"
    fi
    echo "    $asset"
done

echo "==> forumify launched successfully from scratch"
