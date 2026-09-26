# remarkable-shelf formation

Deploys reMarkableShelf: one backend service (`server`) + a static frontend
(Vite build served by nginx), sqlite for storage.

See the [repo root README](../../README.md) for how the shared rendering
pipeline works and how to run a project. This project's app repo is
[reMarkableShelf](https://github.com/kqvd/reMarkableShelf), a sibling
directory at `../../../reMarkableShelf`.

## Secrets

`secrets.yml` currently holds `google_books_api_key` and
`remarkable_ssh_password`. Both are placeholders (`CHANGEME`) until set.

## Server deployment

Not yet set up: there's no `scripts/deploy.sh`. Copy the pattern from
trading-core's or storage-service's.
