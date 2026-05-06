#!/usr/bin/env bash
set -euo pipefail

: "${PROD_HOST:?Missing PROD_HOST}"
: "${PROD_SSH_PRIVATE_KEY:?Missing PROD_SSH_PRIVATE_KEY}"

SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/deploy_key}"
SSH_PORT="${PROD_SSH_PORT:-22}"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

printf '%s\n' "$PROD_SSH_PRIVATE_KEY" > "$SSH_KEY_PATH"
chmod 600 "$SSH_KEY_PATH"

if [[ -n "${PROD_SSH_KNOWN_HOSTS:-}" ]]; then
  printf '%s\n' "$PROD_SSH_KNOWN_HOSTS" > "$HOME/.ssh/known_hosts"
else
  ssh-keyscan -p "$SSH_PORT" -H "$PROD_HOST" >> "$HOME/.ssh/known_hosts"
fi

chmod 644 "$HOME/.ssh/known_hosts"
