# formation-playbooks

Centralized Ansible + Docker Compose + Traefik formation for multiple
projects, all served on one machine through a single shared Traefik
([infra/gateway](infra/gateway/README.md)). Each project keeps its own
secrets, services, and trust boundary; they share the rendering logic (Ansible
tasks, Jinja templates) under `shared/`.

## Layout

```
formation-playbooks/
  shared/
    tasks/
      render-service.yml    container .env + local-mode Makefile target for a backend service
      render-env.yml        single-mode .env (used by browser-facing frontends)
      merge-env.yml         resources -> service_environment, used by both of the above
      write-env.yml         writes service_environment to env_dest
      render-compose.yml    docker-compose.yml + the project's routes into infra/gateway/routes/
    docker/
      backend.Dockerfile    builds any project's Go service (APP_DIR + SERVICE build args;
                            a service's `cmd:` in services.yml overrides SERVICE)
    templates/
      service.env.j2        KEY=VALUE per line
      docker-compose.yml.j2 compose definition, parameterized by project + services.yml + resources.yml
      traefik-static.yml.j2 a project's routes for the shared Traefik, server and local domains
    scripts/
      sync-formation.sh     rsyncs this repo's code (never secrets or rendered files) to the server
  projects/
    <name>/                 one self-contained formation per project (see Projects below)
  infra/                    stacks the server itself runs for every project (see Infra below)
    deploy.sh               sync + (re)start them on the server
```

Each project directory is self-contained: its own `playbook.yml`,
`services.yml` / `resources.yml` / `library.yml`, `secrets.yml` (ansible-vault
encrypted, **not committed to git**), `.vault_pass` (also not committed), and
its own Docker build context. A project's `secrets.yml` and vault password
are never shared with another project — that boundary is deliberate: a
compromise or mistake in one project's secrets doesn't touch the other's.

### Secrets

Projects with an `ansible.cfg` read their vault password from `.vault_pass`:

```bash
# one-time, in the project directory
openssl rand -base64 32 > .vault_pass
chmod 600 .vault_pass

ansible-vault create secrets.yml   # or `edit` once it exists
```

Each project's README lists the vars its `secrets.yml` must define.

## How a project wires in

A project's `playbook.yml` sets these vars used throughout the shared logic:

```yaml
vars:
  project: <name>                      # used for image tags, Dockerfile paths
  formation_root: "{{ playbook_dir }}/../.."   # points back at this repo's root
  backend_dir: <repo>/backend          # Go module for shared/docker/backend.Dockerfile, relative to this repo's parent
```

Each entry in `services.yml` declares what that service consumes under
`resources`, as library sections and their entries:

```yaml
services:
  server:
    resources:
      secrets: [google_books, remarkable_ssh]
      config:  [server]
      stores:  [sqlite]
```

The playbook's `import_tasks` of `shared/tasks/render-services.yml` loops over
`services` and renders each one's `backend/<service>/.env` and Makefile target.
The key maps to the service name by replacing `_` with `-`, and to its
`cmd/<dir>` the same way unless `cmd:` overrides it. The app repos carry no
formation files.

## Adding a new project

1. `mkdir projects/<name>`
2. Add `services.yml`, `resources.yml`, `library.yml`, `secrets.yml` (own vault password), `playbook.yml` (set `project`, `formation_root` and `backend_dir`, `import_tasks` `shared/tasks/render-services.yml`, and end with an `import_tasks` of `shared/tasks/render-compose.yml`), `frontend/Dockerfile`, and `api_domain` / `local_api_domain` (plus `domain` / `local_domain` with a frontend) in `services.yml`
3. Declare each service's `resources` in its `services.yml` entry
4. If the project calls storage-service: add `storage` to `external_networks` in `playbook.yml`, add `networks: [storage]` to the calling services' `compose:` block, create it in `run-services.sh` before `up` alongside `gateway` (see trading-core's), and register the project's API key hash in storage-service's `storage_clients_b64_json`
5. If the project needs extra compose containers (redis, postgres, ...), define them in `resources.yml` with a `compose:` block and list them in `playbook.yml`'s `extra_compose_services` var
6. Give its server domains the `.home` suffix: the server's DNS already answers for everything under it (see [infra/gateway](infra/gateway/README.md#domains))

## Projects

- [remarkable-shelf](projects/remarkable-shelf/README.md) — single backend service + static frontend, sqlite
- [trading-core](projects/trading-core/README.md) — multi-service backend + frontend, redis + postgres, proxy mode for host-side debugging
- [storage-service](projects/storage-service/README.md) — shared blob storage + its own redis, no frontend; other projects' containers reach it over the shared `storage` docker network, everything else at `api.storage-service.home`

## Infra

Not projects: nothing to render and no secrets, so their compose files are
committed as-is. `infra/deploy.sh [gateway|dnsmasq]` syncs and (re)starts them
on the server.

- [gateway](infra/gateway/README.md) — the shared Traefik on :80 that routes every project's domains
- [dnsmasq](infra/dnsmasq/README.md) — LAN DNS that resolves every `.home` name to the server
