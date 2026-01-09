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
mcp-servers (requires docker-setup)
rag-stack (requires docker-setup, ai-stack)
langchain-service (requires docker-setup, ai-stack, rag-stack)
n8n (requires docker-setup)
docs-generator (requires docker-setup, rag-stack)
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
| 8811 | MCP Gateway |
| 7474 | Neo4j Browser |
| 7687 | Neo4j Bolt |
| 6333 | Qdrant HTTP |
| 6334 | Qdrant gRPC |
| 8085 | Docling API |
| 8086 | Open Interpreter |
| 8087 | RAG Ingestion |
| 5678 | n8n UI |
| 5679 | n8n Webhooks |
| 8002 | LangChain API |
| 8088 | MkDocs Site |
| 8089 | Docs API |

## MCP Servers for AI Autonomy

The server includes MCP (Model Context Protocol) servers that enable AI assistants to interact with external systems:

### Core Infrastructure
- **desktop-commander**: File system access, terminal commands, process management
- **github-official**: Repository management, PRs, issues, code search
- **grafana**: Server monitoring dashboards and alerts
- **database-server**: PostgreSQL/SQLite database access

### AI & Research
- **brave**: Web search for pages, images, news
- **perplexity-ask**: Deep research with web access
- **hugging-face**: ML models, datasets, papers

### Memory & Knowledge
- **memory**: Basic persistent knowledge graph
- **neo4j-memory**: Advanced graph-based memory (bolt://neo4j-mcp:7687)

### Automation
- **puppeteer**: Headless browser automation
- **playwright**: Advanced browser automation for web tasks

### Configuration Paths
| Path | Purpose |
|------|---------|
| `/fast-pool/docker/mcp/config` | MCP configuration files |
| `/fast-pool/docker/mcp/data` | MCP persistent data |
| `/fast-pool/docker/mcp/data/neo4j` | Neo4j graph database |

## Personal RAG Assistant

The server includes a complete RAG (Retrieval-Augmented Generation) stack for document-aware AI:

### Components
- **Qdrant**: Vector database for semantic search (port 6333)
- **Docling API**: Document parsing (PDF, DOCX, Markdown) (port 8085)
- **RAG Ingestion**: Custom pipeline for chunking and embedding (port 8087)
- **Open Interpreter**: Code execution sandbox (port 8086)
- **n8n**: Workflow automation for GitHub, monitoring, etc. (port 5678)

### Document Storage
| Path | Purpose |
|------|---------|
| `/bulk-pool/datasets/documents/cisco` | Cisco documentation |
| `/bulk-pool/datasets/documents/paloalto` | Palo Alto documentation |
| `/bulk-pool/datasets/documents/juniper` | Juniper documentation |
| `/bulk-pool/datasets/documents/versa` | Versa documentation |
| `/bulk-pool/datasets/documents/satellite` | Satellite vendor docs |
| `/bulk-pool/datasets/documents/configs` | Configuration files |

### RAG Data Storage
| Path | Purpose |
|------|---------|
| `/fast-pool/docker/rag/qdrant` | Vector embeddings |
| `/fast-pool/docker/rag/docling` | Parsed documents |
| `/fast-pool/docker/n8n` | Workflow automation data |

### RAG Deployment
```bash
# Deploy RAG stack only
ansible-playbook site.yml --tags "rag,rag-stack"

# Deploy n8n only
ansible-playbook site.yml --tags "n8n,automation"
```

See `docs/PERSONAL-RAG-ASSISTANT.md` for detailed architecture and usage.

## Documentation Generator (RAG → Docs)

The server includes automated documentation generation from RAG queries:

### Components
- **MkDocs Material**: Static documentation site (port 8088)
- **Docs API**: FastAPI service for generating/publishing Markdown (port 8089)
- **n8n Workflows**: Automated pipelines for RAG-to-docs and GitHub publishing

### Endpoints
| Endpoint | Description |
|----------|-------------|
| `POST /generate` | Generate Markdown from RAG query |
| `POST /publish` | Save and optionally git-commit document |
| `POST /generate-and-publish` | Combined endpoint |
| `GET /categories` | List document categories |
| `GET /documents` | List all generated documents |

### Document Categories
| Category | Path | Purpose |
|----------|------|---------|
| Runbooks | `/runbooks` | Operational procedures |
| Guides | `/guides` | Step-by-step configuration guides |
| References | `/references` | Technical reference documentation |
| Troubleshooting | `/troubleshooting` | Problem resolution guides |

### n8n Workflows
- **RAG to Documentation**: Webhook → RAG Search → Ollama Generate → Publish
- **Docs to GitHub**: Webhook → List Docs → Fetch Content → GitHub Push

### Storage Paths
| Path | Purpose |
|------|---------|
| `/fast-pool/docker/rag/docs` | Generated documentation |
| `/fast-pool/docker/rag/docs/site` | MkDocs rendered site |

### Deployment
```bash
# Deploy docs-generator only
ansible-playbook site.yml --tags "docs,docs-generator"

# Full deployment with all phases
ansible-playbook site.yml
```

## LangChain Service

Unified LangChain API service for RAG pipelines, autonomous agents, and conversation management.

### Components
- **RAG Chains**: Document-based Q&A with Qdrant using LCEL
- **Conversational RAG**: RAG with chat history support
- **Agents**: DevOps and NOC expert agents
- **Q&A Chains**: General, NOC expert, and code analysis
- **Summary Chains**: Document, log, and config summarization
- **Memory Management**: Buffer, window, summary, and hybrid memory types

### API Endpoints
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Service health check |
| `/info` | GET | Service configuration |
| `/chat` | POST | Simple Q&A |
| `/chat/stream` | POST | Streaming chat |
| `/rag/query` | POST | RAG document Q&A |
| `/rag/conversational` | POST | Conversational RAG |
| `/agent/run` | POST | Execute agent task |
| `/agent/troubleshoot` | POST | NOC troubleshooting workflow |
| `/summarize` | POST | Text summarization |
| `/summarize/log` | POST | Log analysis |
| `/summarize/config` | POST | Config analysis |
| `/memory/create` | POST | Create memory session |
| `/memory/{id}/history` | GET | Get conversation history |
| `/conversations` | GET | List stored conversations |

### Model Configurations
| Config | Model | Temperature | Use Case |
|--------|-------|-------------|----------|
| `general` | llama3.2:3b | 0.7 | General conversations |
| `code` | codellama:13b | 0.2 | Code generation |
| `noc` | llama3.2:3b | 0.3 | NOC assistance |
| `reasoning` | mistral:7b | 0.1 | Complex reasoning |
| `fast` | llama3.2:3b | 0.5 | Quick responses |

### Collection Mappings
| Collection | Purpose |
|------------|---------|
| `langchain_manuals` | Technical documentation |
| `langchain_confluence` | Wiki content |
| `langchain_logs` | Log files |
| `langchain_configs` | Configuration files |
| `langchain_code` | Source code |
| `langchain_general` | General purpose |

### Storage Paths
| Path | Purpose |
|------|---------|
| `/fast-pool/docker/langchain/` | Service data |
| `/fast-pool/docker/langchain/build/` | Application code |
| `/fast-pool/docker/langchain/conversations/` | Stored conversations |

### Deployment
```bash
# Deploy LangChain service
ansible-playbook site.yml --tags "langchain"

# Check status
curl http://192.168.0.101:8002/health

# Test chat
curl -X POST http://192.168.0.101:8002/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello", "model_config": "fast"}'
```

### Management Scripts
```bash
# Status
./scripts/langchain/langchain-manage.sh status

# Logs
./scripts/langchain/langchain-manage.sh logs

# Restart
./scripts/langchain/langchain-manage.sh restart

# Run tests
./scripts/langchain/langchain-test.sh

# Diagnostics
./scripts/langchain/langchain-diagnostic.sh
```

### Python Client
```python
from scripts.langchain.langchain_client import LangChainClient

client = LangChainClient()
response = client.chat("What is Docker?")
rag_result = client.rag_query("How to configure OSPF?", "langchain_manuals")
```

See `docs/langchain-service/` for detailed documentation:
- `README.md` - Overview and architecture
- `USAGE.md` - API usage examples
- `IMPLEMENTATION.md` - Code patterns and extension
- `DEPLOYMENT.md` - Installation and configuration
- `TROUBLESHOOTING.md` - Common issues and solutions

## Related Repositories
- `proxmox-ztp`: Proxmox Zero-Touch Provisioning (reference)
- `PVE-HA-Rhuan`: Proxmox HA cluster setup (reference for ZFS, GPU patterns)
