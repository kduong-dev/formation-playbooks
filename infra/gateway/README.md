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

Every project's `run-services.sh start` / `up` starts it if it isn't already
running, so locally there's nothing to do. Deploy it from your machine with
`infra/deploy.sh gateway`. To manage it directly, from this directory:

```bash
./run-services.sh up       # start (creates the gateway network and routes/)
./run-services.sh routes   # which projects' route files are loaded
./run-services.sh logs     # follow Traefik's logs
./run-services.sh kill
```

## Domains

Every project follows the same naming, set in its `services.yml`
(`domain` / `api_domain`, `local_domain` / `local_api_domain`):

| | Server | Local dev |
|---|---|---|
| Frontend | `<project>.home` | `<project>.localhost` |
| API | `api.<project>.home` | `api.<project>.localhost` |

`.localhost` names resolve to your own machine with no setup. Server names all
sit under `.home` (not a public TLD, and unlike `.local` it doesn't collide
with mDNS), and the server's [dnsmasq](../dnsmasq/README.md) answers for
everything under it with one line:

```
address=/home/192.168.1.19
```

A new project needs no DNS change. Clients do need to ask that dnsmasq for
these names, once per machine or network:

- **Just a Windows PC** (WSL inherits it), in an Administrator PowerShell:
  `Add-DnsClientNrptRule -Namespace ".home" -NameServers "192.168.1.19"`.
  Only these names go to the server; everything else uses your normal DNS.
- **Every device**: set `192.168.1.19` as the DNS server in the router's DHCP
  settings. If the server is down, all lookups fail until it's back.

If the server's IP changes, update the dnsmasq line (and the NRPT rule).
