# Media Deploy Runbook

## Local Validation

Create local data dirs:

```bash
mkdir -p compose/.tmp/media/immich/app
mkdir -p compose/.tmp/media/immich/postgres
mkdir -p compose/.tmp/media/couchdb/data
mkdir -p compose/.tmp/media/nextcloud/html
mkdir -p compose/.tmp/media/nextcloud/mariadb
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
curl -fsS "http://carlos:devpassword@127.0.0.1:15984/_up"
curl -fsS http://127.0.0.1:18080/status.php
```

## Production Secret

Create `/srv/secrets/runtime/media.env` from `compose/env/media.env.example`.

Normal production path: GitHub Actions pulls secrets from Infisical via OIDC, materializes `/tmp/media-runtime.env`, and Ansible copies it to `/srv/secrets/runtime/media.env`.

Required Infisical secrets:

- `PROD_HOST`
- `PROD_SSH_PRIVATE_KEY`
- `IMMICH_DB_PASSWORD`
- `COUCHDB_PASSWORD`
- `NEXTCLOUD_ADMIN_PASSWORD`
- `NEXTCLOUD_DB_PASSWORD`
- `NEXTCLOUD_DB_ROOT_PASSWORD`
- `BITWARDEN_DB_PASSWORD`
- `BITWARDEN_INSTALLATION_ID`
- `BITWARDEN_INSTALLATION_KEY`
- `BITWARDEN_SMTP_PASSWORD`
- `BITWARDEN_DISABLE_USER_REGISTRATION`

Optional Infisical secrets:

- `PROD_SSH_PORT`
- `PROD_SSH_KNOWN_HOSTS`
- `IMMICH_VERSION`

`PROD_SSH_KNOWN_HOSTS` is optional. If missing, workflow uses `ssh-keyscan`, matching `infra-victus`.

`IMMICH_VERSION` defaults to `v2`, the current Immich major-version metatag. Deploy pulls images before `up -d`, so redeploy updates to the latest image available for that tag.

Rules:

- File mode `0600`.
- Keep `IMMICH_DB_PASSWORD` alphanumeric unless Docker interpolation has been tested.
- Set `NGINX_BIND_IP=0.0.0.0` only when firewall, DNS, and TLS posture are understood.
- Set `NGINX_HTTP_PORT=80` for Immich edge.
- Set `NGINX_HTTPS_PORT=443` for HTTPS edge.
- Create the `cloud.carlosjg.space` DNS record before the first deploy. Certbot
  requests one certificate for all media public domains, so a missing record
  prevents certificate issuance.
- Do not commit production values.

The deploy removes the retired `infisical`, `infisical_postgres`, and
`infisical_redis` containers. It deliberately preserves the former PostgreSQL
directory at `/srv/data/media/infisical/postgres`; archive it before deleting it
manually after recovery is no longer needed.

## Production Permissions

Ansible owns bind-mounted service data with container UIDs:

```bash
/srv/data/media/immich/postgres
/srv/data/media/couchdb/data
/srv/data/media/nextcloud/html
/srv/data/media/nextcloud/mariadb
```

Required ownership:

- Immich Postgres data: `999:999`
- CouchDB data: `5984:5984`
- Nextcloud HTML/data: `33:33` (`www-data`)
- Nextcloud MariaDB data: `999:999`

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
  -f compose.yml -f compose.prod.yml ps
curl -fsS http://127.0.0.1/healthz
curl -fsS "https://USER:PASS@couchdb.carlosjg.space/_up"
curl -fsS https://cloud.carlosjg.space/status.php
docker compose --env-file /srv/secrets/runtime/media.env \
  -f compose.yml -f compose.prod.yml exec -T --user www-data nextcloud \
  php occ status --output=json
```

Expected public ports:

- `80/tcp` -> ACME challenge and HTTP-to-HTTPS redirect.
- `443/tcp` -> Immich, CouchDB, and Nextcloud through NGINX.

No Tailscale dependency exists for this stack.

NGINX reaches application services by their Docker service names. Do not assign
static container IPs. Proxy-aware applications trust only the CIDR of their
private Docker network, so a recreated NGINX container receives a safe dynamic
address without changing the proxy trust boundary.

## Nextcloud Operations

Nextcloud runs with dedicated MariaDB and Valkey services on a private Docker
network. NGINX is the only service connected to both the public media network
and the Nextcloud network.

The Nextcloud application and cron containers also attach to a dedicated egress
network so that update checks, app catalog access, federated features, and
outbound notifications can reach the internet. MariaDB and Valkey remain on the
internal Nextcloud network only.

Background jobs run through the `nextcloud-cron` container. Confirm the
scheduler is configured after initial deployment:

```bash
cd /srv/apps/media
docker compose --env-file /srv/secrets/runtime/media.env \
  -f compose.yml -f compose.prod.yml exec -T --user www-data nextcloud \
  php occ background:cron
```

After deploying Nextcloud configuration changes, clear the common setup
warnings from the production host:

```bash
cd /srv/apps/media

docker compose --env-file /srv/secrets/runtime/media.env \
  -f compose.yml -f compose.prod.yml exec -T --user www-data nextcloud \
  php occ config:system:set maintenance_window_start --type=integer --value=7

docker compose --env-file /srv/secrets/runtime/media.env \
  -f compose.yml -f compose.prod.yml exec -T --user www-data nextcloud \
  php occ config:system:set default_phone_region --value=CL

docker compose --env-file /srv/secrets/runtime/media.env \
  -f compose.yml -f compose.prod.yml exec -T --user www-data nextcloud \
  php occ config:system:set serverid --type=integer --value=0
```

Run the expensive mimetype repair in a low-usage window after confirming recent
backups for `/srv/data/media/nextcloud/html` and MariaDB:

```bash
cd /srv/apps/media

docker compose --env-file /srv/secrets/runtime/media.env \
  -f compose.yml -f compose.prod.yml exec -T --user www-data nextcloud \
  php occ maintenance:repair --include-expensive
```

Inspect the actual Nextcloud log errors before changing AppAPI, SMTP, or 2FA
policy:

```bash
cd /srv/apps/media

docker compose --env-file /srv/secrets/runtime/media.env \
  -f compose.yml -f compose.prod.yml exec -T --user www-data nextcloud \
  php occ log:tail
```

The cron container starts only after the Nextcloud health check confirms that
`occ` is installed. This prevents a first-deploy race against the persistent
HTML directory initialization.

Back up `/srv/data/media/nextcloud/html` and a consistent MariaDB dump before
upgrading Nextcloud. Restore both together; restoring user files without the
database, or vice versa, leaves file metadata inconsistent.

## Bitwarden Setup

Create a DNS record for `vault.carlosjg.space`
before the manual deploy, otherwise the shared Certbot certificate cannot be
issued. Run the `Debug Infisical OIDC` workflow first; deploy remains manual
until it reports success.

After the first Bitwarden deployment, create the initial account at
`https://vault.carlosjg.space`, then change
`BITWARDEN_DISABLE_USER_REGISTRATION` to `true` in the runtime configuration
before the next manual deploy. Bitwarden sends mail through the configured
Resend SMTP relay.

Bitwarden uses a private internal network for MariaDB and a dedicated egress
network for outbound SMTP. Keep `bitwarden-db` off the egress network.

Default SMTP values are Resend-compatible:

```text
BITWARDEN_SMTP_HOST=smtp.resend.com
BITWARDEN_SMTP_PORT=465
BITWARDEN_SMTP_SSL=true
BITWARDEN_SMTP_USERNAME=resend
BITWARDEN_SMTP_PASSWORD=<Resend API key>
BITWARDEN_SMTP_FROM_EMAIL=vault@carlosjg.space
```

If mail fails, verify that the Resend API key is active, the sender domain is
verified, and the from address belongs to that verified domain. Then inspect the
Bitwarden logs from the production host:

```bash
cd /srv/apps/media

docker compose --env-file /srv/secrets/runtime/media.env \
  -f compose.yml -f compose.prod.yml logs --tail=200 bitwarden
```

## Extracted Wiki.js

Wiki.js was removed from the `media` deployment.

Previous production location:

```text
/srv/apps/media/compose.wiki.yml
/srv/apps/media/compose.wiki.prod.yml
/srv/data/media/wiki/postgres
```

The portable Compose files now live under:

```text
wikijs-infra/
```

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
