# remarkable-shelf formation

Deploys reMarkableShelf: one backend service (`server`) + a static frontend
(Vite build served by nginx), sqlite for storage.

See the [repo root README](../../README.md) for how the shared rendering
pipeline works and how to run a project. This project's app repo is
[reMarkableShelf](https://github.com/kduong-dev/reMarkableShelf), a sibling
directory at `../../../reMarkableShelf`.

## Secrets

The server needs no tablet password. It signs in to tablets with its own
SSH key, generated on first start as `remarkable-shelf_ed25519` beside the
database in the `remarkable-shelf-db` volume, and installed on each tablet
when it's paired from the Sync page, which asks for the tablet's password
once and doesn't store it. `secrets.yml`'s `remarkable_ssh_password` is no
longer used. Book search uses Open Library, which needs no API key.

## Server deployment

Not yet set up: there's no `scripts/deploy.sh`. Copy the pattern from
trading-core's or storage-service's.
