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
      render-services.yml   every service's .env files, plus the .services.sh proxy mode reads
      render-service.yml    container .env + local-mode host.env for a backend service
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
      host.env.j2           shell-quoted local-mode env, sourced when a service runs on the host
      services.sh.j2        each service's path prefix and cmd, for proxy mode
    scripts/
      run-services.sh       every project's commands; sourced by projects/<name>/run-services.sh
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

## Running a project

Every project has a `run-services.sh` that sets its shared docker networks
and sources [shared/scripts/run-services.sh](shared/scripts/run-services.sh),
so they all have the same commands, run from the project's directory:

```bash
./run-services.sh render [--local]  # .env files, docker-compose.yml, Traefik routes (--local: *.home URLs)
./run-services.sh start             # render + build + up -d
./run-services.sh up                # up -d, no rebuild
./run-services.sh kill              # down --remove-orphans
./run-services.sh delete            # also remove images and volumes
```

### Proxy mode

Any backend service can run on your machine instead of in compose, still
reached through the gateway at its usual API host and path prefix:

```bash
./run-services.sh run <service>   # e.g. run account-service
./run-services.sh status          # which services are running on the host
./run-services.sh ports           # loopback ports Docker published the project's containers on
./run-services.sh proxy           # edit proxy.conf: services flagged 1 stay out of start/up
```

`run` stops the service's container, picks a free port, writes a
`routes/<project>-proxy-<service>.yml` into the gateway that beats the
rendered route for the same host + path prefix, and `go run`s the service's
`cmd/<dir>` in the project's `backend_dir` with the rendered
`backend/<service>/host.env` (its `local` mode env) and `PORT`. Ctrl-C
removes the route. The host process reaches the project's other resources
through their `local` addresses, so publish those in the resource's
`compose.ports` on `127.0.0.1` with no host port (`"127.0.0.1::6379"`), and
let Docker pick a free one. That way no two projects, and nothing else
installed on the machine, can collide. In the `local` address, write
`<host-port:redis:6379>` where the port goes, or
`<host-port:storage-service/api:8083>` for another project's container. `run`
replaces each one with the port Docker published before it sources
`host.env`, and refuses to start if that container isn't up. Ports change
whenever a container is recreated, so restart host-run services after
recreating a resource. Use `./run-services.sh ports` to find a port for your
own tools (`psql`, `redis-cli`). See trading-core's redis and postgres. Callers in
other containers still use the container address, so only traffic through
the gateway reaches the host process.

Projects with a `scripts/deploy.sh` deploy to a remote server from your
machine. Point them at it once with a gitignored `deploy.env` at the repo root:

```bash
cp deploy.env.example deploy.env   # set SERVER to an ~/.ssh/config alias or user@host
```

Each deploy renders locally, syncs code and rendered files to `REMOTE_ROOT`
(default `/opt/formation`), then builds and starts the stack there. The server gets the
same layout as your machine (`formation-playbooks/` next to the app repos,
since the build context is their parent). Only code, the project's rendered
`docker-compose.yml` / `.env` files and its gateway route file are synced,
never `secrets.yml`, `.vault_pass` or `deploy.env`. `SERVER` and
`REMOTE_ROOT` set in the environment override `deploy.env` for one run.

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
`services` and renders each one's `backend/<service>/.env` and `host.env`.
The key maps to the service name by replacing `_` with `-`, and to its
`cmd/<dir>` the same way unless `cmd:` overrides it. The app repos carry no
formation files.

## Adding a new project

1. `mkdir projects/<name>`
2. Add `services.yml`, `resources.yml`, `library.yml`, `secrets.yml` (own vault password), `playbook.yml` (set `project`, `formation_root` and `backend_dir`, `import_tasks` `shared/tasks/render-services.yml`, and end with an `import_tasks` of `shared/tasks/render-compose.yml`), `frontend/Dockerfile`, and `api_domain` / `local_api_domain` (plus `domain` / `local_domain` with a frontend) in `services.yml`
3. Declare each service's `resources` in its `services.yml` entry
4. If the project calls storage-service: add `storage` to `external_networks` in `playbook.yml`, add `networks: [storage]` to the calling services' `compose:` block, add it to `SHARED_NETWORKS` in `run-services.sh` alongside `gateway` (see trading-core's), and register the project's API key hash in storage-service's `storage_clients_b64_json`
5. If the project needs extra compose containers (redis, postgres, ...), define them in `resources.yml` with a `compose:` block and list them in `playbook.yml`'s `extra_compose_services` var
6. Give its server domains the `.home` suffix: the server's DNS already answers for everything under it (see [infra/gateway](infra/gateway/README.md#domains))

## Projects

- [remarkable-shelf](projects/remarkable-shelf/README.md) — single backend service + static frontend, sqlite
- [trading-core](projects/trading-core/README.md) — multi-service backend + frontend, redis + postgres
- [storage-service](projects/storage-service/README.md) — shared blob storage + its own redis, no frontend; other projects' containers reach it over the shared `storage` docker network, everything else at `api.storage-service.home`

## Infra

Not projects: nothing to render and no secrets, so their compose files are
committed as-is. `infra/deploy.sh [gateway|dnsmasq]` syncs and (re)starts them
on the server.

- [gateway](infra/gateway/README.md) — the shared Traefik on :80 that routes every project's domains
- [dnsmasq](infra/dnsmasq/README.md) — LAN DNS that resolves every `.home` name to the server
