# gateway

The one Traefik per machine, on port 80, routing by hostname to every
project's services. Projects don't run their own Traefik: each project's
`run-services.sh render` writes its routes to `routes/<project>.yml` here
(gitignored), and Traefik watches the directory, so they go live without a
restart.

Routable containers (each project's services and frontend) join the shared
external `gateway` network under a `<project>-<name>` alias, which is what the
route files point at. Whichever stack starts first creates the network.

There's nothing to render or keep secret here, so `docker-compose.yml` is
committed as-is.

## Usage

```bash
./run-services.sh up       # start (creates the gateway network and routes/)
./run-services.sh routes   # which projects' route files are loaded
./run-services.sh logs     # follow Traefik's logs
./run-services.sh kill
```

## Domains

| Project | Domains |
|---|---|
| remarkable-shelf | `remarkable-shelf.local`, `api.remarkable-shelf.local` |
| trading-core | `trading-core.local`, `api.trading-core.local` |
| storage-service | `api.storage-service.local` |

Each also has a `.localhost` twin for local dev, which resolves to your own
machine without any DNS setup. On the LAN, the `.local` names resolve through
the dnsmasq on kduong-server (`~/dnsmasq/dnsmasq.conf`), one line per project:

```
address=/storage-service.local/192.168.1.19
```

That also covers subdomains (`api.storage-service.local`). Restart it after
editing: `cd ~/dnsmasq && docker compose restart`.
