# ADR 0003: Credential Services in the Media Runtime

## Status

Accepted.

## Context

Bitwarden Lite and Infisical need public HTTPS endpoints and deployment through
the existing Compose, Ansible, and GitHub Actions path. They must not share
databases or caches with media applications.

## Decision

Run Bitwarden Lite and Infisical in the existing runtime with dedicated MariaDB
and PostgreSQL/Redis services, respectively. Each service group has an internal
Docker network; only the existing NGINX edge joins it. Public names are
`vault.carlosjg.space` and `secrets.carlosjg.space`.

Infisical bootstrap keys are materialized through the existing Infisical
instance during migration, with offline recovery copies retained outside the
self-hosted instance. GitHub workflows are manual-only until the OIDC debug
workflow succeeds.

## Consequences

- Credential services receive TLS, DNS, and deploy automation consistently.
- Media NGINX remains a shared availability dependency for credential services.
- Bitwarden requires the configured external Resend SMTP relay.
- The Infisical encryption and authentication keys cannot be regenerated after
  data exists without losing access to encrypted data or active sessions.
