# Deployment Scripts

These scripts manage building and deploying the trading stack to `kduong-server`.

**Not yet cut over**: copied from the old `trading-formation` repo, which
still owns the live deploy. `build.sh`/`deploy.sh` here still point at the
old server-side paths and git remote — see the `TODO(migration)` notes in
each script before relying on them from this location.

## Prerequisites

- SSH access to `kduong-server` (configured via `~/.ssh/config`)
- `.env` files and `docker-compose.yml` rendered locally via `./run-services.sh render`

## Workflow

### To build and deploy

```bash
# 1. Sync secrets + push + build all services (notifies via Windows desktop when done)
./scripts/build.sh

# Or rebuild a single service
./scripts/build.sh storage-service

# 2. Deploy once notified
./scripts/deploy.sh
```

### If the build fails

```bash
ssh kduong-server 'cat /opt/trading-core/.build.log'
```

## Scripts

| Script | Description |
|--------|-------------|
| `build.sh` | Sync secrets to server, push, and stream build log live |
| `deploy.sh` | Run `docker compose up -d` on server with pre-built images |
