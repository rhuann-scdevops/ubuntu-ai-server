# Personal RAG Assistant - Architecture Guide

## Overview

The Personal RAG Assistant extends the Ubuntu AI Server with document-aware AI capabilities. It enables your local LLM to answer questions grounded in your technical documentation (Cisco, Palo Alto, Juniper, Versa, satellite vendors, etc.).

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           USER INTERFACES                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │  Open WebUI  │  │ AnythingLLM  │  │    n8n       │  │   API/CLI    │    │
│  │   :3000      │  │   :3005      │  │   :5678      │  │              │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
└─────────┼─────────────────┼─────────────────┼─────────────────┼────────────┘
          │                 │                 │                 │
          ▼                 ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AI & RAG LAYER                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         Ollama (:11434)                               │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │  │
│  │  │ llama3.2:8b │  │codellama:13b│  │ mistral:7b  │  │nomic-embed  │  │  │
│  │  │    (chat)   │  │   (code)    │  │   (chat)    │  │   (embed)   │  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────────┐  │
│  │  RAG Ingestion    │  │      Qdrant       │  │      Neo4j            │  │
│  │    (:8087)        │  │     (:6333)       │  │     (:7474)           │  │
│  │                   │  │                   │  │                       │  │
│  │ • Parse docs      │  │ • Vector store    │  │ • Knowledge graph     │  │
│  │ • Chunk text      │  │ • Similarity      │  │ • Entity relations    │  │
│  │ • Generate embeds │  │   search          │  │ • Concept links       │  │
│  └───────────────────┘  └───────────────────┘  └───────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
          │                                               │
          ▼                                               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AUTOMATION & CODE EXECUTION                          │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────────┐  │
│  │  Open Interpreter │  │       n8n         │  │    MCP Servers        │  │
│  │    (:8086)        │  │     (:5678)       │  │     (:8811)           │  │
│  │                   │  │                   │  │                       │  │
│  │ • Code execution  │  │ • GitHub PRs      │  │ • GitHub integration  │  │
│  │ • Script sandbox  │  │ • Scheduled jobs  │  │ • File operations     │  │
│  │ • Tool use        │  │ • Webhooks        │  │ • Browser automation  │  │
│  └───────────────────┘  └───────────────────┘  └───────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            STORAGE LAYER                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────┐  ┌─────────────────────────────────────┐  │
│  │      fast-pool (SSD)        │  │        bulk-pool (HDD)              │  │
│  │                             │  │                                     │  │
│  │ /fast-pool/docker/rag/      │  │ /bulk-pool/datasets/documents/      │  │
│  │ /fast-pool/ai-models/       │  │   ├── cisco/                        │  │
│  │ /fast-pool/databases/       │  │   ├── paloalto/                     │  │
│  │                             │  │   ├── juniper/                      │  │
│  │ • Qdrant vectors            │  │   ├── versa/                        │  │
│  │ • Neo4j data                │  │   ├── satellite/                    │  │
│  │ • Ollama models             │  │   └── configs/                      │  │
│  └─────────────────────────────┘  └─────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Vector Database (Qdrant)

**Port**: 6333 (HTTP), 6334 (gRPC)
**Purpose**: Store and search document embeddings

Qdrant stores vector embeddings of your document chunks, enabling semantic similarity search. When you ask a question, it finds the most relevant document sections.

**Key Features**:
- Fast similarity search with HNSW algorithm
- Filtering by metadata (vendor, device type, etc.)
- Payload storage for chunk text and metadata

### 2. RAG Ingestion Service

**Port**: 8087
**Purpose**: Document parsing, chunking, and embedding

This custom FastAPI service handles the document ingestion pipeline:

1. **Parse**: Convert PDFs, DOCX, Markdown to text
2. **Chunk**: Split into semantic chunks (512 tokens default)
3. **Embed**: Generate embeddings via Ollama nomic-embed-text
4. **Store**: Insert into Qdrant with metadata

**API Endpoints**:
```
POST /ingest           - Ingest a single document
POST /ingest/batch     - Batch ingest a directory
POST /search           - Search for relevant chunks
POST /upload           - Upload and ingest a file
GET  /health           - Service health check
GET  /stats            - Vector store statistics
```

### 3. Document Parser (Docling API)

**Port**: 8085
**Purpose**: Advanced document parsing

Docling provides enhanced PDF/Office parsing with:
- Table extraction
- Layout preservation
- Heading structure detection
- Code block recognition

### 4. Code Execution Sandbox (Open Interpreter)

**Port**: 8086
**Purpose**: Safe code execution for AI-generated scripts

Allows the AI to generate and execute code in a sandboxed environment:
- Python, Shell, JavaScript
- Docker-in-Docker for container operations
- Results returned to the LLM for iteration

### 5. Workflow Automation (n8n)

**Port**: 5678 (UI), 5679 (Webhooks)
**Purpose**: Multi-step workflow orchestration

n8n provides visual workflow automation for:
- GitHub PR automation with AI code review
- RAG query orchestration
- Infrastructure health monitoring
- Scheduled document ingestion

### 6. Knowledge Graph (Neo4j)

**Port**: 7474 (Browser), 7687 (Bolt)
**Purpose**: Entity relationships and concept mapping

Neo4j stores relationships between:
- Documents and topics
- Vendors and technologies
- Configuration dependencies

## Data Flow

### Document Ingestion Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Upload    │───▶│   Parse     │───▶│   Chunk     │───▶│   Embed     │
│   Document  │    │  (Docling)  │    │  (512 tok)  │    │  (Ollama)   │
└─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘
                                                                 │
                   ┌─────────────┐    ┌─────────────┐           │
                   │   Neo4j     │◀───│   Qdrant    │◀──────────┘
                   │  (graph)    │    │  (vectors)  │
                   └─────────────┘    └─────────────┘
```

### Query Flow (RAG)

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   User      │───▶│   Embed     │───▶│   Search    │───▶│  Retrieve   │
│   Question  │    │   Query     │    │   Qdrant    │    │   Chunks    │
└─────────────┘    └─────────────┘    └─────────────┘    └──────┬──────┘
                                                                 │
                   ┌─────────────┐    ┌─────────────┐           │
                   │   Answer    │◀───│   Ollama    │◀──────────┘
                   │             │    │   LLM       │  (context + question)
                   └─────────────┘    └─────────────┘
```

## Deployment

### Full Deployment

```bash
ansible-playbook site.yml
```

### RAG Stack Only

```bash
ansible-playbook site.yml --tags "rag,rag-stack"
```

### n8n Only

```bash
ansible-playbook site.yml --tags "n8n,automation"
```

## Usage Examples

### 1. Ingest Documents via API

```bash
# Ingest a single PDF
curl -X POST http://192.168.0.101:8087/ingest \
  -H "Content-Type: application/json" \
  -d '{
    "file_path": "/app/documents/cisco/ASA_Config_Guide.pdf",
    "metadata": {
      "vendor": "cisco",
      "device_type": "firewall"
    }
  }'

# Batch ingest a directory
curl -X POST http://192.168.0.101:8087/ingest/batch \
  -H "Content-Type: application/json" \
  -d '{
    "directory": "/app/documents/paloalto",
    "vendor": "paloalto",
    "recursive": true
  }'
```

### 2. Search Documents

```bash
curl -X POST http://192.168.0.101:8087/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "How do I configure NAT on Cisco ASA?",
    "top_k": 5,
    "filter_vendor": "cisco"
  }'
```

### 3. RAG Query via n8n Webhook

```bash
curl -X POST http://192.168.0.101:5679/webhook/rag-query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "What are the steps to configure site-to-site VPN on Palo Alto?",
    "vendor": "paloalto"
  }'
```

### 4. Use OpenWebUI RAG

1. Navigate to http://192.168.0.101:3000
2. Enable RAG in settings
3. Configure Qdrant as vector store:
   - Host: `qdrant`
   - Port: `6333`
4. Upload documents or connect to ingested collection

## Configuration Tuning

### Chunking Strategy

Adjust in `group_vars/all.yml`:

```yaml
rag_stack:
  chunk_size: 512      # Tokens per chunk
  chunk_overlap: 64    # Overlap between chunks
  min_chunk_size: 100  # Minimum chunk size
  max_chunk_size: 1024 # Maximum chunk size
```

**Guidelines**:
- Smaller chunks (256-512): Better for precise Q&A
- Larger chunks (512-1024): Better for summarization
- More overlap: Better context continuity, more storage

### Retrieval Settings

```yaml
rag_stack:
  default_top_k: 5          # Number of chunks to retrieve
  reranking_enabled: false  # Enable reranking model
```

### Embedding Model

The default `nomic-embed-text` provides good balance of quality and speed. For higher quality:

```bash
# Pull a larger embedding model
docker exec ollama ollama pull mxbai-embed-large
```

Update config:
```yaml
EMBEDDING_MODEL: "mxbai-embed-large"
```

## Integration Patterns

### OpenWebUI + RAG

OpenWebUI has built-in RAG support. Configure it to use Qdrant:

1. Settings → RAG
2. Vector DB Type: Qdrant
3. Qdrant URL: http://qdrant:6333
4. Collection: documents

### n8n GitHub Automation

The included workflow `github-pr-automation.json` automatically:
1. Receives PR webhooks
2. Fetches the diff
3. Sends to CodeLlama for review
4. Posts AI review as PR comment

Configure GitHub webhook to: `http://192.168.0.101:5679/webhook/github-pr-webhook`

### Code Execution Pipeline

Use Open Interpreter for executing generated code:

```bash
curl -X POST http://192.168.0.101:8086/execute \
  -H "Content-Type: application/json" \
  -d '{
    "language": "python",
    "code": "import pandas as pd; print(pd.__version__)"
  }'
```

## Monitoring

### Qdrant Dashboard

Access at: http://192.168.0.101:6333/dashboard

View:
- Collection statistics
- Vector count
- Index status

### Service Health

```bash
# Check all RAG services
curl http://192.168.0.101:8087/health

# Response:
{
  "status": "healthy",
  "qdrant": "healthy",
  "ollama": "healthy",
  "neo4j": "healthy"
}
```

### Prometheus Metrics

Add to Prometheus scrape config:
```yaml
scrape_configs:
  - job_name: 'qdrant'
    static_configs:
      - targets: ['qdrant:6333']
```

## Troubleshooting

### Documents Not Found in Search

1. Check ingestion status:
   ```bash
   curl http://192.168.0.101:8087/stats
   ```

2. Verify document was chunked:
   ```bash
   docker logs rag-ingestion
   ```

3. Re-ingest with verbose logging:
   ```bash
   docker exec rag-ingestion python -c "import logging; logging.basicConfig(level=logging.DEBUG)"
   ```

### Slow Search Performance

1. Check Qdrant index status
2. Consider enabling HNSW optimization:
   ```bash
   curl -X POST http://192.168.0.101:6333/collections/documents/index \
     -H "Content-Type: application/json" \
     -d '{"field_name": "text", "field_schema": "text"}'
   ```

### Embedding Errors

1. Verify Ollama is running:
   ```bash
   curl http://192.168.0.101:11434/api/tags
   ```

2. Check embedding model is loaded:
   ```bash
   docker exec ollama ollama list
   ```

3. Pull model if missing:
   ```bash
   docker exec ollama ollama pull nomic-embed-text
   ```

## Service Ports Summary

| Service | Port | Purpose |
|---------|------|---------|
| Qdrant HTTP | 6333 | Vector DB API |
| Qdrant gRPC | 6334 | High-performance API |
| Docling API | 8085 | Document parsing |
| Open Interpreter | 8086 | Code execution |
| RAG Ingestion | 8087 | Ingestion pipeline |
| n8n UI | 5678 | Workflow automation |
| n8n Webhooks | 5679 | External triggers |

## Next Steps

1. **Upload Your Documents**: Copy PDFs/docs to `/bulk-pool/datasets/documents/<vendor>/`
2. **Run Batch Ingestion**: Use the ingestion API to process all documents
3. **Test Queries**: Verify search works with sample questions
4. **Configure OpenWebUI**: Enable RAG and connect to Qdrant
5. **Set Up n8n Workflows**: Import example workflows and customize
