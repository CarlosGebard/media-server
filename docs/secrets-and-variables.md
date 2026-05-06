# Secrets and Variables

Runtime secrets come from Infisical via GitHub Actions OIDC.

## GitHub Environment Variables

- `INFISICAL_IDENTITY_ID`
- `INFISICAL_PROJECT_SLUG`
- `INFISICAL_ENV_SLUG`
- `INFISICAL_SECRET_PATH`

## Infisical Secrets

- `PROD_HOST`
- `PROD_SSH_PRIVATE_KEY`
- `PROD_SSH_PORT` optional, defaults to `22`
- `PROD_SSH_KNOWN_HOSTS` optional
- `DB_PASSWORD` for Immich Postgres
- `COUCHDB_USER`
- `COUCHDB_PASSWORD`
- `IMMICH_VERSION` optional, defaults to `v2`

## Runtime File

Workflow materializes `/tmp/media-runtime.env` and Ansible copies it to:

```text
/srv/secrets/runtime/media.env
```

No production secret values should be committed.
