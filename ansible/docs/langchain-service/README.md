# LangChain Service

A unified LangChain API service providing RAG pipelines, autonomous agents, and conversation management for the Ubuntu AI Server stack.

## Overview

The LangChain Service is a FastAPI application that provides:
- **RAG (Retrieval-Augmented Generation)** - Document-based Q&A with Qdrant vector store
- **Conversational RAG** - RAG with chat history support
- **Autonomous Agents** - DevOps and NOC expert agents
- **Q&A Chains** - Direct question answering without retrieval
- **Summary Chains** - Document, log, and config summarization
- **Conversation Memory** - Multiple memory strategies for context management

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      LangChain Service                          │
│                        (Port 8002)                              │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  RAG Chain  │  │   Agents    │  │  Q&A Chain  │             │
│  │             │  │             │  │             │             │
│  │ - Query     │  │ - DevOps    │  │ - General   │             │
│  │ - Conv RAG  │  │ - NOC       │  │ - NOC Expert│             │
│  │             │  │             │  │ - Code      │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                     │
│         └────────────────┼────────────────┘                     │
│                          │                                      │
│  ┌───────────────────────┴───────────────────────┐             │
│  │              Memory Management                 │             │
│  │  - Buffer / Window / Summary / Summary Buffer │             │
│  └───────────────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────────────┘
                    │                       │
                    ▼                       ▼
        ┌───────────────────┐   ┌───────────────────┐
        │      Ollama       │   │      Qdrant       │
        │   (Port 11434)    │   │   (Port 6333)     │
        │                   │   │                   │
        │ - llama3.2:3b     │   │ - Vector Store    │
        │ - codellama:13b   │   │ - Embeddings      │
        │ - mistral:7b      │   │ - Collections     │
        │ - nomic-embed-text│   │                   │
        └───────────────────┘   └───────────────────┘
```

## Features

### RAG Chains
- **RAGChain**: Basic document retrieval and Q&A using LCEL (LangChain Expression Language)
- **ConversationalRAGChain**: RAG with conversation history for context-aware responses

### Agents
- **DevOpsAgent**: Infrastructure management, Docker status, service monitoring
- **NOCAgent**: Network troubleshooting, satellite systems, enterprise networking

### Q&A Chains
- **QAChain**: General purpose question answering
- **NOCExpertChain**: Specialized NOC expertise
- **CodeAnalysisChain**: Code review and generation

### Summary Chains
- **SummaryChain**: General document summarization
- **LogSummaryChain**: Log analysis and pattern detection
- **ConfigSummaryChain**: Configuration analysis and recommendations

### Memory Types
- **Buffer**: Full conversation history
- **Buffer Window**: Last K exchanges
- **Summary**: Condensed conversation summary
- **Summary Buffer**: Hybrid summary + recent messages

## Quick Start

### Test Service Health
```bash
curl http://192.168.0.101:8002/health
```

### Get Service Info
```bash
curl http://192.168.0.101:8002/info
```

### Simple Chat
```bash
curl -X POST http://192.168.0.101:8002/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is Docker?", "model_config": "general"}'
```

### RAG Query
```bash
curl -X POST http://192.168.0.101:8002/rag/query \
  -H "Content-Type: application/json" \
  -d '{
    "question": "How do I configure BGP on Cisco router?",
    "collection": "langchain_manuals",
    "model_config": "noc"
  }'
```

### Run Agent Task
```bash
curl -X POST http://192.168.0.101:8002/agent/run \
  -H "Content-Type: application/json" \
  -d '{
    "task": "Check the status of all Docker containers",
    "agent_type": "devops"
  }'
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Service health check |
| `/info` | GET | Service configuration info |
| `/chat` | POST | Simple Q&A chat |
| `/chat/stream` | POST | Streaming chat response |
| `/rag/query` | POST | RAG-based document Q&A |
| `/rag/conversational` | POST | Conversational RAG |
| `/agent/run` | POST | Execute agent task |
| `/agent/troubleshoot` | POST | NOC troubleshooting workflow |
| `/summarize` | POST | Text summarization |
| `/summarize/log` | POST | Log analysis |
| `/summarize/config` | POST | Config analysis |
| `/memory/create` | POST | Create memory session |
| `/memory/{session_id}/add` | POST | Add to memory |
| `/memory/{session_id}/history` | GET | Get conversation history |
| `/memory/{session_id}/clear` | DELETE | Clear memory |
| `/conversations` | GET | List stored conversations |
| `/conversations/{session_id}` | GET | Get specific conversation |
| `/conversations/{session_id}` | DELETE | Delete conversation |

## Model Configurations

| Config | Model | Temperature | Use Case |
|--------|-------|-------------|----------|
| `general` | llama3.2:3b | 0.7 | General conversations |
| `code` | codellama:13b | 0.2 | Code generation/analysis |
| `noc` | llama3.2:3b | 0.3 | NOC technical assistance |
| `reasoning` | mistral:7b | 0.1 | Complex reasoning |
| `fast` | llama3.2:3b | 0.5 | Quick responses |

## Collection Mappings

| Collection Name | Purpose |
|-----------------|---------|
| `langchain_manuals` | Technical manuals and documentation |
| `langchain_confluence` | Confluence/wiki content |
| `langchain_logs` | Log files and analysis |
| `langchain_configs` | Configuration files |
| `langchain_pcap` | Network packet captures |
| `langchain_code` | Source code |
| `langchain_conversations` | Conversation history |
| `langchain_general` | General purpose storage |

## Integration with Other Services

### Qdrant Vector Database
- URL: `http://192.168.0.101:6333`
- Used for semantic search and document retrieval
- Embeddings generated using `nomic-embed-text`

### Ollama LLM Service
- URL: `http://192.168.0.101:11434`
- Provides all language model capabilities
- Models: llama3.2:3b, codellama:13b, mistral:7b

### RAG Ingestion Service
- URL: `http://192.168.0.101:8087`
- Ingests documents into Qdrant collections
- Parses PDF, DOCX, Markdown files

## Files and Directories

| Path | Description |
|------|-------------|
| `/fast-pool/docker/langchain/` | LangChain service data |
| `/fast-pool/docker/langchain/build/` | Application source code |
| `/fast-pool/docker/langchain/conversations/` | Stored conversations |

## Related Documentation

- [Usage Guide](USAGE.md) - Detailed API usage examples
- [Implementation Guide](IMPLEMENTATION.md) - Code architecture and patterns
- [Deployment Guide](DEPLOYMENT.md) - Installation and configuration
- [Troubleshooting Guide](TROUBLESHOOTING.md) - Common issues and solutions
