# LangChain Service - Deployment Guide

Complete guide for deploying, configuring, and managing the LangChain Service.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Ansible Deployment](#ansible-deployment)
3. [Manual Deployment](#manual-deployment)
4. [Configuration Options](#configuration-options)
5. [Network Configuration](#network-configuration)
6. [Scaling and Performance](#scaling-and-performance)
7. [Backup and Recovery](#backup-and-recovery)
8. [Upgrading](#upgrading)

---

## Prerequisites

### Required Services

Before deploying LangChain Service, ensure these services are running:

| Service | Port | Purpose | Required |
|---------|------|---------|----------|
| Ollama | 11434 | LLM inference | Yes |
| Qdrant | 6333 | Vector database | Yes |
| Docker | - | Container runtime | Yes |

### Verify Prerequisites

```bash
# Check Ollama
curl http://192.168.0.101:11434/api/tags

# Check Qdrant
curl http://192.168.0.101:6333/collections

# Check Docker
docker info
```

### Required Ollama Models

Pull required models before deployment:

```bash
# Required models
ollama pull llama3.2:3b
ollama pull codellama:13b
ollama pull nomic-embed-text

# Optional models
ollama pull mistral:7b
```

---

## Ansible Deployment

### Full Stack Deployment

Deploy with the entire AI stack:

```bash
cd ~/Github/ubuntu-ai-server/ansible

# Full deployment (includes all prerequisites)
ansible-playbook site.yml

# Or deploy with specific phases
ansible-playbook site.yml --tags "ai-stack,rag,langchain"
```

### LangChain Service Only

Deploy just the LangChain service:

```bash
# Deploy LangChain service
ansible-playbook site.yml --tags "langchain"

# Or with more verbosity
ansible-playbook site.yml --tags "langchain" -v
```

### Ansible Role Structure

```
roles/langchain-service/
├── defaults/
│   └── main.yml           # Default variables
├── tasks/
│   └── main.yml           # Deployment tasks
├── templates/
│   ├── main.py.j2         # FastAPI application
│   ├── config.py.j2       # Configuration
│   ├── Dockerfile.j2      # Container build
│   ├── requirements.txt.j2
│   ├── chains/            # Chain implementations
│   ├── agents/            # Agent implementations
│   ├── tools/             # Tool implementations
│   ├── memory/            # Memory implementations
│   └── utils/             # Utility modules
└── files/
    └── (static files)
```

### Configuration Variables

Set in `group_vars/all/main.yml`:

```yaml
# LangChain Service Configuration
langchain_service:
  enabled: true
  version: "latest"
  port: 8002
  data_path: "/fast-pool/docker/langchain"

  # Model configurations
  default_chat_model: "llama3.2:3b"
  default_code_model: "codellama:13b"
  default_embedding_model: "nomic-embed-text"
  noc_expert_model: "llama3.2:3b"

  # RAG Configuration
  chunk_size: 1000
  chunk_overlap: 200
  retrieval_k: 5

  # Memory Configuration
  memory_type: "buffer"
  memory_k: 10
  max_token_limit: 4000

  # Agent Configuration
  agent_max_iterations: 15
  agent_timeout: 120
```

### Deployment Verification

```bash
# Check deployment status
ansible ai_servers -m shell -a "docker ps --filter name=langchain-service"

# Check service health
ansible ai_servers -m shell -a "curl -s http://localhost:8002/health"

# View logs
ansible ai_servers -m shell -a "docker logs langchain-service --tail 50"
```

---

## Manual Deployment

### Step 1: Create Directories

```bash
sudo mkdir -p /fast-pool/docker/langchain/build
sudo mkdir -p /fast-pool/docker/langchain/conversations
```

### Step 2: Create Application Files

Copy all application files to `/fast-pool/docker/langchain/build/`:

```bash
# main.py, config.py, requirements.txt, Dockerfile
# chains/, agents/, tools/, memory/, utils/
```

### Step 3: Build Docker Image

```bash
cd /fast-pool/docker/langchain/build
docker build -t langchain-service:latest .
```

### Step 4: Run Container

```bash
docker run -d \
  --name langchain-service \
  --restart unless-stopped \
  --network ai-network \
  -p 8002:8002 \
  -v /fast-pool/docker/langchain/conversations:/app/conversations \
  -e OLLAMA_URL=http://192.168.0.101:11434 \
  -e QDRANT_URL=http://192.168.0.101:6333 \
  langchain-service:latest
```

### Step 5: Verify Deployment

```bash
# Check container status
docker ps --filter name=langchain-service

# Check health
curl http://localhost:8002/health

# View logs
docker logs -f langchain-service
```

---

## Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_URL` | `http://192.168.0.101:11434` | Ollama API endpoint |
| `QDRANT_URL` | `http://192.168.0.101:6333` | Qdrant endpoint |
| `QDRANT_HOST` | `192.168.0.101` | Qdrant host (alternative) |
| `QDRANT_PORT` | `6333` | Qdrant port |
| `DEFAULT_CHAT_MODEL` | `llama3.2:3b` | Default chat model |
| `DEFAULT_CODE_MODEL` | `codellama:13b` | Code generation model |
| `DEFAULT_EMBEDDING_MODEL` | `nomic-embed-text` | Embedding model |
| `NOC_EXPERT_MODEL` | `llama3.2:3b` | NOC expert model |
| `CHUNK_SIZE` | `1000` | RAG chunk size |
| `CHUNK_OVERLAP` | `200` | RAG chunk overlap |
| `RETRIEVAL_K` | `5` | Number of documents to retrieve |
| `MEMORY_TYPE` | `buffer` | Default memory type |
| `MEMORY_K` | `10` | Window memory size |
| `MAX_TOKEN_LIMIT` | `4000` | Summary memory token limit |
| `AGENT_MAX_ITERATIONS` | `15` | Max agent iterations |
| `AGENT_TIMEOUT` | `120` | Agent timeout in seconds |
| `LOG_LEVEL` | `INFO` | Logging level |

### Docker Compose Deployment

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  langchain-service:
    image: langchain-service:latest
    build:
      context: ./build
      dockerfile: Dockerfile
    container_name: langchain-service
    restart: unless-stopped
    ports:
      - "8002:8002"
    volumes:
      - ./conversations:/app/conversations
    environment:
      - OLLAMA_URL=http://ollama:11434
      - QDRANT_URL=http://qdrant:6333
      - DEFAULT_CHAT_MODEL=llama3.2:3b
      - LOG_LEVEL=INFO
    networks:
      - ai-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8002/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    depends_on:
      - ollama
      - qdrant

networks:
  ai-network:
    external: true
```

### Production Configuration

For production environments:

```yaml
# docker-compose.prod.yml
services:
  langchain-service:
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "5"
    environment:
      - LOG_LEVEL=WARNING
      - AGENT_MAX_ITERATIONS=10
      - AGENT_TIMEOUT=60
```

---

## Network Configuration

### Docker Network

The service connects to the `ai-network` to communicate with other services:

```bash
# Create network if not exists
docker network create ai-network

# Connect existing containers
docker network connect ai-network ollama
docker network connect ai-network qdrant
docker network connect ai-network langchain-service
```

### Service Discovery

Within Docker network, services can be accessed by name:
- Ollama: `http://ollama:11434`
- Qdrant: `http://qdrant:6333`
- LangChain: `http://langchain-service:8002`

### Firewall Rules

Ensure port 8002 is open:

```bash
# UFW
sudo ufw allow 8002/tcp comment "LangChain API"

# Or via iptables
sudo iptables -A INPUT -p tcp --dport 8002 -j ACCEPT
```

### Reverse Proxy (Traefik)

Add to Traefik configuration:

```yaml
# traefik/dynamic/langchain.yml
http:
  routers:
    langchain:
      rule: "Host(`langchain.home.arpa`)"
      service: langchain
      entryPoints:
        - web
        - websecure

  services:
    langchain:
      loadBalancer:
        servers:
          - url: "http://langchain-service:8002"
```

---

## Scaling and Performance

### Resource Requirements

| Load | CPU | Memory | Notes |
|------|-----|--------|-------|
| Light | 1 core | 1GB | Basic queries |
| Medium | 2 cores | 2GB | Multiple concurrent users |
| Heavy | 4 cores | 4GB | High traffic, agents |

### Performance Tuning

#### Uvicorn Workers

Increase workers for better concurrency:

```dockerfile
# Dockerfile
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8002", "--workers", "4"]
```

#### Connection Pooling

The service uses connection pooling for Qdrant:

```python
# In utils/vectorstore.py
from qdrant_client import QdrantClient

_client = None

def get_qdrant_client() -> QdrantClient:
    global _client
    if _client is None:
        _client = QdrantClient(
            url=settings.qdrant_url,
            prefer_grpc=True  # Use gRPC for better performance
        )
    return _client
```

#### Caching

Add Redis for response caching:

```python
# Optional Redis caching
import redis
from functools import lru_cache

r = redis.Redis(host='redis', port=6379, db=0)

def cached_embedding(text: str) -> list:
    cache_key = f"embedding:{hash(text)}"
    cached = r.get(cache_key)
    if cached:
        return json.loads(cached)
    embedding = compute_embedding(text)
    r.setex(cache_key, 3600, json.dumps(embedding))
    return embedding
```

### Horizontal Scaling

For multiple instances, use Docker Swarm or Kubernetes:

```yaml
# docker-compose.scale.yml
services:
  langchain-service:
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure
```

---

## Backup and Recovery

### Backup Conversations

```bash
# Backup conversations directory
tar -czf langchain-conversations-$(date +%Y%m%d).tar.gz \
  /fast-pool/docker/langchain/conversations/

# Or using rsync
rsync -avz /fast-pool/docker/langchain/conversations/ \
  /bulk-pool/backups/langchain/
```

### Backup Configuration

```bash
# Backup build directory (source code)
tar -czf langchain-build-$(date +%Y%m%d).tar.gz \
  /fast-pool/docker/langchain/build/
```

### Restore Procedure

```bash
# Stop service
docker stop langchain-service

# Restore conversations
tar -xzf langchain-conversations-YYYYMMDD.tar.gz -C /

# Restart service
docker start langchain-service
```

### Automated Backup Script

```bash
#!/bin/bash
# /usr/local/bin/backup-langchain.sh

BACKUP_DIR="/bulk-pool/backups/langchain"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup conversations
tar -czf "$BACKUP_DIR/conversations-$DATE.tar.gz" \
  /fast-pool/docker/langchain/conversations/

# Keep only last 7 days
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/conversations-$DATE.tar.gz"
```

---

## Upgrading

### Standard Upgrade

```bash
cd ~/Github/ubuntu-ai-server/ansible

# Pull latest changes
git pull origin main

# Redeploy
ansible-playbook site.yml --tags "langchain"
```

### Manual Upgrade

```bash
# Pull new image or rebuild
cd /fast-pool/docker/langchain/build
docker build -t langchain-service:latest .

# Recreate container
docker stop langchain-service
docker rm langchain-service

# Start with new image
docker run -d \
  --name langchain-service \
  --restart unless-stopped \
  --network ai-network \
  -p 8002:8002 \
  -v /fast-pool/docker/langchain/conversations:/app/conversations \
  langchain-service:latest
```

### Zero-Downtime Upgrade

For production environments:

```bash
# Build new image with different tag
docker build -t langchain-service:v2 .

# Start new container on different port
docker run -d \
  --name langchain-service-v2 \
  --network ai-network \
  -p 8003:8002 \
  langchain-service:v2

# Test new version
curl http://localhost:8003/health

# Update load balancer to new container
# Then stop old container
docker stop langchain-service
docker rm langchain-service

# Rename new container
docker rename langchain-service-v2 langchain-service

# Update port binding
docker stop langchain-service
docker run -d \
  --name langchain-service \
  --network ai-network \
  -p 8002:8002 \
  langchain-service:v2
```

### Rollback

```bash
# Stop current
docker stop langchain-service

# Start previous version
docker run -d \
  --name langchain-service \
  --network ai-network \
  -p 8002:8002 \
  langchain-service:previous-tag
```

### Version Compatibility

| LangChain Service | Ollama | Qdrant | Python |
|-------------------|--------|--------|--------|
| 1.0.0 | 0.3+ | 1.8+ | 3.11+ |

### Migration Notes

When upgrading from older versions:

1. **v0.x to v1.x**: Updated to LangChain 1.x LCEL patterns
   - Memory module rewritten (no `langchain.memory`)
   - Chains use LCEL (`prompt | llm | parser`)
   - Agents simplified (no `AgentExecutor`)

2. **Qdrant collections**: Existing collections remain compatible

3. **Conversations**: JSON format unchanged, fully compatible
