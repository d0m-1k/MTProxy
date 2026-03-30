#!/bin/sh
set -eu

MT_USER="${MT_USER:-nobody}"
MT_PORT="${MT_PORT:-1443}"
MT_STATS_PORT="${MT_STATS_PORT:-8888}"
MT_WORKERS="${MT_WORKERS:-1}"
MT_SECRET="${MT_SECRET:-}"
MT_PROXY_TAG="${MT_PROXY_TAG:-}"
MT_CONFIG_UPDATE_INTERVAL="${MT_CONFIG_UPDATE_INTERVAL:-86400}"

STATE_DIR="${STATE_DIR:-/var/lib/mtproxy}"
PROXY_SECRET_FILE="${PROXY_SECRET_FILE:-$STATE_DIR/proxy-secret}"
PROXY_CONFIG_FILE="${PROXY_CONFIG_FILE:-$STATE_DIR/proxy-multi.conf}"

PROXY_SECRET_URL="${PROXY_SECRET_URL:-https://core.telegram.org/getProxySecret}"
PROXY_CONFIG_URL="${PROXY_CONFIG_URL:-https://core.telegram.org/getProxyConfig}"

mkdir -p "$STATE_DIR"

if [ -z "$MT_SECRET" ]; then
  echo "ERROR: MT_SECRET is empty. Set it in .env" >&2
  exit 1
fi

update_file() {
  url="$1"
  target="$2"
  tmp="${target}.tmp"
  if curl -fsSL "$url" -o "$tmp" && [ -s "$tmp" ]; then
    mv "$tmp" "$target"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

if [ ! -s "$PROXY_SECRET_FILE" ]; then
  echo "Fetching proxy-secret..."
  update_file "$PROXY_SECRET_URL" "$PROXY_SECRET_FILE" || {
    echo "ERROR: failed to fetch proxy-secret" >&2
    exit 1
  }
fi

if [ ! -s "$PROXY_CONFIG_FILE" ]; then
  echo "Fetching proxy-multi.conf..."
  update_file "$PROXY_CONFIG_URL" "$PROXY_CONFIG_FILE" || {
    echo "ERROR: failed to fetch proxy-multi.conf" >&2
    exit 1
  }
fi

updater_pid=""
if [ "$MT_CONFIG_UPDATE_INTERVAL" -gt 0 ] 2>/dev/null; then
  (
    while :; do
      sleep "$MT_CONFIG_UPDATE_INTERVAL"
      if update_file "$PROXY_CONFIG_URL" "$PROXY_CONFIG_FILE"; then
        echo "proxy-multi.conf updated"
      else
        echo "WARN: proxy-multi.conf update failed" >&2
      fi
    done
  ) &
  updater_pid="$!"
fi

cleanup() {
  if [ -n "$updater_pid" ] && kill -0 "$updater_pid" 2>/dev/null; then
    kill "$updater_pid" 2>/dev/null || true
  fi
}
trap cleanup INT TERM EXIT

set -- \
  -u "$MT_USER" \
  -p "$MT_STATS_PORT" \
  -H "$MT_PORT" \
  -S "$MT_SECRET" \
  --aes-pwd "$PROXY_SECRET_FILE" "$PROXY_CONFIG_FILE" \
  -M "$MT_WORKERS"

if [ -n "$MT_PROXY_TAG" ]; then
  set -- "$@" -P "$MT_PROXY_TAG"
fi

exec /usr/local/bin/mtproto-proxy "$@"
