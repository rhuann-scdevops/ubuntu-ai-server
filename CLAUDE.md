# Claude AI Context - Ubuntu AI Server

## Project Overview
Ansible automation to configure Ubuntu 24.04 LTS as a production AI/DevOps server.

## Target Server Hardware
- **Hostname**: rhuan-lab-srv02
- **Platform**: Dell Precision 5820 Tower Workstation
- **CPU**: Intel Xeon W-2123 @ 3.60GHz (4 cores/8 threads)
- **RAM**: 128GB DDR4 ECC
- **GPU**: NVIDIA Quadro P4000 8GB GDDR5
- **Storage**:
  - NVMe: 953.9GB Micron (nvme0n1) - Root OS
  - SSD: 447.1GB (sda) - ZFS fast-pool
  - SSD: 447.1GB Kingston SA400 (sdb) - ZFS fast-pool
  - HDD: 1.8TB Seagate ST2000VX008 (sdc) - ZFS bulk-pool
  - HDD: 1.8TB Seagate ST2000DM001 (sdd) - ZFS bulk-pool
- **Network**: eno1 @ 192.168.0.101/24

## Architecture Decisions

### Storage Strategy
1. **NVMe (nvme0n1)**: Root filesystem - Ubuntu 24.04 LTS, system packages
2. **fast-pool**: ZFS mirror of 2x SSDs (~447GB usable)
   - Docker volumes, container data
   - Databases (PostgreSQL, Redis)
   - AI model storage (fast access)
3. **bulk-pool**: ZFS mirror of 2x HDDs (~1.8TB usable)
   - Datasets and training data
   - Backups and snapshots
   - Media and archives

### GPU Utilization
- NVIDIA Quadro P4000 for CUDA workloads
- nvidia-container-toolkit for Docker GPU passthrough
- Primary use: LLM inference, image generation, ML training

### Container Strategy
All services run as Docker containers for isolation and portability:
- AI services with GPU access
- DevOps tools without GPU
- Monitoring stack

## Ansible Role Dependencies

```
base-system
    └── zfs-storage
        └── nvidia-cuda
            └── docker-setup
                ├── ai-stack (requires GPU)
                ├── devops-tools
                └── monitoring
                    └── backup
security (can run independently)
```

## Key Variables (group_vars/all.yml)

```yaml
# Storage
zfs_fast_pool_disks: ["/dev/sda", "/dev/sdb"]
zfs_bulk_pool_disks: ["/dev/sdc", "/dev/sdd"]

# Network
server_ip: "192.168.0.101"
domain: "home.arpa"

# GPU
nvidia_driver_version: "550"  # Latest stable
cuda_version: "12.4"

# AI Stack
ollama_models: ["llama3.2", "codellama", "mistral"]
```

## Common Tasks

### Full Deployment
```bash
ansible-playbook site.yml
```

### Selective Deployment
```bash
# Just storage and GPU
ansible-playbook site.yml --tags "zfs,nvidia"

# Just AI stack
ansible-playbook site.yml --tags "ai-stack"

# Skip security hardening
ansible-playbook site.yml --skip-tags "security"
```

### Verify GPU in Containers
```bash
docker run --rm --gpus all nvidia/cuda:12.2-base-ubuntu22.04 nvidia-smi
```

## File Locations

| Path | Purpose |
|------|---------|
| `/fast-pool/docker` | Docker volumes |
| `/fast-pool/ai-models` | Ollama models, embeddings |
| `/fast-pool/databases` | PostgreSQL, Redis data |
| `/bulk-pool/datasets` | Training data |
| `/bulk-pool/backups` | ZFS snapshots, backups |

## Service Ports

| Port | Service |
|------|---------|
| 22 | SSH |
| 80 | Traefik HTTP |
| 443 | Traefik HTTPS |
| 3000 | Open WebUI |
| 3001 | Gitea |
| 3002 | Grafana |
| 8080 | Traefik Dashboard |
| 9090 | Prometheus |
| 9443 | Portainer |
| 11434 | Ollama API |

## Related Repositories
- `proxmox-ztp`: Proxmox Zero-Touch Provisioning (reference)
- `PVE-HA-Rhuan`: Proxmox HA cluster setup (reference for ZFS, GPU patterns)
