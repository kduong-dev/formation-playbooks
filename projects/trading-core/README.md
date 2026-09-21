# trading-core formation

Deploys the trading-core stack: 7 backend services, a Next.js frontend, redis,
postgres, behind Traefik. Migrated from the standalone
[trading-formation](https://github.com/trading-core/trading-formation) repo
into this centralized layout — see the repo root README for how the shared
rendering pipeline works.

**Migration status**: this is a copy, not yet the live deploy path. The old
`trading-formation` repo still owns the actual `kduong-server` deployment.
`scripts/build.sh` and `scripts/deploy.sh` here have `TODO(migration)` notes
where server-side paths and the `server` git remote still need to be
repointed before this becomes the live deploy path. Everything else
(`run-services.sh render/start/up`, local dev, proxy mode) works standalone
against this repo already.

App repos are sibling directories under `trading-core/`, one level up from
where the old `trading-formation` lived — this project reaches them via
`../../../trading-core/trading-backend` and `../../../trading-core/trading-frontend`.

## Secrets

`secrets.yml` was copied over from the old `trading-formation` repo
still encrypted — same ansible-vault ciphertext, so the existing vault
password still works:

```bash
ansible-vault edit secrets.yml --ask-vault-pass
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

See [scripts/README.md](scripts/README.md) for the (not-yet-cut-over)
server build/deploy workflow.
