#!/bin/bash
# =============================================================================
# LangChain Service Management Script
# =============================================================================
# Usage: ./langchain-manage.sh [command]
#
# Commands:
#   status      - Show service status
#   start       - Start the service
#   stop        - Stop the service
#   restart     - Restart the service
#   logs        - Show recent logs
#   health      - Check service health
#   rebuild     - Rebuild and restart
#   deploy      - Deploy via Ansible
#   backup      - Backup conversations
#   test        - Run API tests
# =============================================================================

set -e

# Configuration
CONTAINER_NAME="langchain-service"
SERVICE_URL="http://localhost:8002"
BUILD_DIR="/fast-pool/docker/langchain/build"
BACKUP_DIR="/bulk-pool/backups/langchain"
ANSIBLE_DIR="${HOME}/Github/ubuntu-ai-server/ansible"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if container exists
container_exists() {
    docker ps -a --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Check if container is running
container_running() {
    docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Status command
cmd_status() {
    echo "=== LangChain Service Status ==="
    echo ""

    if container_running; then
        log_success "Container is running"
        echo ""
        docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""

        # Check health
        echo "Health Check:"
        HEALTH=$(curl -s "${SERVICE_URL}/health" 2>/dev/null || echo '{"status":"unreachable"}')
        echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
    else
        log_error "Container is not running"
        if container_exists; then
            echo ""
            echo "Container exists but stopped:"
            docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}"
        fi
    fi
}

# Start command
cmd_start() {
    if container_running; then
        log_warn "Container is already running"
        return
    fi

    log_info "Starting ${CONTAINER_NAME}..."

    if container_exists; then
        docker start "${CONTAINER_NAME}"
    else
        log_error "Container does not exist. Use 'deploy' or 'rebuild' first."
        exit 1
    fi

    # Wait for health
    log_info "Waiting for service to be healthy..."
    for i in {1..30}; do
        if curl -s "${SERVICE_URL}/health" >/dev/null 2>&1; then
            log_success "Service is healthy"
            return
        fi
        sleep 2
    done

    log_warn "Service may not be fully ready yet"
}

# Stop command
cmd_stop() {
    if ! container_running; then
        log_warn "Container is not running"
        return
    fi

    log_info "Stopping ${CONTAINER_NAME}..."
    docker stop "${CONTAINER_NAME}"
    log_success "Container stopped"
}

# Restart command
cmd_restart() {
    log_info "Restarting ${CONTAINER_NAME}..."

    if container_running; then
        docker restart "${CONTAINER_NAME}"
    else
        cmd_start
    fi

    # Wait for health
    log_info "Waiting for service to be healthy..."
    for i in {1..30}; do
        if curl -s "${SERVICE_URL}/health" >/dev/null 2>&1; then
            log_success "Service is healthy"
            return
        fi
        sleep 2
    done

    log_warn "Service may not be fully ready yet"
}

# Logs command
cmd_logs() {
    LINES="${1:-100}"
    log_info "Showing last ${LINES} lines of logs..."
    echo ""
    docker logs "${CONTAINER_NAME}" --tail "${LINES}" 2>&1
}

# Health command
cmd_health() {
    echo "=== Service Health ==="
    echo ""

    echo "LangChain Service:"
    curl -s "${SERVICE_URL}/health" | python3 -m json.tool 2>/dev/null || echo "UNREACHABLE"
    echo ""

    echo "Ollama:"
    curl -s "http://192.168.0.101:11434/api/tags" >/dev/null 2>&1 && echo "OK" || echo "UNREACHABLE"
    echo ""

    echo "Qdrant:"
    curl -s "http://192.168.0.101:6333/collections" >/dev/null 2>&1 && echo "OK" || echo "UNREACHABLE"
    echo ""

    echo "=== Service Info ==="
    curl -s "${SERVICE_URL}/info" | python3 -m json.tool 2>/dev/null || echo "UNREACHABLE"
}

# Rebuild command
cmd_rebuild() {
    log_info "Rebuilding ${CONTAINER_NAME}..."

    # Stop if running
    if container_running; then
        log_info "Stopping existing container..."
        docker stop "${CONTAINER_NAME}"
    fi

    # Remove if exists
    if container_exists; then
        log_info "Removing existing container..."
        docker rm "${CONTAINER_NAME}"
    fi

    # Build image
    log_info "Building Docker image..."
    docker build -t langchain-service:latest "${BUILD_DIR}"

    # Run container
    log_info "Starting container..."
    docker run -d \
        --name "${CONTAINER_NAME}" \
        --restart unless-stopped \
        --network ai-network \
        -p 8002:8002 \
        -v /fast-pool/docker/langchain/conversations:/app/conversations \
        -e OLLAMA_URL=http://192.168.0.101:11434 \
        -e QDRANT_URL=http://192.168.0.101:6333 \
        langchain-service:latest

    # Wait for health
    log_info "Waiting for service to be healthy..."
    for i in {1..60}; do
        if curl -s "${SERVICE_URL}/health" >/dev/null 2>&1; then
            log_success "Service is healthy"
            return
        fi
        sleep 2
    done

    log_error "Service failed to start. Check logs with: $0 logs"
    exit 1
}

# Deploy command
cmd_deploy() {
    log_info "Deploying via Ansible..."

    if [ ! -d "${ANSIBLE_DIR}" ]; then
        log_error "Ansible directory not found: ${ANSIBLE_DIR}"
        exit 1
    fi

    cd "${ANSIBLE_DIR}"
    ansible-playbook site.yml --tags "langchain" -v

    log_success "Deployment complete"
}

# Backup command
cmd_backup() {
    DATE=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/langchain-backup-${DATE}.tar.gz"

    log_info "Creating backup..."

    mkdir -p "${BACKUP_DIR}"

    tar -czf "${BACKUP_FILE}" \
        -C /fast-pool/docker/langchain \
        conversations build 2>/dev/null || true

    log_success "Backup created: ${BACKUP_FILE}"

    # Cleanup old backups (keep last 7)
    log_info "Cleaning up old backups..."
    ls -t "${BACKUP_DIR}"/langchain-backup-*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm

    # List backups
    echo ""
    echo "Available backups:"
    ls -lh "${BACKUP_DIR}"/langchain-backup-*.tar.gz 2>/dev/null || echo "No backups found"
}

# Test command
cmd_test() {
    echo "=== Running API Tests ==="
    echo ""

    # Test health
    echo "1. Health Check:"
    curl -s "${SERVICE_URL}/health" | python3 -m json.tool
    echo ""

    # Test info
    echo "2. Service Info:"
    curl -s "${SERVICE_URL}/info" | python3 -m json.tool
    echo ""

    # Test chat
    echo "3. Chat Test:"
    curl -s -X POST "${SERVICE_URL}/chat" \
        -H "Content-Type: application/json" \
        -d '{"message": "Say hello in one word", "model_config": "fast"}' | python3 -m json.tool
    echo ""

    # Test RAG (if collection exists)
    echo "4. RAG Test (may fail if no documents):"
    curl -s -X POST "${SERVICE_URL}/rag/query" \
        -H "Content-Type: application/json" \
        -d '{"question": "test query", "collection": "langchain_general", "k": 1}' | python3 -m json.tool 2>/dev/null || echo "No documents in collection"
    echo ""

    log_success "Tests complete"
}

# Help
cmd_help() {
    echo "LangChain Service Management Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status      Show service status"
    echo "  start       Start the service"
    echo "  stop        Stop the service"
    echo "  restart     Restart the service"
    echo "  logs [n]    Show recent logs (default: 100 lines)"
    echo "  health      Check service and dependencies health"
    echo "  rebuild     Rebuild Docker image and restart"
    echo "  deploy      Deploy via Ansible"
    echo "  backup      Backup conversations and config"
    echo "  test        Run API tests"
    echo "  help        Show this help message"
    echo ""
}

# Main
case "${1:-help}" in
    status)
        cmd_status
        ;;
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    logs)
        cmd_logs "${2:-100}"
        ;;
    health)
        cmd_health
        ;;
    rebuild)
        cmd_rebuild
        ;;
    deploy)
        cmd_deploy
        ;;
    backup)
        cmd_backup
        ;;
    test)
        cmd_test
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        log_error "Unknown command: $1"
        cmd_help
        exit 1
        ;;
esac
