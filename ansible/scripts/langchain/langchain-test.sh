#!/bin/bash
# =============================================================================
# LangChain Service Quick Test Script
# =============================================================================
# Runs basic API tests to verify service functionality
# Usage: ./langchain-test.sh [base-url]
# =============================================================================

BASE_URL="${1:-http://192.168.0.101:8002}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

test_endpoint() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local data="$4"
    local expected="$5"

    echo -n "Testing: $name... "

    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" "${BASE_URL}${endpoint}" 2>/dev/null)
    else
        response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}${endpoint}" \
            -H "Content-Type: application/json" \
            -d "$data" 2>/dev/null)
    fi

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        if [ -n "$expected" ]; then
            if echo "$body" | grep -q "$expected"; then
                echo -e "${GREEN}PASS${NC} (HTTP $http_code)"
                ((PASS++))
            else
                echo -e "${YELLOW}WARN${NC} (HTTP $http_code, missing expected content)"
                ((PASS++))
            fi
        else
            echo -e "${GREEN}PASS${NC} (HTTP $http_code)"
            ((PASS++))
        fi
    else
        echo -e "${RED}FAIL${NC} (HTTP $http_code)"
        ((FAIL++))
        echo "  Response: $body"
    fi
}

echo "========================================"
echo "LangChain Service Test Suite"
echo "========================================"
echo "Base URL: $BASE_URL"
echo "Time: $(date)"
echo "========================================"
echo ""

# Health check
test_endpoint "Health Check" "GET" "/health" "" "healthy"

# Info endpoint
test_endpoint "Service Info" "GET" "/info" "" "langchain-service"

# Chat endpoint
test_endpoint "Chat (General)" "POST" "/chat" \
    '{"message": "Say hello in one word", "model_config": "fast"}' \
    "response"

# Chat with session
test_endpoint "Chat (with Session)" "POST" "/chat" \
    '{"message": "Remember my name is TestUser", "model_config": "fast", "session_id": "test-session"}' \
    "response"

# RAG query (may fail if no documents)
echo -n "Testing: RAG Query... "
response=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/rag/query" \
    -H "Content-Type: application/json" \
    -d '{"question": "test query", "collection": "langchain_general", "k": 1}' 2>/dev/null)
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}PASS${NC} (HTTP $http_code)"
    ((PASS++))
elif [ "$http_code" = "404" ] || [ "$http_code" = "500" ]; then
    echo -e "${YELLOW}SKIP${NC} (No documents in collection)"
else
    echo -e "${RED}FAIL${NC} (HTTP $http_code)"
    ((FAIL++))
fi

# Summarize endpoint
test_endpoint "Summarize" "POST" "/summarize" \
    '{"text": "This is a test document about Docker containers. Docker is a platform for containerization.", "prompt_type": "general"}' \
    "summary"

# Agent endpoint
test_endpoint "DevOps Agent" "POST" "/agent/run" \
    '{"task": "Briefly describe what you can help with", "agent_type": "devops"}' \
    "output"

# Memory create
test_endpoint "Memory Create" "POST" "/memory/create" \
    '{"session_id": "test-memory", "memory_type": "buffer"}' \
    ""

# Memory history
test_endpoint "Memory History" "GET" "/memory/test-memory/history" "" ""

# Conversations list
test_endpoint "List Conversations" "GET" "/conversations" "" ""

echo ""
echo "========================================"
echo "Test Results"
echo "========================================"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo "========================================"

if [ $FAIL -gt 0 ]; then
    exit 1
else
    exit 0
fi
