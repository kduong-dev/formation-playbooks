# remarkable-shelf formation

Deploys reMarkableShelf: the backend `server`, the internal `folder-source`
ebook source plugin, and a static frontend (Vite build served by nginx),
sqlite for storage. The server keeps book files
(EPUBs and PDFs it copies to tablets) in
[storage-service](../storage-service/README.md), which runs as its own
formation and must be up for saving, downloading and copying them (API key:
`storage_service_api_key` in this project's `secrets.yml`).

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

`secrets.yml` holds `storage_service_api_key`, the raw key for the
`remarkable-shelf` namespace, whose hash is in storage-service's
`storage_clients_b64_json`.

## Books folder

`folder-source` serves the EPUBs and PDFs in `/opt/remarkable-shelf/books`
on the host (`books_folder` in `resources.yml`), read-only. A book in the
library can fetch a file whose name holds every word of its title, such as
`Robert C. Martin - Clean Code.epub` for Clean Code. To use it, create the
folder, then add `http://folder-source:8090` as a Plugin on the app's
Sources page, and order it among the other sources there.

## Server deployment

`scripts/deploy.sh` renders, syncs the formation and the reMarkableShelf
repo to the server, builds and starts the stack there, and checks that
`remarkable-shelf.home` and `/api/books` answer 200. Deploy storage-service
first whenever its `storage_clients_b64_json` changes, so it accepts this
project's key.
