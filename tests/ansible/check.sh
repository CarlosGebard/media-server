#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

command -v ansible-playbook >/dev/null 2>&1 || {
  echo "Missing ansible-playbook in PATH" >&2
  exit 1
}

bash "$ROOT_DIR/tests/ansible/deploy-media-syntax-check.sh"

echo "personal-media Ansible integrity checks OK"
