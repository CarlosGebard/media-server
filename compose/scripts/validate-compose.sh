#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { echo "[INFO] $*"; }
err() {
	echo "[ERROR] $*" >&2
	exit 1
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || err "Missing command: $1"
}

require_file() {
	local path="$1"
	[[ -f "$path" ]] || err "Missing file: $path"
}

require_dir() {
	local path="$1"
	[[ -d "$path" ]] || err "Missing dir: $path"
}

validate_stack() {
	local stack_dir="$ROOT_DIR/compose/projects/media"
	local env_file="$stack_dir/.env"
	local compose_base="$stack_dir/compose.yml"
	local compose_wiki="$stack_dir/compose.wiki.yml"
	local compose_overlay="$stack_dir/compose.dev.yml"
	local compose_wiki_overlay="$stack_dir/compose.wiki.dev.yml"

	require_file "$env_file"
	require_file "$compose_base"
	require_file "$compose_wiki"
	require_file "$compose_overlay"
	require_file "$compose_wiki_overlay"

	log "media: docker compose config"
	docker compose --env-file "$env_file" -f "$compose_base" -f "$compose_wiki" -f "$compose_overlay" -f "$compose_wiki_overlay" config >/dev/null
}

validate_nginx() {
	local nginx_conf="$ROOT_DIR/compose/configs/nginx/nginx.conf"
	local nginx_conf_dir="$ROOT_DIR/compose/configs/nginx/conf.d"

	require_file "$nginx_conf"
	require_dir "$nginx_conf_dir"

	log "nginx: nginx -t"
	docker run --rm \
		--add-host immich-server:127.0.0.1 \
		--add-host couchdb:127.0.0.1 \
		--add-host wiki:127.0.0.1 \
		-v "$nginx_conf:/etc/nginx/nginx.conf:ro" \
		-v "$nginx_conf_dir:/etc/nginx/conf.d:ro" \
		nginx:1.28.3-alpine nginx -t
}

validate_required_dirs() {
	local dirs=(
		"$ROOT_DIR/compose/.tmp/media/immich/app"
		"$ROOT_DIR/compose/.tmp/media/immich/postgres"
		"$ROOT_DIR/compose/.tmp/media/couchdb/data"
		"$ROOT_DIR/compose/.tmp/media/wiki/postgres"
	)

	for dir in "${dirs[@]}"; do
		require_dir "$dir"
	done
}

require_cmd docker
validate_stack
validate_required_dirs
validate_nginx

log "Local validation OK"
