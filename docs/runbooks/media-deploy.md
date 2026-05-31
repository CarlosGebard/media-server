# Media Deploy Runbook

## Local Validation

Create local data dirs:

```bash
mkdir -p compose/.tmp/media/immich/app
mkdir -p compose/.tmp/media/immich/postgres
mkdir -p compose/.tmp/media/couchdb/data
```

Validate Compose:

```bash
./compose/scripts/validate-compose.sh
```

Start local stack:

```bash
docker compose --env-file compose/projects/media/.env \
  -f compose/projects/media/compose.yml \
  -f compose/projects/media/compose.dev.yml up -d
```

Check local edge:

```bash
curl -fsS http://127.0.0.1:8080/healthz
curl -fsS "http://admin:devpassword@127.0.0.1:15984/_up"
```

## Production Secret

Create `/srv/secrets/runtime/media.env` from `compose/env/media.env.example`.

Normal production path: GitHub Actions pulls secrets from Infisical via OIDC, materializes `/tmp/media-runtime.env`, and Ansible copies it to `/srv/secrets/runtime/media.env`.

Required Infisical secrets:

- `PROD_HOST`
- `PROD_SSH_PRIVATE_KEY`
- `DB_PASSWORD`
- `COUCHDB_USER`
- `COUCHDB_PASSWORD`

Optional Infisical secrets:

- `PROD_SSH_PORT`
- `PROD_SSH_KNOWN_HOSTS`
- `IMMICH_VERSION`

`PROD_SSH_KNOWN_HOSTS` is optional. If missing, workflow uses `ssh-keyscan`, matching `infra-victus`.

`IMMICH_VERSION` defaults to `v2`, the current Immich major-version metatag. Deploy pulls images before `up -d`, so redeploy updates to the latest image available for that tag.

Rules:

- File mode `0600`.
- Keep `DB_PASSWORD` alphanumeric unless Docker interpolation has been tested.
- Set `NGINX_BIND_IP=0.0.0.0` only when firewall, DNS, and TLS posture are understood.
- Set `NGINX_HTTP_PORT=80` for Immich edge.
- Set `NGINX_HTTPS_PORT=443` for HTTPS edge.
- Do not commit production values.

## Production Permissions

Ansible owns bind-mounted service data with container UIDs:

```bash
/srv/data/media/immich/postgres
/srv/data/media/couchdb/data
```

Required ownership:

- Immich Postgres data: `999:999`
- CouchDB data: `5984:5984`

This is required because both containers run as non-root users and must create/read database files inside bind-mounted host directories.

Immich app storage is mounted as `/data`:

```bash
/srv/data/media/immich/app
```

Immich creates these folders below that root:

- `backups`
- `encoded-video`
- `library`
- `profile`
- `thumbs`
- `upload`

## Production Deploy

```bash
MEDIA_RUNTIME_ENV_SOURCE_FILE=/path/to/media.env \
ansible-playbook -i ansible/inventories/production/hosts.yml \
  ansible/playbooks/deploy-media.yml
```

## Production Checks

Run from host after deploy:

```bash
cd /srv/apps/media
docker compose --env-file /srv/secrets/runtime/media.env \
  -f compose.yml -f compose.wiki.yml -f compose.prod.yml -f compose.wiki.prod.yml ps
curl -fsS http://127.0.0.1/healthz
curl -fsS "https://USER:PASS@couchdb.carlosjg.space/_up"
curl -fsS "https://docs.carlosjg.space"
```

Expected public ports:

- `80/tcp` -> ACME challenge and HTTP-to-HTTPS redirect.
- `443/tcp` -> Immich and CouchDB through NGINX.
- `443/tcp` -> Immich, CouchDB, and Wiki.js through NGINX.

No Tailscale dependency exists for this stack.

## CouchDB Migration

1. Backup old CouchDB data.
2. Stop old `personal` CouchDB stack.
3. Copy or restore data into `/srv/data/media/couchdb/data`.
4. Ensure ownership matches container user `5984:5984`.
5. Deploy `media`.
6. Verify through NGINX:

```bash
curl -fsS "https://USER:PASS@couchdb.carlosjg.space/_up"
```

Rollback:

1. Stop new `media` CouchDB.
2. Restart old `personal` stack.
3. Restore backup if writes occurred after migration test.
