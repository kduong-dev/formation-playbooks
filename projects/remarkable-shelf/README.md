# remarkable-shelf formation

Deploys reMarkableShelf: one backend service (`server`) + a static frontend
(Vite build served by nginx), sqlite for storage.

See the [repo root README](../../README.md) for how the shared rendering
pipeline works and how to run a project. This project's app repo is
[reMarkableShelf](https://github.com/kduong-dev/reMarkableShelf), a sibling
directory at `../../../reMarkableShelf`.

## Secrets

`secrets.yml` holds `remarkable_ssh_password`, a placeholder (`CHANGEME`)
until set. Book search uses Open Library, which needs no API key.

## Server deployment

Not yet set up: there's no `scripts/deploy.sh`. Copy the pattern from
trading-core's or storage-service's.
