# ADR 0001: Personal Media Stack Boundary

## Status

Accepted.

## Context

`infra-victus` currently has a `personal` stack with CouchDB. New infrastructure needs Immich as primary personal media system and should absorb CouchDB so personal-data services live together.

## Decision

Create a dedicated `personal-media` repository with one `media` stack. Immich is primary service. CouchDB moves into same stack because it is independent personal infrastructure, not core app infrastructure.

Docker Compose remains source of truth. Ansible stages files, asserts runtime secrets, stages NGINX config, and runs Compose.

NGINX is colocated with the media stack and is the public edge for Immich and CouchDB. Tailscale is intentionally not part of this repository because both services must be reachable from outside the private mesh.

## Consequences

- Immich and CouchDB can deploy together as personal media/data infrastructure.
- CouchDB migration must be a controlled operational step.
- Public exposure requires strong CouchDB credentials, firewall review, and TLS before real Internet use.
- Future TLS/certbot automation can be added without moving Immich or CouchDB out of the stack.
