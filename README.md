# Ubuntu AI Server - Production Monster

Ansible automation to transform Ubuntu 24.04 LTS into a production-ready AI and DevOps powerhouse.

## Server Hardware

| Component | Specification |
|-----------|--------------|
| **Platform** | Dell Precision 5820 Tower |
| **CPU** | Intel Xeon W-2123 @ 3.60GHz (4 cores/8 threads) |
| **RAM** | 128GB DDR4 ECC |
| **GPU** | NVIDIA Quadro P4000 8GB |
| **NVMe** | 953.9GB Micron (Root OS) |
| **SSD 1** | 447.1GB (ZFS Mirror) |
| **SSD 2** | 447.1GB Kingston SA400 (ZFS Mirror) |
| **HDD 1** | 1.8TB Seagate ST2000VX008 (ZFS Mirror) |
| **HDD 2** | 1.8TB Seagate ST2000DM001 (ZFS Mirror) |
| **Network** | 1GbE (eno1) |

## Features

### Storage Architecture
- **NVMe**: Root filesystem (ext4) - OS and system files
- **SSD Pool**: ZFS mirror (~447GB) - Fast storage for containers, databases, AI models
- **HDD Pool**: ZFS mirror (~1.8TB) - Bulk storage for datasets, backups, media

### GPU Stack
- NVIDIA Quadro P4000 with CUDA support
- Container runtime GPU passthrough (nvidia-container-toolkit)
- Optimized for AI/ML workloads

### AI Tools
- **Ollama**: Local LLM inference
- **Open WebUI**: Chat interface for Ollama
- **ComfyUI**: Stable Diffusion workflow
- **LocalAI**: OpenAI-compatible API
- **Text Generation WebUI**: Advanced LLM interface

### DevOps Stack
- **Docker**: Container runtime with compose
- **Portainer**: Container management UI
- **Traefik**: Reverse proxy with auto SSL
- **Gitea**: Self-hosted Git
- **Drone CI**: Continuous integration
- **Harbor**: Container registry

### Monitoring
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Node Exporter**: System metrics
- **NVIDIA DCGM**: GPU metrics
- **Loki**: Log aggregation

## Quick Start

### Prerequisites

1. Ubuntu 24.04 LTS installed on target server
2. SSH access with root/sudo privileges
3. Ansible installed on control machine

```bash
# Install Ansible on control machine (Ubuntu/Debian)
sudo apt update
sudo apt install -y ansible sshpass

# Or via pip
pip install ansible
```

### Setup

1. Clone this repository:
```bash
git clone https://github.com/rhuann-scdevops/ubuntu-ai-server.git
cd ubuntu-ai-server
```

2. Configure inventory:
```bash
cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml
# Edit hosts.yml with your server details
```

3. Review and adjust variables:
```bash
# Edit ansible/group_vars/all.yml for your environment
```

4. Run the playbook:
```bash
cd ansible

# Full deployment
ansible-playbook site.yml

# Or run specific roles
ansible-playbook site.yml --tags "base,zfs"
ansible-playbook site.yml --tags "nvidia,docker"
ansible-playbook site.yml --tags "ai-stack"
```

## Playbook Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── site.yml                 # Main playbook
├── inventory/
│   ├── hosts.yml           # Server inventory (gitignored)
│   └── hosts.yml.example   # Example inventory
├── group_vars/
│   └── all.yml             # Global variables
└── roles/
    ├── base-system/        # OS configuration, packages, users
    ├── zfs-storage/        # ZFS pools for SSDs and HDDs
    ├── nvidia-cuda/        # NVIDIA drivers and CUDA toolkit
    ├── docker-setup/       # Docker, compose, nvidia-toolkit
    ├── ai-stack/           # Ollama, Open WebUI, ComfyUI
    ├── devops-tools/       # Gitea, Drone, Harbor, Traefik
    ├── monitoring/         # Prometheus, Grafana, Loki
    ├── backup/             # Automated backup solutions
    └── security/           # Firewall, fail2ban, hardening
```

## Available Tags

| Tag | Description |
|-----|-------------|
| `base` | Base system configuration |
| `zfs` | ZFS storage pools |
| `nvidia` | NVIDIA drivers and CUDA |
| `docker` | Docker and nvidia-container-toolkit |
| `ai-stack` | AI tools (Ollama, WebUI, etc.) |
| `devops` | DevOps tools (Gitea, Drone, etc.) |
| `monitoring` | Monitoring stack |
| `backup` | Backup configuration |
| `security` | Security hardening |

## Storage Pools

### SSD Pool (fast-pool)
```bash
# Mirror of 2x ~447GB SSDs
zpool create fast-pool mirror /dev/sda /dev/sdb
zfs set compression=lz4 fast-pool
zfs set atime=off fast-pool

# Datasets
zfs create fast-pool/docker      # Docker volumes
zfs create fast-pool/databases   # PostgreSQL, Redis
zfs create fast-pool/ai-models   # LLM models, embeddings
```

### HDD Pool (bulk-pool)
```bash
# Mirror of 2x ~1.8TB HDDs
zpool create bulk-pool mirror /dev/sdc /dev/sdd
zfs set compression=lz4 bulk-pool

# Datasets
zfs create bulk-pool/datasets    # Training data, datasets
zfs create bulk-pool/backups     # System backups
zfs create bulk-pool/media       # Media files
```

## Service Endpoints

After deployment, services are available at:

| Service | URL | Description |
|---------|-----|-------------|
| Portainer | https://server:9443 | Container management |
| Traefik | https://server:8080 | Reverse proxy dashboard |
| Ollama | http://server:11434 | LLM API |
| Open WebUI | http://server:3000 | Chat interface |
| Gitea | http://server:3001 | Git server |
| Grafana | http://server:3002 | Monitoring dashboard |
| Prometheus | http://server:9090 | Metrics |

## GPU Utilization

Check GPU status:
```bash
# NVIDIA driver info
nvidia-smi

# Container GPU access
docker run --rm --gpus all nvidia/cuda:12.2-base-ubuntu22.04 nvidia-smi

# Ollama GPU status
curl http://localhost:11434/api/tags
```

## Maintenance

### ZFS Operations
```bash
# Check pool status
zpool status

# Scrub pools (weekly recommended)
zpool scrub fast-pool
zpool scrub bulk-pool

# Check compression ratio
zfs get compressratio
```

### Backup
```bash
# Manual snapshot
zfs snapshot -r fast-pool@$(date +%Y%m%d)
zfs snapshot -r bulk-pool@$(date +%Y%m%d)

# Send to remote (replace with your backup target)
zfs send fast-pool@snapshot | ssh backup-server zfs recv backup-pool/fast
```

## Troubleshooting

### NVIDIA Driver Issues
```bash
# Check driver loaded
lsmod | grep nvidia

# Reinstall if needed
sudo apt purge nvidia-*
ansible-playbook site.yml --tags nvidia
```

### Docker GPU Access
```bash
# Verify nvidia-container-toolkit
docker info | grep -i nvidia

# Test GPU in container
docker run --rm --gpus all nvidia/cuda:12.2-base-ubuntu22.04 nvidia-smi
```

### ZFS Import Issues
```bash
# List available pools
zpool import

# Force import
zpool import -f pool-name
```

## License

MIT License - See LICENSE file for details.

## Author

Rhuan - DevOps Engineer
