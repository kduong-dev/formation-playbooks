# dnsmasq

LAN DNS on your server. It answers for every name under `.home` with the
server's IP, which is how the [gateway](../gateway/README.md) domains resolve,
and forwards everything else to 1.1.1.1 / 8.8.8.8. It uses host networking and
listens only on the server's LAN interface (`wlp0s20f3`).

## Changing it

Edit [dnsmasq.conf](dnsmasq.conf), then from your machine:

```bash
infra/deploy.sh dnsmasq
```

dnsmasq only reads its config at startup, so `run-services.sh up` recreates
the container; lookups fail for a second or two while it restarts.

If the server's IP or network interface changes, update `address=` and
`interface=` in dnsmasq.conf (and the NRPT rule on Windows clients, see the
[gateway README](../gateway/README.md#domains)).
