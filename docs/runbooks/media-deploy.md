# Media Deploy Runbook

## Local Validation

Create local data dirs:

```bash
mkdir -p compose/.tmp/media/immich/library
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
- Set `NGINX_COUCHDB_PORT=5984` for CouchDB edge.
- Do not commit production values.

## Production Permissions

Ansible owns CouchDB data as UID/GID `5984:5984`:

```bash
/srv/data/media/couchdb/data
```

This is required because the CouchDB container runs as `5984:5984` and must create `_nodes.couch`, `_dbs.couch`, and user databases there.

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
  -f compose.yml -f compose.prod.yml ps
curl -fsS http://127.0.0.1/healthz
curl -fsS "http://USER:PASS@127.0.0.1:5984/_up"
```

Expected public ports:

- `80/tcp` -> Immich through NGINX.
- `5984/tcp` -> CouchDB through NGINX.

No Tailscale dependency exists for this stack.

## CouchDB Migration

1. Backup old CouchDB data.
2. Stop old `personal` CouchDB stack.
3. Copy or restore data into `/srv/data/media/couchdb/data`.
4. Ensure ownership matches container user `5984:5984`.
5. Deploy `media`.
6. Verify through NGINX:

```bash
curl -fsS "http://USER:PASS@127.0.0.1:${NGINX_COUCHDB_PORT:-5984}/_up"
```

Rollback:

1. Stop new `media` CouchDB.
2. Restart old `personal` stack.
3. Restore backup if writes occurred after migration test.
