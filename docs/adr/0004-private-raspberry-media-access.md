# ADR 0004: Private Raspberry Pi Media Access through Tailscale

## Status

Accepted.

## Context

The Raspberry Pi has no public IP address and the home network must not depend
on router changes, public DNS records, or public ingress. Clients need stable,
private hostnames for media services from both LAN and remote networks.

## Decision

Deploy the media runtime to the Raspberry Pi with a dedicated Compose overlay.
Tailscale provides transport and access control. Host-level dnsmasq resolves
`*.home.carlosjg.space` to the Raspberry Pi Tailscale IPv4 address, and the
tailnet uses Split DNS for that suffix. NGINX binds only to that Tailscale
address and routes each hostname to its Docker service.

TLS uses a private CA certificate mounted from `/srv/secrets/tls`; clients must
trust its root certificate. The self-hosted Infisical runtime is removed, while
GitHub Actions continues to retrieve deploy secrets from an external Infisical
instance using OIDC. The existing public-server deployment remains separate.

## Consequences

- No router, NAT, public DNS, public ACME, or exposed ports are required.
- Private clients must be enrolled in Tailscale and trust the private CA.
- Split DNS and tailnet ACLs are external configuration and are documented as
  bootstrap requirements.
- dnsmasq is a small host dependency managed by Ansible rather than a Docker
  workload, so DNS is available independently of the media stack.
