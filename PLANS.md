# PLANS.md

## Goal

Create a new `personal-media` IaC repository based on `infra-victus` conventions. Main runtime is Immich; CouchDB moves from old `personal` stack into this repo. Docker Compose remains source of truth, Ansible handles host setup and deploy, secrets stay outside git.

## Scope

- Scaffold repo structure for Compose, Ansible, docs, and validation scripts.
- Add `media` stack with Immich services: server, machine-learning, Redis-compatible Valkey, and Postgres vector image.
- Add CouchDB to same `media` stack using existing config conventions.
- Extract Wiki.js from the deployed media stack into portable Compose files.
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
- Wiki.js is no longer exposed by the media NGINX edge.
- Production exposes Immich and CouchDB by HTTPS virtual hosts on `443/tcp`.
- Certbot manages TLS for the public media virtual hosts; DNS must exist before deployment.
- CouchDB credentials are provided by env, not committed as production secrets.
- Immich upstream Compose remains reference for service topology.
- GitHub Actions reads the Infisical production environment from the fixed
  paths `/global`, `/nextcloud`, `/bitwarden`, and `/infisical`; their folder
  names are a workflow contract, not GitHub variables.
- NGINX uses Docker service DNS and dynamic addresses on private networks;
  proxy-aware applications trust only their corresponding private CIDR.
- Nextcloud persists its HTML tree as `www-data` and starts cron only after the
  application health check completes, avoiding first-deploy initialization
  races.

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
  -f compose/projects/media/compose.dev.yml config
docker run --rm \
  --add-host immich-server:127.0.0.1 \
  --add-host couchdb:127.0.0.1 \
  -v "$PWD/compose/configs/nginx/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "$PWD/compose/configs/nginx/conf.d:/etc/nginx/conf.d:ro" \
  nginx:1.28.3-alpine nginx -t
```

Rollback:
Revert Compose files only; no data touched unless stack was started.

3. Prepare production deploy model.

Expected outcome:
GitHub Actions can pull secrets from Infisical, create `media.env`, and Ansible can copy Compose/config/NGINX files, assert `/srv/secrets/runtime/media.env`, and run `docker compose up -d` without Wiki.js.

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
Immich and CouchDB respond through NGINX on public HTTPS virtual hosts. No Tailscale dependency exists.

Validation:

```bash
curl -fsS "http://127.0.0.1:${NGINX_HTTP_PORT:-80}/healthz"
curl -fsS "https://USER:PASS@couchdb.carlosjg.space/_up"
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
- Wiki.js was located at `/srv/apps/media/compose.wiki*.yml` with Postgres data under `/srv/data/media/wiki/postgres`; extracted IaC package now lives under `wikijs-infra/`.
- Env secrets with special characters can break Docker interpolation; keep DB password alphanumeric unless tested.
- TLS issuance depends on valid DNS and public access to port 80 for ACME challenges.

## Decision Notes

- Stack name is `media`, not `personal`, because Immich is system center and CouchDB becomes supporting personal-data service.
- Base Compose contains service topology only; dev/prod overlays own paths and port exposure.
- Prod exposes via NGINX, not direct app container ports.
- Wiki.js is outside the media deployment so the media stack can be operated without starting `wiki` or `wiki-database`.
- Tailscale is intentionally omitted because Immich and CouchDB need public exposure.
- CouchDB config is copied from old infra pattern with auth required and local-only operational posture.

## Ready-to-implement Summary

Minimum safe path: scaffold `personal-media`, render Compose locally, validate NGINX, then add production deploy role without touching live CouchDB. Actual CouchDB data migration must be separate controlled step with backup, downtime window, and post-migration `_up` check through NGINX.

## Follow-up: Nextcloud Integration

Goal: add Nextcloud as the personal cloud at `cloud.carlosjg.space`, deployed
automatically through the existing GitHub Actions, Infisical, Ansible, and
Compose path.

Scope:

- Add `nextcloud`, `nextcloud-cron`, `nextcloud-db`, and `nextcloud-redis`.
- Persist files and MariaDB data under `/srv/data/media/nextcloud`.
- Route the public virtual host through NGINX, including CalDAV/CardDAV
  discovery redirects and TLS certificate coverage.
- Extend the Infisical contract with Nextcloud admin and database secrets.
- Remove residual Wiki.js workflow references that no longer match the stack.

Non-goals: SMTP, office suites, external object storage, and backup automation.

Validation:

```bash
make validate
make ansible-check
docker compose --env-file compose/projects/media/.env \
  -f compose/projects/media/compose.yml \
  -f compose/projects/media/compose.prod.yml config
```

Risk: `cloud.carlosjg.space` must resolve to the server before the production
workflow runs; otherwise the shared Certbot certificate cannot be renewed or
expanded.

## Follow-up: Credential Services

Goal: deploy Bitwarden Lite at `vault.carlosjg.space` and Infisical at
`secrets.carlosjg.space` with dedicated private data services.

Scope: dedicated databases/caches, NGINX routes and certificate domains,
manual-only deployment workflows, Infisical OIDC diagnostic workflow, and
bootstrap-key recovery documentation.

Validation: render dev/prod Compose, run Ansible syntax validation, run
`nginx -t`, then manually execute `Debug Infisical OIDC` before enabling
automatic workflows.

## Follow-up: Obsidian LiveSync on iOS

Goal: make the existing CouchDB edge compatible with Obsidian iOS.

Scope: correct the Capacitor CORS origin and disable proxy buffering/redirect rewriting for CouchDB in the local and production NGINX routes.

Assumptions: the production CouchDB URL remains `https://couchdb.carlosjg.space` and has a trusted TLS certificate.

Steps:

1. Allow `capacitor://localhost` in CouchDB CORS.
2. Set `proxy_redirect off` and `proxy_buffering off` on every CouchDB reverse-proxy location.

Validation: render the local Compose configuration and run `nginx -t` through `./compose/scripts/validate-compose.sh`.

Risks: iOS will still reject HTTP or a self-signed/invalid TLS certificate.
