# LangChain Service - Usage Guide

Comprehensive guide for using the LangChain Service API endpoints.

## Table of Contents
1. [Basic Chat](#basic-chat)
2. [RAG Queries](#rag-queries)
3. [Agents](#agents)
4. [Summarization](#summarization)
5. [Memory Management](#memory-management)
6. [Conversations](#conversations)
7. [Python SDK Examples](#python-sdk-examples)
8. [JavaScript Examples](#javascript-examples)
9. [n8n Integration](#n8n-integration)

---

## Basic Chat

### Simple Question
```bash
curl -X POST http://192.168.0.101:8002/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Explain what a Docker container is",
    "model_config": "general"
  }'
```

**Response:**
```json
{
  "response": "A Docker container is a lightweight, standalone, executable package...",
  "model": "llama3.2:3b",
  "session_id": null
}
```

### Chat with Session (Memory)
```bash
# First message
curl -X POST http://192.168.0.101:8002/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "My name is John and I work with Cisco routers",
    "session_id": "user-123"
  }'

# Follow-up message (remembers context)
curl -X POST http://192.168.0.101:8002/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What commands should I use for troubleshooting?",
    "session_id": "user-123"
  }'
```

### Streaming Chat
```bash
curl -X POST http://192.168.0.101:8002/chat/stream \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Write a Python function to parse JSON",
    "model_config": "code"
  }'
```

### Model Configurations

| Config | Best For |
|--------|----------|
| `general` | Everyday conversations, explanations |
| `code` | Code generation, debugging, reviews |
| `noc` | Network operations, troubleshooting |
| `reasoning` | Complex analysis, multi-step problems |
| `fast` | Quick, simple responses |

---

## RAG Queries

RAG (Retrieval-Augmented Generation) enhances responses with relevant documents from your knowledge base.

### Basic RAG Query
```bash
curl -X POST http://192.168.0.101:8002/rag/query \
  -H "Content-Type: application/json" \
  -d '{
    "question": "How do I configure OSPF on a Cisco router?",
    "collection": "langchain_manuals"
  }'
```

**Response:**
```json
{
  "answer": "To configure OSPF on a Cisco router, follow these steps...",
  "sources": [
    {
      "content": "OSPF (Open Shortest Path First) is a link-state routing protocol...",
      "metadata": {
        "source": "cisco-ios-guide.pdf",
        "page": 145
      }
    }
  ],
  "model": "llama3.2:3b"
}
```

### RAG with Custom Parameters
```bash
curl -X POST http://192.168.0.101:8002/rag/query \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What are the best practices for BGP configuration?",
    "collection": "langchain_manuals",
    "model_config": "noc",
    "k": 10
  }'
```

### Conversational RAG
Maintains conversation context while retrieving documents:

```bash
# Initial question
curl -X POST http://192.168.0.101:8002/rag/conversational \
  -H "Content-Type: application/json" \
  -d '{
    "question": "What is VRRP?",
    "collection": "langchain_manuals",
    "session_id": "rag-session-1"
  }'

# Follow-up question
curl -X POST http://192.168.0.101:8002/rag/conversational \
  -H "Content-Type: application/json" \
  -d '{
    "question": "How do I configure it on Juniper?",
    "collection": "langchain_manuals",
    "session_id": "rag-session-1"
  }'
```

### Available Collections

| Collection | Content Type |
|------------|--------------|
| `langchain_manuals` | Vendor documentation (Cisco, Juniper, etc.) |
| `langchain_confluence` | Wiki/Confluence pages |
| `langchain_logs` | Log files for analysis |
| `langchain_configs` | Configuration files |
| `langchain_code` | Source code repositories |
| `langchain_general` | General purpose documents |

---

## Agents

Agents can perform multi-step tasks autonomously.

### DevOps Agent
```bash
curl -X POST http://192.168.0.101:8002/agent/run \
  -H "Content-Type: application/json" \
  -d '{
    "task": "Check the health of all running Docker containers and report any issues",
    "agent_type": "devops"
  }'
```

**Response:**
```json
{
  "output": "I analyzed the Docker environment. Here are my findings:\n\n## Container Status\n- langchain-service: healthy\n- qdrant: healthy\n- ollama: healthy\n...",
  "intermediate_steps": []
}
```

### NOC Agent
```bash
curl -X POST http://192.168.0.101:8002/agent/run \
  -H "Content-Type: application/json" \
  -d '{
    "task": "A customer is reporting slow connectivity. Help me troubleshoot.",
    "agent_type": "noc"
  }'
```

### NOC Troubleshooting Workflow
Structured troubleshooting for network issues:

```bash
curl -X POST http://192.168.0.101:8002/agent/troubleshoot \
  -H "Content-Type: application/json" \
  -d '{
    "issue": "Customer site ABC123 experiencing packet loss on satellite link",
    "verbose": true
  }'
```

**Response:**
```json
{
  "issue": "Customer site ABC123 experiencing packet loss on satellite link",
  "analysis": "## Analysis\n\n### Information Gathering\n...\n### Recommendations\n1. Check antenna alignment\n2. Verify modem signal levels...",
  "steps_taken": []
}
```

---

## Summarization

### General Summary
```bash
curl -X POST http://192.168.0.101:8002/summarize \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Long document text here...",
    "prompt_type": "technical"
  }'
```

**Prompt Types:**
- `general` - Concise summary
- `technical` - Technical documentation summary
- `log` - Log analysis summary
- `config` - Configuration summary
- `incident` - Incident report summary

### Log Analysis
```bash
curl -X POST http://192.168.0.101:8002/summarize/log \
  -H "Content-Type: application/json" \
  -d '{
    "log_content": "Jan 9 10:15:32 server sshd[1234]: Failed password for invalid user admin...\nJan 9 10:15:35 server sshd[1234]: Failed password for invalid user root..."
  }'
```

**Response:**
```json
{
  "analysis": "## Status\nWARNING\n\n## Key Events\n- Multiple failed SSH login attempts detected\n\n## Errors Found\n- 15 failed authentication attempts in 5 minutes\n\n## Patterns\n- Brute force attack pattern detected\n\n## Recommendations\n- Enable fail2ban\n- Review SSH configuration",
  "log_length": 1542,
  "line_count": 23
}
```

### Configuration Analysis
```bash
curl -X POST http://192.168.0.101:8002/summarize/config \
  -H "Content-Type: application/json" \
  -d '{
    "config_content": "hostname R1\ninterface GigabitEthernet0/0\n ip address 10.0.0.1 255.255.255.0\n...",
    "config_type": "cisco-ios"
  }'
```

---

## Memory Management

### Create Memory Session
```bash
curl -X POST http://192.168.0.101:8002/memory/create \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "my-session",
    "memory_type": "buffer_window",
    "k": 5
  }'
```

**Memory Types:**
- `buffer` - Full conversation history
- `buffer_window` - Last K exchanges (default K=10)
- `summary` - Summarized conversation
- `summary_buffer` - Summary + recent messages

### Add to Memory
```bash
curl -X POST http://192.168.0.101:8002/memory/my-session/add \
  -H "Content-Type: application/json" \
  -d '{
    "human_input": "What is OSPF?",
    "ai_output": "OSPF is a link-state routing protocol..."
  }'
```

### Get History
```bash
curl http://192.168.0.101:8002/memory/my-session/history
```

### Clear Memory
```bash
curl -X DELETE http://192.168.0.101:8002/memory/my-session/clear
```

---

## Conversations

### List All Conversations
```bash
curl http://192.168.0.101:8002/conversations
```

### Get Specific Conversation
```bash
curl http://192.168.0.101:8002/conversations/my-session
```

### Delete Conversation
```bash
curl -X DELETE http://192.168.0.101:8002/conversations/my-session
```

---

## Python SDK Examples

### Basic Usage
```python
import requests

BASE_URL = "http://192.168.0.101:8002"

# Simple chat
def chat(message: str, model_config: str = "general") -> str:
    response = requests.post(
        f"{BASE_URL}/chat",
        json={"message": message, "model_config": model_config}
    )
    return response.json()["response"]

# RAG query
def rag_query(question: str, collection: str = "langchain_general") -> dict:
    response = requests.post(
        f"{BASE_URL}/rag/query",
        json={"question": question, "collection": collection}
    )
    return response.json()

# Example usage
answer = chat("What is Kubernetes?")
print(answer)

rag_result = rag_query("How to configure OSPF?", "langchain_manuals")
print(rag_result["answer"])
for source in rag_result["sources"]:
    print(f"Source: {source['metadata']}")
```

### Async Client
```python
import asyncio
import aiohttp

async def async_chat(message: str) -> str:
    async with aiohttp.ClientSession() as session:
        async with session.post(
            "http://192.168.0.101:8002/chat",
            json={"message": message}
        ) as response:
            data = await response.json()
            return data["response"]

# Usage
asyncio.run(async_chat("Hello, how are you?"))
```

### Streaming Response
```python
import requests

def stream_chat(message: str):
    response = requests.post(
        "http://192.168.0.101:8002/chat/stream",
        json={"message": message},
        stream=True
    )
    for chunk in response.iter_content(chunk_size=None):
        if chunk:
            print(chunk.decode(), end="", flush=True)

stream_chat("Write a Python function to sort a list")
```

### Full Client Class
```python
from typing import Optional, Dict, Any, List
import requests

class LangChainClient:
    def __init__(self, base_url: str = "http://192.168.0.101:8002"):
        self.base_url = base_url
        self.session = requests.Session()

    def health(self) -> Dict[str, Any]:
        """Check service health."""
        return self.session.get(f"{self.base_url}/health").json()

    def chat(
        self,
        message: str,
        model_config: str = "general",
        session_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Send a chat message."""
        payload = {
            "message": message,
            "model_config": model_config
        }
        if session_id:
            payload["session_id"] = session_id
        return self.session.post(f"{self.base_url}/chat", json=payload).json()

    def rag_query(
        self,
        question: str,
        collection: str = "langchain_general",
        model_config: str = "general",
        k: int = 5
    ) -> Dict[str, Any]:
        """Query with RAG."""
        return self.session.post(
            f"{self.base_url}/rag/query",
            json={
                "question": question,
                "collection": collection,
                "model_config": model_config,
                "k": k
            }
        ).json()

    def run_agent(
        self,
        task: str,
        agent_type: str = "devops"
    ) -> Dict[str, Any]:
        """Run an agent task."""
        return self.session.post(
            f"{self.base_url}/agent/run",
            json={"task": task, "agent_type": agent_type}
        ).json()

    def summarize(
        self,
        text: str,
        prompt_type: str = "general"
    ) -> str:
        """Summarize text."""
        response = self.session.post(
            f"{self.base_url}/summarize",
            json={"text": text, "prompt_type": prompt_type}
        )
        return response.json()["summary"]

# Usage
client = LangChainClient()
print(client.health())
print(client.chat("Hello!"))
```

---

## JavaScript Examples

### Fetch API
```javascript
const BASE_URL = 'http://192.168.0.101:8002';

// Simple chat
async function chat(message, modelConfig = 'general') {
    const response = await fetch(`${BASE_URL}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message, model_config: modelConfig })
    });
    const data = await response.json();
    return data.response;
}

// RAG query
async function ragQuery(question, collection = 'langchain_general') {
    const response = await fetch(`${BASE_URL}/rag/query`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question, collection })
    });
    return await response.json();
}

// Usage
chat('What is Docker?').then(console.log);
ragQuery('How to configure BGP?', 'langchain_manuals').then(console.log);
```

### Axios
```javascript
const axios = require('axios');

const client = axios.create({
    baseURL: 'http://192.168.0.101:8002',
    headers: { 'Content-Type': 'application/json' }
});

async function chat(message) {
    const { data } = await client.post('/chat', { message });
    return data.response;
}

async function ragQuery(question, collection) {
    const { data } = await client.post('/rag/query', { question, collection });
    return data;
}
```

---

## n8n Integration

### Webhook Node Configuration
1. Create HTTP Request node
2. Set Method: POST
3. URL: `http://langchain-service:8002/rag/query`
4. Body Content Type: JSON
5. Body Parameters:
   - `question`: `{{ $json.query }}`
   - `collection`: `langchain_manuals`

### Example Workflow: RAG to Slack

```json
{
  "nodes": [
    {
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "path": "rag-query",
        "httpMethod": "POST"
      }
    },
    {
      "name": "LangChain RAG",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "method": "POST",
        "url": "http://langchain-service:8002/rag/query",
        "bodyContentType": "json",
        "bodyParametersJson": "={{ JSON.stringify({ question: $json.body.question, collection: 'langchain_manuals' }) }}"
      }
    },
    {
      "name": "Slack",
      "type": "n8n-nodes-base.slack",
      "parameters": {
        "channel": "#support",
        "text": "={{ $json.answer }}"
      }
    }
  ]
}
```

### Integration with RAG Ingestion
The LangChain Service works with the RAG Ingestion service (port 8087) for document management:

```bash
# Ingest document
curl -X POST http://192.168.0.101:8087/ingest \
  -F "file=@document.pdf" \
  -F "collection=langchain_manuals" \
  -F "vendor=cisco"

# Then query via LangChain
curl -X POST http://192.168.0.101:8002/rag/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What does this document say about...", "collection": "langchain_manuals"}'
```
