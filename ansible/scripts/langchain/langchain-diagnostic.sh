#!/bin/bash
# =============================================================================
# LangChain Service Diagnostic Script
# =============================================================================
# Collects diagnostic information for troubleshooting
# Usage: ./langchain-diagnostic.sh [output-file]
# =============================================================================

OUTPUT_FILE="${1:-langchain-diagnostic-$(date +%Y%m%d_%H%M%S).txt}"
CONTAINER_NAME="langchain-service"
SERVICE_URL="http://localhost:8002"

# Colors (disabled for file output)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

log() {
    echo -e "$1" | tee -a "$OUTPUT_FILE"
}

section() {
    log ""
    log "=========================================="
    log "$1"
    log "=========================================="
}

# Start
echo "LangChain Service Diagnostic Report" > "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

section "SYSTEM INFORMATION"
log "Hostname: $(hostname)"
log "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
log "Kernel: $(uname -r)"
log "Date: $(date)"
log "Uptime: $(uptime)"

section "DOCKER INFORMATION"
log "Docker Version:"
docker version 2>&1 | tee -a "$OUTPUT_FILE"

section "CONTAINER STATUS"
log "All LangChain-related containers:"
docker ps -a --filter "name=langchain\|qdrant\|ollama" 2>&1 | tee -a "$OUTPUT_FILE"

section "CONTAINER DETAILS - ${CONTAINER_NAME}"
if docker ps -a --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log "Container exists"
    log ""
    log "Inspect:"
    docker inspect "${CONTAINER_NAME}" 2>&1 | tee -a "$OUTPUT_FILE"
    log ""
    log "Health:"
    docker inspect "${CONTAINER_NAME}" --format='{{json .State.Health}}' 2>&1 | python3 -m json.tool 2>/dev/null | tee -a "$OUTPUT_FILE"
else
    log "Container does not exist"
fi

section "CONTAINER LOGS (Last 200 lines)"
docker logs "${CONTAINER_NAME}" --tail 200 2>&1 | tee -a "$OUTPUT_FILE"

section "NETWORK CONFIGURATION"
log "Docker Networks:"
docker network ls 2>&1 | tee -a "$OUTPUT_FILE"
log ""
log "ai-network details:"
docker network inspect ai-network 2>&1 | tee -a "$OUTPUT_FILE"

section "PORT BINDINGS"
log "Ports in use:"
ss -tlnp 2>/dev/null | grep -E "8002|11434|6333" | tee -a "$OUTPUT_FILE"
log ""
log "Docker port mappings:"
docker port "${CONTAINER_NAME}" 2>&1 | tee -a "$OUTPUT_FILE"

section "ENVIRONMENT VARIABLES"
docker exec "${CONTAINER_NAME}" env 2>&1 | grep -v "^PATH=\|^HOME=\|^HOSTNAME=" | tee -a "$OUTPUT_FILE"

section "SERVICE HEALTH CHECKS"
log "LangChain Health:"
curl -s "${SERVICE_URL}/health" 2>&1 | python3 -m json.tool 2>/dev/null | tee -a "$OUTPUT_FILE" || log "UNREACHABLE"

log ""
log "LangChain Info:"
curl -s "${SERVICE_URL}/info" 2>&1 | python3 -m json.tool 2>/dev/null | tee -a "$OUTPUT_FILE" || log "UNREACHABLE"

log ""
log "Ollama Health:"
curl -s "http://192.168.0.101:11434/api/tags" 2>&1 | python3 -m json.tool 2>/dev/null | head -20 | tee -a "$OUTPUT_FILE" || log "UNREACHABLE"

log ""
log "Qdrant Health:"
curl -s "http://192.168.0.101:6333/collections" 2>&1 | python3 -m json.tool 2>/dev/null | tee -a "$OUTPUT_FILE" || log "UNREACHABLE"

section "RESOURCE USAGE"
log "Container Stats:"
docker stats "${CONTAINER_NAME}" --no-stream 2>&1 | tee -a "$OUTPUT_FILE"

log ""
log "Host Memory:"
free -h 2>&1 | tee -a "$OUTPUT_FILE"

log ""
log "Host Disk:"
df -h /fast-pool 2>&1 | tee -a "$OUTPUT_FILE"

section "PROCESS LIST (Container)"
docker exec "${CONTAINER_NAME}" ps aux 2>&1 | tee -a "$OUTPUT_FILE"

section "INSTALLED PACKAGES (Container)"
docker exec "${CONTAINER_NAME}" pip list 2>&1 | grep -i "langchain\|ollama\|qdrant\|fastapi\|uvicorn" | tee -a "$OUTPUT_FILE"

section "FILE SYSTEM"
log "Build directory contents:"
ls -la /fast-pool/docker/langchain/build/ 2>&1 | tee -a "$OUTPUT_FILE"

log ""
log "Conversations directory:"
ls -la /fast-pool/docker/langchain/conversations/ 2>&1 | tee -a "$OUTPUT_FILE"

section "RECENT ERRORS"
log "Errors in last 1000 log lines:"
docker logs "${CONTAINER_NAME}" --tail 1000 2>&1 | grep -i "error\|exception\|failed\|traceback" | tail -50 | tee -a "$OUTPUT_FILE"

section "ANSIBLE ROLE FILES"
log "LangChain role structure:"
find ~/Github/ubuntu-ai-server/ansible/roles/langchain-service/ -type f -name "*.yml" -o -name "*.j2" 2>/dev/null | head -30 | tee -a "$OUTPUT_FILE"

section "FIREWALL STATUS"
log "UFW Status:"
sudo ufw status 2>&1 | grep -E "8002|11434|6333" | tee -a "$OUTPUT_FILE"

section "SUMMARY"
log ""

# Check container
if docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log "${GREEN}[OK]${NC} Container is running"
else
    log "${RED}[FAIL]${NC} Container is not running"
fi

# Check health
if curl -s "${SERVICE_URL}/health" | grep -q "healthy"; then
    log "${GREEN}[OK]${NC} Service is healthy"
else
    log "${RED}[FAIL]${NC} Service health check failed"
fi

# Check Ollama
if curl -s "http://192.168.0.101:11434/api/tags" >/dev/null 2>&1; then
    log "${GREEN}[OK]${NC} Ollama is reachable"
else
    log "${RED}[FAIL]${NC} Ollama is not reachable"
fi

# Check Qdrant
if curl -s "http://192.168.0.101:6333/collections" >/dev/null 2>&1; then
    log "${GREEN}[OK]${NC} Qdrant is reachable"
else
    log "${RED}[FAIL]${NC} Qdrant is not reachable"
fi

log ""
log "=========================================="
log "Report saved to: ${OUTPUT_FILE}"
log "=========================================="

echo ""
echo "Diagnostic report saved to: ${OUTPUT_FILE}"
