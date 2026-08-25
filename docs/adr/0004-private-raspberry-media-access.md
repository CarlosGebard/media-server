# ADR 0004: Private Raspberry Pi Media Access through Tailscale

## Status

Accepted.

## Context

The Raspberry Pi has no public IP address and the home network must not depend
on router changes, public DNS records, or public ingress. Clients need stable,
private hostnames for media services from both LAN and remote networks.

## Decision

Deploy the media runtime to the Raspberry Pi with a dedicated Compose overlay.
Each application binds only to a localhost port and Tailscale Serve publishes
it on an HTTPS port of the Raspberry Pi MagicDNS hostname. Tailscale manages
transport, access control, DNS, and trusted TLS certificates.

The self-hosted Infisical runtime is removed, while
GitHub Actions continues to retrieve deploy secrets from an external Infisical
instance using OIDC. The existing public-server deployment remains separate.

## Consequences

- No router, NAT, public DNS, public ACME, or exposed ports are required.
- Private clients must be enrolled in the tailnet and allowed by its ACLs.
- No private CA, split DNS, dnsmasq, or Raspberry NGINX edge is required.
- The service URLs use distinct HTTPS ports on one stable MagicDNS hostname.
