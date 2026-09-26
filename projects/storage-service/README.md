# storage-service formation

Deploys [storage-service](../../../storage-service/README.md), the
project-agnostic blob store, with its own redis for the event logs. It has no
frontend. Calling projects' containers reach it as `storage-service:8083` over
the shared external docker network `storage`; anything else (your machine,
other LAN devices) goes through the shared Traefik at
`http://api.storage-service.home/storage/v1`, or
`api.storage-service.localhost` in local dev. For callers running on the
server's host (e.g. trading-core's proxy mode), it is also published on
`127.0.0.1:8083`.

See the [repo root README](../../README.md) for how the shared rendering
pipeline works and how to run and deploy a project. The app repo is a sibling
directory at `../../../storage-service`.

## Callers

Each calling project holds its own API key, which maps to a namespace, and
its README says what it uses storage for. To list them:
`grep -l storage ../*/services.yml`.

To add a caller, follow step 4 of
[Adding a new project](../../README.md#adding-a-new-project). Then generate a
key, add the namespace → hash pair to `storage_clients_b64_json` here, and put
the raw key in the caller's secrets:

```bash
cd ../../../storage-service && go run ./cmd/api-key-generator -namespace <project>
```

Start order doesn't matter: this project's `run-services.sh` and each
caller's create the `storage` network if it doesn't exist yet.

## Secrets

`secrets.yml` holds `storage_clients_b64_json`: base64 JSON of
`{"<namespace>": "<sha256 hex of api key>"}` covering every caller.

## Data

Bytes live in `/opt/storage-service` on the host; metadata lives in the
`storage:uploads` and `storage:files` event logs in this stack's redis
(`redis-data` volume).
