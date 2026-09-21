# formation-playbooks

Centralized Ansible + Docker Compose + Traefik formation for multiple
projects. Each project keeps its own secrets, services, and trust boundary;
they share the rendering logic (Ansible tasks, Jinja templates) under `shared/`.

## Layout

```
formation-playbooks/
  shared/
    tasks/
      render-service.yml   container/local env merge for a backend service (+ Makefile target collection)
      render-env.yml        single-mode env merge (used by browser-facing frontends)
    templates/
      service.env.j2        KEY=VALUE per line
      docker-compose.yml.j2 compose definition, parameterized by project + services.yml + resources.yml
      traefik-static.yml.j2 Traefik routing for server and local domains
  projects/
    remarkable-shelf/       reMarkableShelf's formation (see projects/remarkable-shelf/README.md)
    trading-core/           trading-core's formation (see projects/trading-core/README.md)
```

Each project directory is self-contained: its own `playbook.yml`,
`services.yml` / `resources.yml` / `library.yml`, `secrets.yml` (ansible-vault
encrypted, **not committed to git**), `.vault_pass` (also not committed), and
its own Docker build context. A project's `secrets.yml` and vault password
are never shared with another project — that boundary is deliberate: a
compromise or mistake in one project's secrets doesn't touch the other's.

## How a project wires in

A project's `playbook.yml` sets two vars used throughout the shared logic:

```yaml
vars:
  project: <name>                      # used for image tags, Dockerfile paths
  formation_root: "{{ playbook_dir }}/../.."   # points back at this repo's root
```

The app repo (e.g. `reMarkableShelf`, `trading-backend`) declares what each
service consumes in its own `cmd/<service>/formation.yml`:

```yaml
resources:
  secrets: [google_books, remarkable_ssh]
  config:  [server]
  stores:  [sqlite]
```

That file does `include_tasks: "{{ playbook_dir }}/tasks/render-service.yml"`
— `playbook_dir` always resolves to whichever project's `playbook.yml` is
running, so the app repos never need to know about `formation-playbooks`'
internal layout. Each project directory has a two-line shim at
`tasks/render-service.yml` that forwards to `shared/tasks/render-service.yml`,
so that include path keeps working without editing the app repos.

## Adding a new project

1. `mkdir projects/<name>`
2. Add `services.yml`, `resources.yml`, `library.yml`, `secrets.yml` (own vault password), `playbook.yml` (set `project` and `formation_root`), `backend/Dockerfile`, `frontend/Dockerfile`
3. Add a `tasks/render-service.yml` shim forwarding to `shared/tasks/render-service.yml`
4. Add `cmd/<service>/formation.yml` in the app repo declaring its resources
5. If the project needs extra compose containers (redis, postgres, ...), define them in `resources.yml` with a `compose:` block and list them in `playbook.yml`'s `extra_compose_services` var

## Projects

- [remarkable-shelf](projects/remarkable-shelf/README.md) — single backend service + static frontend, sqlite
- [trading-core](projects/trading-core/README.md) — multi-service backend + frontend, redis + postgres, proxy mode for host-side debugging
