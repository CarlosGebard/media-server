# PLANS.md

## Goal

Create a new `personal-media` IaC repository based on `infra-victus` conventions. Main runtime is Immich; CouchDB moves from old `personal` stack into this repo. Docker Compose remains source of truth, Ansible handles host setup and deploy, secrets stay outside git.

## Scope

- Scaffold repo structure for Compose, Ansible, docs, and validation scripts.
- Add `media` stack with Immich services: server, machine-learning, Redis-compatible Valkey, and Postgres vector image.
- Add CouchDB to same `media` stack using existing config conventions.
- Add Wiki.js as a portable Compose module in the same deployed stack.
- Add NGINX edge inside the `media` stack.
- Support local dev paths under `compose/.tmp`.
- Support production paths under `/srv/apps`, `/srv/data`, `/srv/secrets`.
- Add deploy role/playbook pattern matching `infra-victus`.
- Add checks for Compose render, NGINX config, Ansible syntax, edge reachability, and CouchDB migration.
- Add runbook for local validation, prod deploy, public exposure, and CouchDB migration.

## Non-goals

- No automatic migration of live CouchDB data yet.
- No full multi-stack deploy orchestrator yet.
- No Tailscale/private-only exposure.
- No automatic TLS/certbot automation yet.
- No GPU/hardware acceleration for Immich yet.
- No backup automation yet.

## Likely Files

- `AGENTS.md`
- `PLANS.md`
- `README.md`
- `compose/projects/media/compose.yml`
- `compose/projects/media/compose.dev.yml`
- `compose/projects/media/compose.prod.yml`
- `compose/projects/media/.env`
- `compose/env/media.env.example`
- `compose/configs/couchdb/local.d/local.ini`
- `compose/configs/nginx/nginx.conf`
- `compose/configs/nginx/conf.d/media.conf`
- `compose/scripts/validate-compose.sh`
- `.github/workflows/validate-infra.yml`
- `.github/workflows/deploy-media.yml`
- `.github/scripts/prepare-ssh.sh`
- `.github/scripts/build-deploy-inventory.sh`
- `tests/ansible/check.sh`
- `docs/secrets-and-variables.md`
- `ansible/playbooks/deploy-media.yml`
- `ansible/roles/deploy/media/tasks/main.yml`
- `ansible/inventories/production/group_vars/host-contract.yml`
- `ansible/inventories/production/group_vars/deploy.yml`
- `docs/adr/0001-personal-media-stack-boundary.md`
- `docs/runbooks/media-deploy.md`

## Assumptions

- Server filesystem follows `/srv/apps`, `/srv/data`, `/srv/logs`, `/srv/secrets`, `/srv/backups`.
- Runtime env is staged at `/srv/secrets/runtime/media.env`.
- GitHub Actions pulls production secrets from Infisical via OIDC and materializes `/tmp/media-runtime.env`.
- Local runtime uses `compose/projects/media/.env`.
- Immich image version is controlled by `IMMICH_VERSION`.
- NGINX is the public edge for Immich and CouchDB.
- Wiki.js is exposed through the same NGINX edge at `docs.carlosjg.space`.
- Production exposes Immich and CouchDB by HTTPS virtual hosts on `443/tcp`.
- TLS and DNS can be added later without changing app containers.
- CouchDB credentials are provided by env, not committed as production secrets.
- Immich upstream Compose remains reference for service topology.

## Milestones

1. Scaffold repo skeleton.

Expected outcome:
Base directories, docs, Compose stack, Ansible deploy role, and validation script exist.

Validation:

```bash
find . -maxdepth 4 -type f | sort
```

Rollback:
Delete scaffolded files before any deploy.

2. Validate local Compose render.

Expected outcome:
`media` stack renders with dev volumes, direct localhost service ports, and NGINX localhost edge ports.

Validation:

```bash
./compose/scripts/validate-compose.sh
docker compose --env-file compose/projects/media/.env \
  -f compose/projects/media/compose.yml \
  -f compose/projects/media/compose.wiki.yml \
  -f compose/projects/media/compose.dev.yml \
  -f compose/projects/media/compose.wiki.dev.yml config
docker run --rm \
  --add-host immich-server:127.0.0.1 \
  --add-host couchdb:127.0.0.1 \
  --add-host wiki:127.0.0.1 \
  -v "$PWD/compose/configs/nginx/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "$PWD/compose/configs/nginx/conf.d:/etc/nginx/conf.d:ro" \
  nginx:1.28.3-alpine nginx -t
```

Rollback:
Revert Compose files only; no data touched unless stack was started.

3. Prepare production deploy model.

Expected outcome:
GitHub Actions can pull secrets from Infisical, create `media.env`, and Ansible can copy Compose/config/NGINX files, assert `/srv/secrets/runtime/media.env`, and run `docker compose up -d` including the Wiki.js module.

Validation:

```bash
ansible-playbook --syntax-check \
  -i ansible/inventories/production/hosts.yml \
  ansible/playbooks/deploy-media.yml
./tests/ansible/check.sh
```

Rollback:
Run `docker compose down` from `/srv/apps/media`; keep `/srv/data/media/*` unless migration rollback requires data restore.

4. Verify exposed edge.

Expected outcome:
Immich, CouchDB, and Wiki.js respond through NGINX on public HTTPS virtual hosts. No Tailscale dependency exists.

Validation:

```bash
curl -fsS "http://127.0.0.1:${NGINX_HTTP_PORT:-80}/healthz"
curl -fsS "https://USER:PASS@couchdb.carlosjg.space/_up"
curl -fsS "https://docs.carlosjg.space"
```

Rollback:
Close public firewall ports or stop `nginx` service while app containers continue running internally.

5. Migrate CouchDB later.

Expected outcome:
Stop old CouchDB, copy or restore data into `/srv/data/media/couchdb/data`, start new stack, verify `_up`.

Validation:

```bash
curl -fsS "http://USER:PASS@127.0.0.1:5984/_up"
```

Rollback:
Stop new CouchDB, restart old `personal` stack, restore previous data if writes occurred during test.

## Risks

- Immich service topology changes over time; keep upstream docs checked before upgrades.
- Immich Postgres data should not live on network shares.
- CouchDB migration needs downtime or replication strategy to avoid divergent writes.
- Port conflicts possible on `2283` and `5984`.
- Public exposure increases auth, TLS, rate-limit, and firewall risk.
- Wiki.js portability depends on keeping its Postgres data under `/srv/data/media/wiki/postgres` and its Compose files isolated as `compose.wiki*.yml`.
- Env secrets with special characters can break Docker interpolation; keep DB password alphanumeric unless tested.
- TLS automation is not implemented yet; deploy behind external TLS or add certbot/ACME milestone before Internet use with credentials.

## Decision Notes

- Stack name is `media`, not `personal`, because Immich is system center and CouchDB becomes supporting personal-data service.
- Base Compose contains service topology only; dev/prod overlays own paths and port exposure.
- Prod exposes via NGINX, not direct app container ports.
- Wiki.js is a module file pair, not folded into the base media topology, so it can be moved to another stack with minimal Compose and data-path changes.
- Tailscale is intentionally omitted because Immich and CouchDB need public exposure.
- CouchDB config is copied from old infra pattern with auth required and local-only operational posture.

## Ready-to-implement Summary

Minimum safe path: scaffold `personal-media`, render Compose locally, validate NGINX, then add production deploy role without touching live CouchDB. Actual CouchDB data migration must be separate controlled step with backup, downtime window, and post-migration `_up` check through NGINX.
