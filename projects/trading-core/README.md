# trading-core formation

Deploys the trading-core stack: 6 backend services, a Next.js frontend, redis,
postgres, behind the shared Traefik ([gateway](../../infra/gateway/README.md))
at `trading-core.home` / `api.trading-core.home`. reporting-service stores
files in [storage-service](../storage-service/README.md), which runs as its
own formation and must be up for report uploads/downloads to work. See the
repo root README for how the shared rendering pipeline works.

This is the live deployment on kduong-server, replacing the standalone
[trading-formation](https://github.com/trading-core/trading-formation) repo
(retired; its data was backed up, not migrated).

The app code is the `trading-core` monorepo, checked out next to this repo —
this project reaches it via `../../../trading-core/backend` and
`../../../trading-core/frontend`. What each service consumes is its
`resources` in `services.yml`, and the frontend's is `frontend.resources`
there too.

## Secrets

`secrets.yml` was copied over from the old `trading-formation` repo
still encrypted — same ansible-vault ciphertext, so the existing vault
password still works. Like the other projects, it's read from `.vault_pass`
(see the [root README](../../README.md#secrets)):

```bash
ansible-vault edit secrets.yml
```

## Usage

```bash
./run-services.sh render          # .env files, Makefile, docker-compose.yml, Traefik routes
./run-services.sh render --local  # same, but for .local (server) domains instead of .localhost
./run-services.sh start           # build + up -d
./run-services.sh proxy           # edit proxy.conf to run a service on the host instead of in compose
./run-services.sh watch           # keep Traefik in sync with host-run service ports
./run-services.sh kill
```

## Server deployment

```bash
./scripts/deploy.sh   # render for *.home, sync to kduong-server:/opt/formation, build + up
```

The server gets the same layout as your machine under `/opt/formation`
(`formation-playbooks/` and `trading-core/{backend,frontend}/`, since
the build context is their parent). Only code, this project's rendered
`docker-compose.yml` / `.env` files and its gateway route file are synced —
never `secrets.yml` or `.vault_pass`. `SERVER` and `REMOTE_ROOT` env vars
override the defaults.
