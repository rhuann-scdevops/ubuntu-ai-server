# LangChain Service - Implementation Guide

Technical deep-dive into the LangChain Service architecture, code patterns, and extension points.

## Table of Contents
1. [Project Structure](#project-structure)
2. [Core Components](#core-components)
3. [LangChain 1.x Patterns](#langchain-1x-patterns)
4. [Adding New Chains](#adding-new-chains)
5. [Adding New Agents](#adding-new-agents)
6. [Custom Tools](#custom-tools)
7. [Memory Implementations](#memory-implementations)
8. [Configuration System](#configuration-system)
9. [Testing](#testing)

---

## Project Structure

```
/fast-pool/docker/langchain/build/
├── main.py              # FastAPI application entry point
├── config.py            # Settings and model configurations
├── requirements.txt     # Python dependencies
├── Dockerfile           # Container build configuration
├── chains/
│   ├── __init__.py      # Chain exports
│   ├── rag_chain.py     # RAG chain implementations
│   ├── qa_chain.py      # Q&A chain implementations
│   └── summary_chain.py # Summarization chains
├── agents/
│   ├── __init__.py      # Agent exports
│   ├── devops_agent.py  # DevOps agent implementation
│   └── noc_agent.py     # NOC agent implementation
├── tools/
│   ├── __init__.py      # Tool exports
│   ├── devops_tools.py  # Docker, systemd tools
│   ├── network_tools.py # Ping, DNS, port scan tools
│   └── knowledge_tools.py # Qdrant search tools
├── memory/
│   ├── __init__.py      # Memory exports
│   └── conversation_memory.py # Memory implementations
└── utils/
    ├── __init__.py      # Utility exports
    ├── vectorstore.py   # Qdrant vector store setup
    └── embeddings.py    # Embedding model setup
```

---

## Core Components

### FastAPI Application (main.py)

The main application defines all API endpoints and orchestrates the components:

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="LangChain Service")

# Request models
class ChatRequest(BaseModel):
    message: str
    model_config: str = "general"
    session_id: Optional[str] = None

class RAGQueryRequest(BaseModel):
    question: str
    collection: str = "langchain_general"
    model_config: str = "general"
    k: int = 5

# Endpoints
@app.post("/chat")
async def chat(request: ChatRequest):
    chain = create_qa_chain(model_config=request.model_config)
    response = await chain.ainvoke(request.message)
    return {"response": response, "model": chain.model_name}

@app.post("/rag/query")
async def rag_query(request: RAGQueryRequest):
    vectorstore = get_vectorstore(request.collection)
    chain = create_rag_chain(vectorstore, model_config=request.model_config, k=request.k)
    result = await chain.ainvoke(request.question)
    return result
```

### Configuration (config.py)

Centralized configuration using Pydantic Settings:

```python
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    # Service settings
    service_name: str = "langchain-service"
    debug: bool = False

    # External services
    ollama_url: str = "http://192.168.0.101:11434"
    qdrant_url: str = "http://192.168.0.101:6333"

    # Model defaults
    default_chat_model: str = "llama3.2:3b"
    default_code_model: str = "codellama:13b"
    default_embedding_model: str = "nomic-embed-text"
    noc_expert_model: str = "llama3.2:3b"

    # RAG settings
    chunk_size: int = 1000
    chunk_overlap: int = 200
    retrieval_k: int = 5

    # Memory settings
    memory_type: str = "buffer"
    memory_k: int = 10
    max_token_limit: int = 4000

    # Agent settings
    agent_max_iterations: int = 15
    agent_timeout: int = 120

@lru_cache()
def get_settings() -> Settings:
    return Settings()

# Model configurations for different use cases
MODEL_CONFIGS = {
    "general": {"model": "llama3.2:3b", "temperature": 0.7},
    "code": {"model": "codellama:13b", "temperature": 0.2},
    "noc": {"model": "llama3.2:3b", "temperature": 0.3},
    "reasoning": {"model": "mistral:7b", "temperature": 0.1},
    "fast": {"model": "llama3.2:3b", "temperature": 0.5},
}
```

---

## LangChain 1.x Patterns

### LCEL (LangChain Expression Language)

LangChain 1.x uses LCEL for composing chains. Key patterns:

#### Basic Chain
```python
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_ollama import ChatOllama

# Simple chain: prompt -> llm -> parser
prompt = ChatPromptTemplate.from_template("Answer: {question}")
llm = ChatOllama(model="llama3.2:3b")
chain = prompt | llm | StrOutputParser()

# Invoke
result = chain.invoke({"question": "What is Python?"})
```

#### RAG Chain with Retriever
```python
from langchain_core.runnables import RunnablePassthrough

def format_docs(docs):
    return "\n\n".join(doc.page_content for doc in docs)

# RAG chain: retrieve documents, format, inject into prompt
chain = (
    {
        "context": retriever | format_docs,
        "question": RunnablePassthrough()
    }
    | prompt
    | llm
    | StrOutputParser()
)
```

#### Parallel Execution
```python
from langchain_core.runnables import RunnableParallel

# Execute multiple chains in parallel
parallel = RunnableParallel(
    summary=summary_chain,
    entities=entity_chain,
    sentiment=sentiment_chain
)

result = parallel.invoke({"text": "..."})
# Returns: {"summary": "...", "entities": [...], "sentiment": "..."}
```

### Async Patterns

All chains support async execution:

```python
# Async invoke
result = await chain.ainvoke({"question": "..."})

# Async streaming
async for chunk in chain.astream({"question": "..."}):
    print(chunk, end="")
```

---

## Adding New Chains

### Step 1: Create Chain Class

Create a new file in `chains/` directory:

```python
# chains/my_chain.py
from typing import Optional, Dict, Any
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_ollama import ChatOllama

from config import get_settings, MODEL_CONFIGS

class MyChain:
    """Custom chain for specific use case."""

    def __init__(
        self,
        model_name: Optional[str] = None,
        temperature: float = 0.5
    ):
        self.settings = get_settings()
        self.model_name = model_name or self.settings.default_chat_model
        self.temperature = temperature

        self.llm = ChatOllama(
            base_url=self.settings.ollama_url,
            model=self.model_name,
            temperature=self.temperature
        )

        self.chain = self._build_chain()

    def _build_chain(self):
        """Build the LCEL chain."""
        prompt = ChatPromptTemplate.from_template("""
You are an expert assistant.

{input}

Please provide a detailed response.
""")
        return prompt | self.llm | StrOutputParser()

    async def ainvoke(self, input_text: str) -> str:
        """Async invoke the chain."""
        return await self.chain.ainvoke({"input": input_text})

    def invoke(self, input_text: str) -> str:
        """Sync invoke the chain."""
        return self.chain.invoke({"input": input_text})


def create_my_chain(model_config: str = "general") -> MyChain:
    """Factory function."""
    config = MODEL_CONFIGS.get(model_config, MODEL_CONFIGS["general"])
    return MyChain(
        model_name=config["model"],
        temperature=config["temperature"]
    )
```

### Step 2: Export from __init__.py

```python
# chains/__init__.py
from .my_chain import MyChain, create_my_chain
```

### Step 3: Add API Endpoint

```python
# main.py
from chains import create_my_chain

@app.post("/my-endpoint")
async def my_endpoint(request: MyRequest):
    chain = create_my_chain(model_config=request.model_config)
    result = await chain.ainvoke(request.input)
    return {"result": result}
```

---

## Adding New Agents

### Step 1: Create Agent Class

```python
# agents/my_agent.py
from typing import Optional, List, Dict, Any
from langchain_ollama import ChatOllama
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from langchain_core.output_parsers import StrOutputParser
from langchain_core.messages import HumanMessage, AIMessage

from config import get_settings, MODEL_CONFIGS
from tools import MyTool1, MyTool2  # Your custom tools

MY_AGENT_PROMPT = """You are a specialized agent for...

When performing tasks:
1. First analyze the request
2. Use available tools as needed
3. Provide clear explanations

Available tools:
{tools_description}
"""

class MyAgent:
    """Custom agent implementation."""

    def __init__(
        self,
        model_name: Optional[str] = None,
        temperature: float = 0.2,
        verbose: bool = False
    ):
        self.settings = get_settings()
        self.model_name = model_name or self.settings.default_chat_model
        self.temperature = temperature
        self.verbose = verbose

        self.llm = ChatOllama(
            base_url=self.settings.ollama_url,
            model=self.model_name,
            temperature=self.temperature
        )

        self.tools = [MyTool1(), MyTool2()]
        self.chain = self._build_chain()

    def _build_chain(self):
        prompt = ChatPromptTemplate.from_messages([
            ("system", MY_AGENT_PROMPT),
            MessagesPlaceholder("chat_history", optional=True),
            ("human", "{input}")
        ])
        return prompt | self.llm | StrOutputParser()

    def _format_tools(self) -> str:
        return "\n".join(
            f"- {t.name}: {t.description}" for t in self.tools
        )

    async def ainvoke(
        self,
        task: str,
        chat_history: List[tuple] = None
    ) -> Dict[str, Any]:
        history = []
        if chat_history:
            for human, ai in chat_history:
                history.append(HumanMessage(content=human))
                history.append(AIMessage(content=ai))

        enhanced_task = f"{task}\n\nTools:\n{self._format_tools()}"

        result = await self.chain.ainvoke({
            "input": enhanced_task,
            "chat_history": history
        })

        return {"output": result, "intermediate_steps": []}
```

---

## Custom Tools

### Creating a Tool

```python
# tools/my_tools.py
from langchain_core.tools import BaseTool
from pydantic import BaseModel, Field
from typing import Type

class MyToolInput(BaseModel):
    """Input schema for MyTool."""
    query: str = Field(description="The query to process")
    option: str = Field(default="default", description="Processing option")

class MyTool(BaseTool):
    """Tool description goes here."""

    name: str = "my_tool"
    description: str = "Use this tool to..."
    args_schema: Type[BaseModel] = MyToolInput

    def _run(self, query: str, option: str = "default") -> str:
        """Synchronous execution."""
        # Tool logic here
        return f"Processed: {query} with {option}"

    async def _arun(self, query: str, option: str = "default") -> str:
        """Asynchronous execution."""
        # Async tool logic here
        return f"Processed: {query} with {option}"
```

### Network Tool Example

```python
# tools/network_tools.py
import subprocess
from langchain_core.tools import BaseTool

class PingTool(BaseTool):
    name: str = "ping"
    description: str = "Ping a host to check connectivity"

    def _run(self, host: str, count: int = 4) -> str:
        try:
            result = subprocess.run(
                ["ping", "-c", str(count), host],
                capture_output=True,
                text=True,
                timeout=30
            )
            return result.stdout if result.returncode == 0 else result.stderr
        except subprocess.TimeoutExpired:
            return f"Ping to {host} timed out"
        except Exception as e:
            return f"Error: {str(e)}"
```

---

## Memory Implementations

### Custom Memory Manager

The `MemoryManager` class provides flexible conversation memory:

```python
# memory/conversation_memory.py
from typing import List, Dict, Any
from langchain_core.messages import HumanMessage, AIMessage, BaseMessage

class MemoryManager:
    """Memory manager using LangChain 1.x patterns."""

    def __init__(self, memory_type: str = "buffer", **kwargs):
        self.memory_type = memory_type
        self._messages: List[BaseMessage] = []
        self._k = kwargs.get("k", 10)
        self._summary = ""

    def add_message(self, human_input: str, ai_output: str):
        """Add a conversation exchange."""
        self._messages.append(HumanMessage(content=human_input))
        self._messages.append(AIMessage(content=ai_output))

        # Handle memory type logic
        if self.memory_type == "buffer_window":
            max_messages = self._k * 2
            if len(self._messages) > max_messages:
                self._messages = self._messages[-max_messages:]

    def get_history(self) -> List[BaseMessage]:
        """Get conversation history."""
        return self._messages.copy()

    def get_history_as_tuples(self) -> List[tuple]:
        """Get history as (human, ai) tuples."""
        history = []
        for i in range(0, len(self._messages) - 1, 2):
            if i + 1 < len(self._messages):
                human = self._messages[i].content
                ai = self._messages[i + 1].content
                history.append((human, ai))
        return history

    def clear(self):
        """Clear conversation history."""
        self._messages = []
        self._summary = ""
```

### Using Memory with Chains

```python
# In your chain or agent
memory = MemoryManager(memory_type="buffer_window", k=5)

# After each interaction
memory.add_message(user_question, ai_response)

# Get history for context
history = memory.get_history_as_tuples()

# Use with conversational chain
result = await chain.ainvoke(question, chat_history=history)
```

---

## Configuration System

### Environment Variables

The service reads configuration from environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_URL` | `http://192.168.0.101:11434` | Ollama API endpoint |
| `QDRANT_URL` | `http://192.168.0.101:6333` | Qdrant endpoint |
| `DEFAULT_CHAT_MODEL` | `llama3.2:3b` | Default LLM model |
| `DEFAULT_CODE_MODEL` | `codellama:13b` | Code generation model |
| `DEFAULT_EMBEDDING_MODEL` | `nomic-embed-text` | Embedding model |
| `CHUNK_SIZE` | `1000` | Document chunk size |
| `CHUNK_OVERLAP` | `200` | Chunk overlap |
| `MEMORY_TYPE` | `buffer` | Default memory type |
| `MEMORY_K` | `10` | Window memory size |

### Adding New Configurations

1. Add to `Settings` class in `config.py`
2. Update Ansible template if needed
3. Document in this guide

---

## Testing

### Unit Tests

```python
# tests/test_chains.py
import pytest
from chains import create_qa_chain, create_rag_chain

@pytest.mark.asyncio
async def test_qa_chain():
    chain = create_qa_chain(model_config="fast")
    result = await chain.ainvoke("What is 2+2?")
    assert result is not None
    assert len(result) > 0

@pytest.mark.asyncio
async def test_rag_chain(mock_vectorstore):
    chain = create_rag_chain(mock_vectorstore, k=3)
    result = await chain.ainvoke("Test question")
    assert "answer" in result
    assert "sources" in result
```

### Integration Tests

```python
# tests/test_api.py
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

def test_chat():
    response = client.post("/chat", json={
        "message": "Hello",
        "model_config": "fast"
    })
    assert response.status_code == 200
    assert "response" in response.json()
```

### Running Tests

```bash
# Inside container
docker exec langchain-service pytest tests/ -v

# Or with coverage
docker exec langchain-service pytest tests/ --cov=. --cov-report=html
```
