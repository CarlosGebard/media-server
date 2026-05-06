# AGENTS.md

## Purpose

This repository operates personal media infrastructure with Docker Compose as runtime source of truth and Ansible as host/deploy orchestrator.

Golden rule:

> One source of truth, two execution modes: local and server.

## Working Rules

1. Keep changes small, testable, and scoped.
2. Compose files define runtime; Ansible copies files and runs Compose.
3. Secrets never live in repo.
4. Local and prod differences live in env files and overlays.
5. Do not hardcode `/srv` in base Compose.
6. Update `PLANS.md` for multi-file, infra, architecture, or ambiguous work.
7. Run validation before claiming completion.

## Repository Structure

```text
compose/
  projects/media/
  configs/couchdb/
  env/
  scripts/

ansible/
  playbooks/
  roles/deploy/media/
  inventories/production/group_vars/

docs/
  adr/
  runbooks/
```

## Stack Boundaries

- `media` is the main stack.
- Immich is the primary system.
- CouchDB is colocated here because it is personal-data infrastructure, not app core.
- NGINX is the public edge for Immich and CouchDB.
- Tailscale is intentionally not used in this repo.
- Observability remains outside this repo unless explicitly added later.

## Validation

Prefer:

```bash
./compose/scripts/validate-compose.sh
```

Then run targeted checks:

```bash
docker compose --env-file compose/projects/media/.env \
  -f compose/projects/media/compose.yml \
  -f compose/projects/media/compose.dev.yml config
```
