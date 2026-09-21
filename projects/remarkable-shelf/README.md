# remarkable-shelf formation

Deploys reMarkableShelf: one backend service (`server`) + a static frontend
(Vite build served by nginx), sqlite for storage.

See the [repo root README](../../README.md) for how the shared rendering
pipeline works. This project's app repo is
[reMarkableShelf](https://github.com/kqvd/reMarkableShelf), a sibling
directory at `../../../reMarkableShelf`.

## Secrets

```bash
# one-time
openssl rand -base64 32 > .vault_pass
chmod 600 .vault_pass

ansible-vault edit secrets.yml
```

`secrets.yml` currently holds `google_books_api_key` and
`remarkable_ssh_password` — both placeholders (`CHANGEME`) until set.

## Usage

```bash
./run-services.sh render   # .env, docker-compose.yml, Traefik routes
./run-services.sh start    # render + build + up -d
./run-services.sh up       # up -d, no rebuild
./run-services.sh kill     # down --remove-orphans
```

Local dev: `http://remarkable-shelf.localhost` (frontend),
`http://api.remarkable-shelf.localhost/api` (backend).

## Server deployment

Not yet set up. See `trading-core`'s `scripts/build.sh` / `scripts/deploy.sh`
for the pattern (SSH-based build + deploy) once there's a server to target.
