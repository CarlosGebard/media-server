#!/usr/bin/env bash
set -euo pipefail

: "${PROD_HOST:?Missing PROD_HOST}"

INVENTORY_PATH="${INVENTORY_PATH:-/tmp/deploy-hosts.yml}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/deploy_key}"
SSH_PORT="${PROD_SSH_PORT:-22}"
SSH_USER="${DEPLOY_SSH_USER:-carlos}"

printf '%s\n' \
  'all:' \
  '  hosts:' \
  '    deploy_target:' \
  "      ansible_host: ${PROD_HOST}" \
  "      ansible_user: ${SSH_USER}" \
  "      ansible_port: ${SSH_PORT}" \
  "      ansible_ssh_private_key_file: ${SSH_KEY_PATH}" \
  > "$INVENTORY_PATH"
