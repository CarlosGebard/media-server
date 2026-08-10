#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_ENV="$SCRIPT_DIR/upload-immich-library.local.env"

if [[ -f "$LOCAL_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_ENV"
fi

BASE="${BASE:-/home/carlos/Downloads/Imagenes-OneDrive/Imágenes}"
SERVER_URL="${SERVER_URL:-https://immich.carlosjg.space/api}"
API_KEY="${API_KEY:?Set API_KEY before running this script}"
CONCURRENCY="${CONCURRENCY:-8}"
CLI_IMAGE="${CLI_IMAGE:-ghcr.io/immich-app/immich-cli:latest}"
DRY_RUN="${DRY_RUN:-0}"

extra_args=()
if [[ "$DRY_RUN" == "1" ]]; then
  extra_args+=(--dry-run)
fi

upload_album() {
  local src="$1"
  local album="$2"

  [[ -d "$src" ]] || return 0

  printf '\n== Album: %s ==\n' "$album"
  docker run --rm \
    -v "$src:/import:ro" \
    "$CLI_IMAGE" \
    upload \
      --url "$SERVER_URL" \
      --key "$API_KEY" \
      --recursive \
      --concurrency "$CONCURRENCY" \
      --album-name "$album" \
      "${extra_args[@]}" \
      /import
}

printf '== Upload Photos by year ==\n'
for y in "$BASE"/Photos/[0-9][0-9][0-9][0-9]; do
  [[ -d "$y" ]] || continue
  upload_album "$y" "Photos $(basename "$y")"
done

printf '\n== Upload Videos by year ==\n'
for y in "$BASE"/Videos/[0-9][0-9][0-9][0-9]; do
  [[ -d "$y" ]] || continue
  upload_album "$y" "Videos $(basename "$y")"
done

upload_album "$BASE/memes" "Memes"
upload_album "$BASE/Motivacion" "Motivacion"

printf '\n== Import complete ==\n'
