# trading-core formation

Deploys the trading-core stack: 6 backend services, a Next.js frontend, redis,
postgres, behind the shared Traefik ([gateway](../../infra/gateway/README.md))
at `trading-core.home` / `api.trading-core.home`. reporting-service stores
files in [storage-service](../storage-service/README.md), which runs as its
own formation and must be up for report uploads/downloads to work
(API key: `storage_service_api_key` in this project's `secrets.yml`). See the
[repo root README](../../README.md) for how the shared rendering pipeline
works and how to run and deploy a project.

The app code is the `trading-core` monorepo, checked out next to this repo —
this project reaches it via `../../../trading-core/backend` and
`../../../trading-core/frontend`. What each service consumes is its
`resources` in `services.yml`, and the frontend's is `frontend.resources`
there too.

## Secrets

`secrets.yml` holds `token_secret`, `alpaca_api_key`, `alpaca_api_secret`,
`broker_credentials_b64_json` and `storage_service_api_key`.

## Usage

The [standard commands](../../README.md#running-a-project), including
[proxy mode](../../README.md#proxy-mode) (`./run-services.sh run
account-service`). redis and postgres are published on `127.0.0.1` for
services run on the host.

`scripts/deploy.sh` renders with `--local`, so the server gets the `*.home`
domains.
