# formation-playbooks

Ansible playbooks for provisioning and deploying reMarkableShelf's backend.

## Layout

- `inventories/` — per-environment hosts (`production`, `staging`)
- `group_vars/all/vars.yml` — non-secret defaults
- `group_vars/all/vault.yml` — secrets, encrypted with Ansible Vault
- `roles/backend/` — deploy role: binary, env file, systemd unit
- `playbooks/backend.yml` — entry point for backend deployment

## Secrets

Secrets live in `group_vars/all/vault.yml`, encrypted with Ansible Vault.
The vault password is read from `.vault_pass` (gitignored, not committed).

```bash
# generate a vault password (one time, per environment/machine)
openssl rand -base64 32 > .vault_pass
chmod 600 .vault_pass

# view/edit secrets
ansible-vault edit group_vars/all/vault.yml

# encrypt a new plaintext file
ansible-vault encrypt group_vars/all/vault.yml

# rekey (rotate the vault password)
ansible-vault rekey group_vars/all/vault.yml
```

Share `.vault_pass` with the team out-of-band (password manager), never via git.

## Usage

```bash
# staging
ansible-playbook -i inventories/staging/hosts.yml playbooks/backend.yml

# production (default inventory per ansible.cfg)
ansible-playbook playbooks/backend.yml
```

Before running against real hosts, fill in `ansible_host` / `ansible_user`
in the relevant `inventories/*/hosts.yml`, and replace the `CHANGEME`
placeholders in `group_vars/all/vault.yml` via `ansible-vault edit`.
