# LangChain Service - Troubleshooting Guide

Common issues and solutions for the LangChain Service.

## Table of Contents
1. [Quick Diagnostics](#quick-diagnostics)
2. [Container Issues](#container-issues)
3. [Connection Issues](#connection-issues)
4. [Import/Module Errors](#importmodule-errors)
5. [Performance Issues](#performance-issues)
6. [RAG Issues](#rag-issues)
7. [Agent Issues](#agent-issues)
8. [Memory Issues](#memory-issues)
9. [Log Analysis](#log-analysis)
10. [Recovery Procedures](#recovery-procedures)

---

## Quick Diagnostics

### Health Check Script

```bash
#!/bin/bash
# quick-check.sh

echo "=== LangChain Service Diagnostics ==="

# Check container
echo -n "Container Status: "
docker ps --filter name=langchain-service --format "{{.Status}}" || echo "NOT RUNNING"

# Check health endpoint
echo -n "Health Endpoint: "
curl -s -o /dev/null -w "%{http_code}" http://localhost:8002/health 2>/dev/null || echo "UNREACHABLE"
echo ""

# Check Ollama
echo -n "Ollama: "
curl -s -o /dev/null -w "%{http_code}" http://192.168.0.101:11434/api/tags 2>/dev/null || echo "UNREACHABLE"
echo ""

# Check Qdrant
echo -n "Qdrant: "
curl -s -o /dev/null -w "%{http_code}" http://192.168.0.101:6333/collections 2>/dev/null || echo "UNREACHABLE"
echo ""

# Recent errors
echo "=== Recent Errors ==="
docker logs langchain-service --tail 20 2>&1 | grep -i "error\|exception\|failed" || echo "No recent errors"
```

### One-Liner Checks

```bash
# Container running?
docker ps --filter name=langchain-service

# Health check
curl http://localhost:8002/health

# Recent logs
docker logs langchain-service --tail 50

# Container stats
docker stats langchain-service --no-stream
```

---

## Container Issues

### Container Not Starting

**Symptom:** Container exits immediately or keeps restarting

**Check logs:**
```bash
docker logs langchain-service --tail 100
```

**Common causes:**

#### 1. Import Error
```
ModuleNotFoundError: No module named 'langchain.chains'
```
**Solution:** LangChain 1.x removed `langchain.chains`. Redeploy with updated code:
```bash
ansible-playbook site.yml --tags "langchain"
```

#### 2. Syntax Error in Python
```
SyntaxError: invalid syntax
```
**Solution:** Check for template rendering issues:
```bash
# View rendered file
cat /fast-pool/docker/langchain/build/main.py

# Look for Jinja artifacts like {{ or }}
grep -n "{{" /fast-pool/docker/langchain/build/*.py
```

#### 3. Missing Dependencies
```
ModuleNotFoundError: No module named 'xyz'
```
**Solution:** Add to requirements.txt and rebuild:
```bash
# Add dependency
echo "xyz>=1.0.0" >> /fast-pool/docker/langchain/build/requirements.txt

# Rebuild
docker build -t langchain-service:latest /fast-pool/docker/langchain/build/
docker restart langchain-service
```

### Container Unhealthy

**Symptom:** Container shows `(unhealthy)` status

**Check health:**
```bash
# Test from inside container
docker exec langchain-service curl -s http://localhost:8002/health

# Check health check logs
docker inspect langchain-service --format='{{json .State.Health}}'
```

**Common causes:**

1. **Service not ready yet:** Wait 60 seconds for startup
2. **Port binding issue:** Check port 8002 is exposed
3. **Application crash loop:** Check logs for Python errors

### Container High Memory Usage

**Symptom:** Container using excessive memory

```bash
# Check memory usage
docker stats langchain-service --no-stream

# Check for memory leaks in logs
docker logs langchain-service 2>&1 | grep -i "memory\|oom"
```

**Solutions:**
1. Set memory limits in Docker:
   ```bash
   docker update --memory="4g" langchain-service
   ```
2. Reduce `memory_k` setting to limit conversation history
3. Use `buffer_window` memory type instead of `buffer`

---

## Connection Issues

### Cannot Connect to Service

**Symptom:** `Connection refused` or `Connection timed out`

**Check:**
```bash
# Is container running?
docker ps --filter name=langchain-service

# Is port exposed?
docker port langchain-service

# Is port listening?
ss -tlnp | grep 8002

# Test from server
curl http://localhost:8002/health

# Test from remote
curl http://192.168.0.101:8002/health
```

**Solutions:**

#### Firewall blocking
```bash
# Check UFW
sudo ufw status | grep 8002

# Allow port
sudo ufw allow 8002/tcp
```

#### Docker network issue
```bash
# Check network
docker network inspect ai-network

# Reconnect container
docker network disconnect ai-network langchain-service
docker network connect ai-network langchain-service
```

### Cannot Connect to Ollama

**Symptom:** `Connection refused` when calling Ollama

```bash
# Test Ollama
curl http://192.168.0.101:11434/api/tags

# Check from container
docker exec langchain-service curl http://192.168.0.101:11434/api/tags
```

**Solutions:**

1. **Ollama not running:**
   ```bash
   docker start ollama
   ```

2. **Wrong URL:** Check `OLLAMA_URL` environment variable:
   ```bash
   docker exec langchain-service env | grep OLLAMA
   ```

3. **Network isolation:** Ensure both containers on same network

### Cannot Connect to Qdrant

**Symptom:** `Connection refused` when querying vectors

```bash
# Test Qdrant
curl http://192.168.0.101:6333/collections

# Check from container
docker exec langchain-service curl http://192.168.0.101:6333/collections
```

**Solutions:**

1. **Qdrant not running:**
   ```bash
   docker start qdrant
   ```

2. **Collection doesn't exist:**
   ```bash
   # List collections
   curl http://192.168.0.101:6333/collections

   # Create collection if missing
   curl -X PUT http://192.168.0.101:6333/collections/langchain_general \
     -H "Content-Type: application/json" \
     -d '{"vectors": {"size": 768, "distance": "Cosine"}}'
   ```

---

## Import/Module Errors

### LangChain 1.x Migration Issues

**Error:**
```
ImportError: cannot import name 'AgentExecutor' from 'langchain.agents'
```

**Cause:** LangChain 1.x restructured modules

**Solution:** Use updated imports:
```python
# Old (0.x)
from langchain.chains import LLMChain
from langchain.memory import ConversationBufferMemory
from langchain.agents import AgentExecutor

# New (1.x)
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.messages import HumanMessage, AIMessage
```

### Missing langchain-ollama

**Error:**
```
ModuleNotFoundError: No module named 'langchain_ollama'
```

**Solution:**
```bash
# Add to requirements.txt
echo "langchain-ollama>=0.2.0" >> requirements.txt

# Rebuild
docker build -t langchain-service:latest .
```

### Missing langchain-qdrant

**Error:**
```
ModuleNotFoundError: No module named 'langchain_qdrant'
```

**Solution:**
```bash
# Add to requirements.txt
echo "langchain-qdrant>=0.2.0" >> requirements.txt

# Rebuild
docker build -t langchain-service:latest .
```

---

## Performance Issues

### Slow Response Times

**Diagnosis:**
```bash
# Check response time
time curl -X POST http://localhost:8002/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello"}'

# Check Ollama response time
time curl http://192.168.0.101:11434/api/generate \
  -d '{"model": "llama3.2:3b", "prompt": "Hello"}'
```

**Common causes:**

1. **Model loading:** First request is slow while model loads
2. **Large context:** Reduce `k` in RAG queries
3. **Complex prompts:** Simplify system prompts

**Solutions:**
- Pre-warm models: Make a test request after startup
- Use faster models: `llama3.2:3b` instead of larger models
- Enable GPU: Verify Ollama using GPU

### High CPU Usage

**Check:**
```bash
docker stats langchain-service --no-stream
top -p $(docker inspect -f '{{.State.Pid}}' langchain-service)
```

**Solutions:**
1. Limit concurrent requests
2. Add request rate limiting
3. Increase container CPU allocation

### Timeout Errors

**Symptom:** Requests timing out

**Solutions:**
1. Increase agent timeout:
   ```yaml
   langchain_service:
     agent_timeout: 180  # Increase from 120
   ```

2. Reduce model size for faster responses

3. Add timeout to curl:
   ```bash
   curl --max-time 120 -X POST http://localhost:8002/agent/run ...
   ```

---

## RAG Issues

### No Results Returned

**Symptom:** RAG queries return empty or irrelevant results

**Check collection:**
```bash
# List collections
curl http://192.168.0.101:6333/collections

# Check collection info
curl http://192.168.0.101:6333/collections/langchain_manuals
```

**Solutions:**

1. **Collection empty:** Ingest documents first
   ```bash
   curl -X POST http://192.168.0.101:8087/ingest \
     -F "file=@document.pdf" \
     -F "collection=langchain_manuals"
   ```

2. **Wrong collection name:** Verify collection in query

3. **Low k value:** Increase number of results
   ```json
   {"question": "...", "collection": "...", "k": 10}
   ```

### Poor RAG Quality

**Symptom:** Retrieved documents not relevant

**Solutions:**

1. **Improve chunking:** Adjust chunk size
   ```yaml
   langchain_service:
     chunk_size: 500   # Smaller chunks
     chunk_overlap: 100
   ```

2. **Re-embed documents:** Delete and re-ingest with better settings

3. **Use hybrid search:** Combine keyword and semantic search

### Embedding Model Issues

**Error:**
```
Error: Model 'nomic-embed-text' not found
```

**Solution:**
```bash
# Pull embedding model
ollama pull nomic-embed-text

# Verify
ollama list | grep nomic
```

---

## Agent Issues

### Agent Not Responding

**Symptom:** Agent endpoint hangs or times out

**Check:**
```bash
docker logs langchain-service --tail 50 2>&1 | grep -i agent
```

**Solutions:**

1. **Reduce max iterations:**
   ```yaml
   langchain_service:
     agent_max_iterations: 5  # Lower from 15
   ```

2. **Simplify task:** Break complex tasks into smaller steps

3. **Check tool availability:** Ensure tools can execute

### Tool Execution Failures

**Error in logs:**
```
Tool execution failed: Permission denied
```

**Solutions:**

1. **Docker socket access:** Mount Docker socket
   ```yaml
   volumes:
     - /var/run/docker.sock:/var/run/docker.sock
   ```

2. **Network tools:** Ensure container has network access

3. **File tools:** Verify volume mounts

---

## Memory Issues

### Conversation History Lost

**Symptom:** Previous context not remembered

**Check:**
```bash
# List stored conversations
curl http://localhost:8002/conversations
```

**Solutions:**

1. **Session ID not provided:** Always include `session_id` in requests

2. **Memory cleared:** Don't call clear endpoint unintentionally

3. **Container restart:** Conversations stored in memory are lost on restart
   - Use persistent storage path
   - Or use `ConversationStore` for persistence

### Memory Growing Too Large

**Symptom:** Increasing memory usage over time

**Solutions:**

1. **Use buffer_window:** Limit history length
   ```json
   {"memory_type": "buffer_window", "k": 5}
   ```

2. **Use summary memory:** Condense old conversations
   ```json
   {"memory_type": "summary_buffer"}
   ```

3. **Periodically clear:** Clean up old sessions
   ```bash
   curl -X DELETE http://localhost:8002/memory/old-session/clear
   ```

---

## Log Analysis

### Enable Debug Logging

```bash
# Set environment variable
docker run -e LOG_LEVEL=DEBUG langchain-service:latest

# Or in existing container
docker exec langchain-service sh -c "export LOG_LEVEL=DEBUG"
```

### Log Patterns to Watch

```bash
# Errors
docker logs langchain-service 2>&1 | grep -i "error\|exception"

# Connection issues
docker logs langchain-service 2>&1 | grep -i "connection\|refused\|timeout"

# Memory issues
docker logs langchain-service 2>&1 | grep -i "memory\|oom"

# Ollama issues
docker logs langchain-service 2>&1 | grep -i "ollama"

# Qdrant issues
docker logs langchain-service 2>&1 | grep -i "qdrant"
```

### Export Logs

```bash
# Export recent logs
docker logs langchain-service --since 1h > langchain-logs.txt 2>&1

# Export all logs
docker logs langchain-service > langchain-all-logs.txt 2>&1
```

---

## Recovery Procedures

### Full Service Restart

```bash
# Stop
docker stop langchain-service

# Remove (keeps volumes)
docker rm langchain-service

# Rebuild if needed
docker build -t langchain-service:latest /fast-pool/docker/langchain/build/

# Start fresh
docker run -d \
  --name langchain-service \
  --restart unless-stopped \
  --network ai-network \
  -p 8002:8002 \
  -v /fast-pool/docker/langchain/conversations:/app/conversations \
  langchain-service:latest
```

### Redeploy via Ansible

```bash
cd ~/Github/ubuntu-ai-server/ansible
ansible-playbook site.yml --tags "langchain" -v
```

### Reset to Clean State

```bash
# Stop and remove container
docker stop langchain-service
docker rm langchain-service

# Remove image
docker rmi langchain-service:latest

# Clean conversations (optional)
rm -rf /fast-pool/docker/langchain/conversations/*

# Clean build artifacts
rm -rf /fast-pool/docker/langchain/build/__pycache__

# Redeploy
ansible-playbook site.yml --tags "langchain"
```

### Emergency Recovery

If service is completely broken:

```bash
# 1. Stop everything
docker stop langchain-service
docker rm langchain-service

# 2. Backup current state
cp -r /fast-pool/docker/langchain /tmp/langchain-backup

# 3. Reset git and redeploy
cd ~/Github/ubuntu-ai-server
git checkout -- ansible/roles/langchain-service/
git pull origin main

# 4. Redeploy
cd ansible
ansible-playbook site.yml --tags "langchain"

# 5. Verify
curl http://localhost:8002/health
```

---

## Getting Help

### Collect Diagnostic Information

Before asking for help, collect:

```bash
# System info
echo "=== System Info ===" > diagnostic.txt
uname -a >> diagnostic.txt
docker version >> diagnostic.txt

# Container info
echo "=== Container Status ===" >> diagnostic.txt
docker ps -a --filter name=langchain >> diagnostic.txt
docker inspect langchain-service >> diagnostic.txt

# Logs
echo "=== Recent Logs ===" >> diagnostic.txt
docker logs langchain-service --tail 200 >> diagnostic.txt 2>&1

# Configuration
echo "=== Environment ===" >> diagnostic.txt
docker exec langchain-service env >> diagnostic.txt

# Health
echo "=== Health Check ===" >> diagnostic.txt
curl -s http://localhost:8002/health >> diagnostic.txt
curl -s http://localhost:8002/info >> diagnostic.txt
```

### Report Issues

Include:
1. `diagnostic.txt` output
2. Steps to reproduce
3. Expected vs actual behavior
4. LangChain service version (from `/info` endpoint)
