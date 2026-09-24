# storage-service formation

Deploys [storage-service](../../../storage-service/README.md), the
project-agnostic blob store, with its own redis for the event logs. It has no
frontend and no Traefik: calling projects reach it as `storage-service:8083`
over the shared external docker network `storage`. For callers running on the
host (e.g. trading-core's proxy mode), it is also published on
`127.0.0.1:8083`.

See the [repo root README](../../README.md) for how the shared rendering
pipeline works. The app repo is a sibling directory at `../../../storage-service`.

## Callers

Each calling project holds its own API key, which maps to a namespace:

| Project | Services on the `storage` network | Key var (in that project's `secrets.yml`) |
|---|---|---|
| trading-core | reporting-service | `storage_service_api_key` |

To add a caller, generate a key, add the namespace → hash pair to
`storage_clients_b64_json` here, and put the raw key in the caller's secrets:

```bash
cd ../../../storage-service && go run ./cmd/api-key-generator -namespace <project>
```

## Secrets

Set up as in the [root README](../../README.md#secrets). `secrets.yml` holds
`storage_clients_b64_json` — base64 JSON of
`{"<namespace>": "<sha256 hex of api key>"}` covering every caller.

## Usage

```bash
./run-services.sh render   # .env, docker-compose.yml
./run-services.sh start    # render + build + up -d
./run-services.sh up       # up -d, no rebuild
./run-services.sh kill     # down --remove-orphans
```

Start order doesn't matter: this script and each caller's `run-services.sh`
create the `storage` network if it doesn't exist yet.

## Server deployment

```bash
./scripts/deploy.sh   # render, sync to kduong-server:/opt/formation, build + up
```

The server gets the same layout as your machine under `/opt/formation`
(`formation-playbooks/` and `storage-service/` side by side, since the build
context is their parent). Only code and this project's rendered
`docker-compose.yml` and `.env` are synced — never `secrets.yml` or
`.vault_pass`. `SERVER` and `REMOTE_ROOT` env vars override the defaults.

## Data

Bytes live in `/opt/storage-service` on the host; metadata lives in the
`storage:uploads` and `storage:files` event logs in this stack's redis
(`redis-data` volume).
