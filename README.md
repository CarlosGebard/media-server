# personal-media

IaC for personal media services.

Main stack:

- Immich
- Immich machine learning
- Valkey
- Immich Postgres vector database
- CouchDB
- Nextcloud with MariaDB and Valkey
- Bitwarden Lite with MariaDB
- Infisical with PostgreSQL and Redis
- NGINX public edge

Runtime source of truth is Docker Compose. Ansible only stages files, asserts secrets, and runs Compose.
Production secrets are pulled from Infisical through GitHub Actions OIDC.

## Local

```bash
make validate
make up
```

Local edge:

- Immich: `http://127.0.0.1:8080`
- CouchDB through NGINX: `http://127.0.0.1:15984`
- CouchDB direct dev port: `http://127.0.0.1:5984`
- Nextcloud through NGINX: `http://127.0.0.1:18080`
- Bitwarden through NGINX: `http://127.0.0.1:18081`
- Infisical through NGINX: `http://127.0.0.1:18082`

## Production

Stage secrets outside git:

```bash
/srv/secrets/runtime/media.env
```

Then deploy:

```bash
ansible-playbook -i ansible/inventories/production/hosts.yml ansible/playbooks/deploy-media.yml
```

Production edge:

- Immich is exposed at `https://immich.carlosjg.space`.
- CouchDB is exposed at `https://couchdb.carlosjg.space`.
- Nextcloud is exposed at `https://cloud.carlosjg.space`.
- Bitwarden is exposed at `https://vault.carlosjg.space`.
- Infisical is exposed at `https://secrets.carlosjg.space`.
- HTTP on `80/tcp` is kept for ACME challenge and redirect.
- Tailscale is not part of this stack.

## Notes

- Do not commit real `.env` production values.
- Infisical secret contract is documented in `docs/secrets-and-variables.md`.
- `IMMICH_VERSION` defaults to `v2`; deploy pulls images before starting containers.
- Keep Immich upgrades deliberate; check upstream release notes before changing `IMMICH_VERSION`.
- Keep CouchDB credentials strong because service is exposed.
- Keep Nextcloud major-version upgrades deliberate; `NEXTCLOUD_VERSION` defaults to `34-apache`.
- CouchDB migration from old infra is documented in `docs/runbooks/media-deploy.md`.
- Wiki.js was extracted from the media stack; its standalone package lives under `wikijs-infra/`.

## Storage

Production layout:

```text
/srv/data/media/immich/app       # Immich /data root
/srv/data/media/immich/postgres  # Immich Postgres
/srv/data/media/couchdb/data     # CouchDB
/srv/data/media/nextcloud/html   # Nextcloud application, config, and user files
/srv/data/media/nextcloud/mariadb # Nextcloud MariaDB
/srv/data/media/bitwarden/data   # Bitwarden application data
/srv/data/media/bitwarden/mariadb # Bitwarden MariaDB
/srv/data/media/infisical/postgres # Infisical PostgreSQL
```

Immich creates `library`, `upload`, `thumbs`, `profile`, `encoded-video`, and `backups` under `/srv/data/media/immich/app`.
