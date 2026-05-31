# personal-media

IaC for personal media services.

Main stack:

- Immich
- Immich machine learning
- Valkey
- Immich Postgres vector database
- CouchDB
- Wiki.js
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
- Wiki.js through NGINX: `http://127.0.0.1:13000`
- Wiki.js direct dev port: `http://127.0.0.1:3000`

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
- Wiki.js is exposed at `https://docs.carlosjg.space`.
- HTTP on `80/tcp` is kept for ACME challenge and redirect.
- Tailscale is not part of this stack.

## Notes

- Do not commit real `.env` production values.
- Infisical secret contract is documented in `docs/secrets-and-variables.md`.
- `IMMICH_VERSION` defaults to `v2`; deploy pulls images before starting containers.
- Keep Immich upgrades deliberate; check upstream release notes before changing `IMMICH_VERSION`.
- Keep CouchDB credentials strong because service is exposed.
- CouchDB migration from old infra is documented in `docs/runbooks/media-deploy.md`.

## Storage

Production layout:

```text
/srv/data/media/immich/app       # Immich /data root
/srv/data/media/immich/postgres  # Immich Postgres
/srv/data/media/couchdb/data     # CouchDB
/srv/data/media/wiki/postgres    # Wiki.js Postgres
```

Immich creates `library`, `upload`, `thumbs`, `profile`, `encoded-video`, and `backups` under `/srv/data/media/immich/app`.
