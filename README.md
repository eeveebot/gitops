# gitops

> Kubernetes GitOps repository for the eevee platform — declarative infrastructure and application delivery via Flux.

## Overview

This repository is the single source of truth for eevee's Kubernetes cluster. It uses [Flux](https://fluxcd.io/) to continuously reconcile cluster state against the manifests stored here, and [Ansible](https://www.ansible.com/) to bootstrap the underlying RKE2 nodes.

The eevee framework runs as a collection of independent modules (router, connectors, commands) deployed as Kubernetes resources managed by the [eevee Helm chart](https://helm.eevee.bot/). Each module is declared with its image tag, replica count, IPC configuration, and per-module config in a single `HelmRelease` — Flux detects changes and rolls them out automatically.

Secrets are encrypted at rest with [SOPS](https://github.com/getsops/sops) using [age](https://github.com/FiloSottile/age) and decrypted in-cluster by the Flux SOPS provider, so no plaintext secrets are ever committed.

## Features

- **Declarative cluster state** — Flux watches the `main` branch and reconciles every 10 minutes
- **Automated rollouts** — push an image tag change and Flux handles the rest
- **SOPS-encrypted secrets** — age-encrypted secrets decrypted in-cluster via the `sops-age` secret
- **Ansible cluster bootstrapping** — RKE2 installation, UFW firewall, Cilium CNI, and Flux bootstrap in one playbook
- **Kustomize layering** — each service (eevee, cilium, traefik, cert-manager, monitoring, authentik, local-path-provisioner) is a self-contained Kustomization with its own `deploy.yaml`
- **Helm-driven bot deployment** — the eevee `HelmRelease` declares all bot modules, their images, config, and persistence in one place
- **Dual-stack networking** — IPv4/IPv6 throughout (Cilium, cluster CIDRs, BGP)

## Install

This is a GitOps repository, not an npm package. To use it:

```bash
git clone ssh://git@github.com/eeveebot/gitops.git
cd gitops
```

### Prerequisites

- An RKE2 Kubernetes cluster (bootstrapped via the Ansible playbooks below)
- Flux CLI (`flux`)

## Configuration

### Repository Layout

```
gitops/
├── ansible/                  # Node bootstrapping
│   ├── inventory/            # Ansible inventory (control plane, workers)
│   ├── playbooks/rke2.yml    # Full RKE2 install + Flux bootstrap playbook
│   ├── tmpl/                 # RKE2 config templates (server, agent)
│   └── vars/extravars.yml    # Cluster CIDRs, Flux repo URL, Cilium Helm values
├── flux/                     # Flux Kustomizations
│   ├── .sops.yaml            # SOPS config (age recipient, encryption rules)
│   ├── encrypt.sh            # Encrypt a file: ./flux/encrypt.sh <path>
│   ├── decrypt.sh            # Decrypt a file: ./flux/decrypt.sh <path>
│   ├── flux-system/          # Flux itself (GitRepository, root Kustomization)
│   ├── eevee/                # eevee HelmRelease + CRDs + secrets
│   ├── cilium/               # Cilium CNI (Helm, BGP, WireGuard encryption)
│   ├── traefik/              # Ingress controller
│   ├── cert-manager/         # TLS certificates (Let's Encrypt DNS-01 via Cloudflare)
│   ├── monitoring/           # Observability stack
│   ├── authentik/            # Identity provider
│   └── local-path-provisioner/ # Dynamic local PV provisioning
├── AGENTS.md                 # AI agent development guidelines
└── LICENSE                   # CC BY-NC-SA 4.0
```

### Flux Sync

Flux watches `ssh://git@github.com/eeveebot/gitops.git` on the `main` branch, polling every **1 minute** for new commits. The root `Kustomization` at `./flux` reconciles every **10 minutes**, which in turn syncs all child Kustomizations (eevee, cilium, traefik, etc.) on the same interval.

### SOPS Configuration

| Key | Value |
|-----|-------|
| Path regex | `.*\.sops\.yaml$` |
| Encrypted fields | `data`, `stringData` |
| Age recipient | `age1cgrs4dhzusfgkqg5dcyepzpfttlf3cppjd3zuv0l4qju7cmq7fpsqltd7r` |
| In-cluster secret | `sops-age` in `flux-system` namespace |

To encrypt/decrypt locally:

```bash
# Set your age key file
export SOPS_AGE_KEY_FILE="./flux/.sops/flux.agekey"

# Encrypt
./flux/encrypt.sh flux/eevee/deploy/weather-secrets.sops.yaml

# Decrypt
./flux/decrypt.sh flux/eevee/deploy/weather-secrets.sops.yaml
```

### Ansible Variables

Key variables in `ansible/vars/extravars.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `rke2_cluster_cidr` | `172.16.0.0/16,fda8:af7c:f3da::/64` | Pod CIDRs (v4, v6) |
| `rke2_service_cidr` | `172.18.0.0/16,fd4e:73c9:dc74::/112` | Service CIDRs (v4, v6) |
| `rke2_cluster_dns` | `172.18.0.10,fd4e:73c9:dc74::10` | Cluster DNS IPs |
| `flux_github_url` | `ssh://git@github.com/eeveebot/gitops.git` | Flux source repo |
| `flux_github_branch` | `main` | Branch to track |
| `flux_github_repo_path` | `/flux` | Path within repo |
| `cilium_version` | `1.19.1` | Cilium Helm chart version |

### Cluster Inventory

Defined in `ansible/inventory/chi-eevee-bot.yml`:

- **Control plane:** `chi101-eevee-bot` (`chi101.eevee.bot`)
- **Workers:** _(none currently)_

## Usage / Commands

### Bootstrapping a New Cluster

```bash
# 1. Install Ansible requirements
cd ansible
ansible-galaxy collection install -r requirements.yml

# 2. Run the RKE2 playbook (installs RKE2, Cilium, Flux)
ansible-playbook -i inventory/chi-eevee-bot.yml \
  -e @vars/extravars.yml \
  -e "rke2_token=YOUR_TOKEN" \
  playbooks/rke2.yml
```

The playbook:
1. Installs prerequisite packages and reboots
2. Configures UFW firewall (SSH, K8s API, inter-node traffic)
3. Installs RKE2 server/agent with templated configs
4. Bootstraps Cilium CNI via Helm
5. Bootstraps Flux with `flux bootstrap git` and installs the SOPS age key

### Deploying a Bot Module Update

To roll out a new image tag for a bot module (e.g., upgrading the router):

1. Edit `flux/eevee/deploy/eevee.yaml`
2. Update the `image` field for the target module:
   ```yaml
   - name: router
     spec:
       image: ghcr.io/eeveebot/router:2.4.5   # bump the tag
   ```
3. Commit and push to `main`
4. Flux detects the change within 1 minute and reconciles the `HelmRelease` within 10 minutes

### Force a Reconciliation

```bash
# Reconcile everything
flux reconcile ks flux-system --with-source

# Reconcile a specific Kustomization
flux reconcile ks eevee --with-source

# Force a HelmRelease update
flux reconcile hr eevee-eevee --force
```

### Adding a New Bot Module

Add a new entry under `bot.botModules` in `flux/eevee/deploy/eevee.yaml`:

```yaml
- name: my-module
  spec:
    size: 1
    image: ghcr.io/eeveebot/my-module:1.0.0
    pullPolicy: Always
    metrics: false
    metricsPort: 8080
    ipcConfig: eevee-bot
    moduleName: my-module
    moduleConfig: |
      ratelimit:
        mode: drop
        level: user
        limit: 10
        interval: 1m
```

If the module needs secrets, create a SOPS-encrypted file and add it to `flux/eevee/deploy/kustomization.yaml`.

### Validating Manifests

```bash
# Dry-run all Kustomizations
kubectl apply --dry-run=client -k flux/

# Dry-run a single service
kubectl apply --dry-run=client -k flux/eevee/

# Validate with Flux
flux validate kustomization flux/
```

## Architecture

### Deployment Flow

```
┌─────────────┐     push      ┌──────────────────┐
│   Developer  │──────────────▶│  GitHub (main)    │
└─────────────┘               └────────┬─────────┘
                                       │ poll every 1m
                                       ▼
                              ┌──────────────────┐
                              │  Flux Source      │
                              │  Controller       │
                              └────────┬─────────┘
                                       │
                                       ▼
                              ┌──────────────────┐
                              │  Flux Kustomize   │
                              │  Controller       │
                              │  (reconcile 10m)  │
                              └────────┬─────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
             ┌──────────┐      ┌──────────┐       ┌──────────┐
             │  eevee   │      │  cilium  │  ...  │  traefik │
             │  Ks      │      │  Ks      │       │  Ks      │
             └────┬─────┘      └──────────┘       └──────────┘
                  │
                  ▼
         ┌────────────────┐
         │ HelmRelease    │
         │ eevee-crds     │────▶ CRDs installed
         │ eevee-eevee    │────▶ Operator + Bot modules
         └────────────────┘
```

### eevee HelmRelease Structure

The eevee deployment has two `HelmRelease` resources:

1. **`eevee-crds`** — Installs the eevee Custom Resource Definitions first (dependency for the main release)
2. **`eevee-eevee`** — Depends on `eevee-crds`; deploys:
   - The **eevee operator** (`operator.enabled: true`)
   - All **bot modules** declared under `bot.botModules`
   - Managed **NATS** for inter-module IPC

Each bot module spec includes:

| Field | Purpose |
|-------|---------|
| `size` | Replica count |
| `image` | Container image with tag |
| `pullPolicy` | Image pull policy (typically `Always`) |
| `metrics` | Enable Prometheus metrics endpoint |
| `metricsPort` | Metrics listen port |
| `ipcConfig` | Reference to the IPC config (NATS connection) |
| `moduleName` | Module identifier (e.g., `router`, `connector-irc`) |
| `moduleConfig` | Inline YAML config passed to the module |
| `envSecret` | Reference to a Secret for environment variables |
| `persistentVolumeClaim` | Optional PVC for stateful modules (seen, weather, tell) |
| `mountOperatorApiToken` | Mount the operator API token (admin module) |

### Currently Deployed Modules

| Module | Image | Purpose |
|--------|-------|---------|
| cli | `cli:1.2.15` | Management CLI |
| router | `router:2.4.4` | Message routing and command dispatch |
| admin | `admin:2.6.0` | Administrative commands |
| echo | `echo:1.3.0` | Echo command |
| emote | `emote:1.5.0` | Emoticon commands |
| seen | `seen:1.4.0` | Track user presence (persistent) |
| help | `help:2.4.0` | Help documentation |
| calculator | `calculator:1.4.0` | Math operations |
| dice | `dice:1.4.0` | Dice rolling |
| superslap | `superslap:1.6.0` | Slap command |
| urltitle | `urltitle:2.5.2` | URL title fetching |
| weather | `weather:1.4.0` | Weather lookups (persistent) |
| tell | `tell:2.3.0` | Message relay (persistent) |
| connector-irc | `connector-irc:1.5.7` | IRC network connection |

### Infrastructure Stack

| Component | Purpose |
|-----------|---------|
| Cilium | CNI with eBPF, kube-proxy replacement, WireGuard encryption, BGP, DSR load balancing, dual-stack |
| Traefik | Ingress controller with LoadBalancer IP pools |
| cert-manager | TLS via Let's Encrypt DNS-01 (Cloudflare API) |
| local-path-provisioner | Dynamic local persistent volumes |
| monitoring | Observability stack (Honkwatch) |
| authentik | Identity provider with Traefik middleware |

## Development

```bash
# Clone the repository
git clone ssh://git@github.com/eeveebot/gitops.git
cd gitops

# Validate manifests
kubectl apply --dry-run=client -k flux/

# Edit secrets (requires SOPS age key)
export SOPS_AGE_KEY_FILE="./flux/.sops/flux.agekey"
./flux/decrypt.sh flux/eevee/deploy/weather-secrets.sops.yaml
# ... edit ...
./flux/encrypt.sh flux/eevee/deploy/weather-secrets.sops.yaml
```

## Contributing

See the [eeveebot GitHub organization](https://github.com/eeveebot) for contribution guidelines. Follow the conventions in `AGENTS.md` — small focused commits, conventional commit messages, and always encrypt secrets with SOPS before pushing.

## License

[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) — see [LICENSE](./LICENSE) for the full text.
