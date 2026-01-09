#!/usr/bin/env python3
"""
LangChain Service Python Client

A Python client library for interacting with the LangChain Service API.

Usage:
    from langchain_client import LangChainClient

    client = LangChainClient()
    response = client.chat("What is Docker?")
    print(response)
"""

from typing import Optional, Dict, Any, List, Generator
import requests
import json


class LangChainClient:
    """Client for LangChain Service API."""

    def __init__(
        self,
        base_url: str = "http://192.168.0.101:8002",
        timeout: int = 120
    ):
        """
        Initialize the client.

        Args:
            base_url: LangChain Service URL
            timeout: Request timeout in seconds
        """
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update({
            "Content-Type": "application/json"
        })

    def health(self) -> Dict[str, Any]:
        """Check service health."""
        response = self.session.get(
            f"{self.base_url}/health",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()

    def info(self) -> Dict[str, Any]:
        """Get service information."""
        response = self.session.get(
            f"{self.base_url}/info",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()

    def chat(
        self,
        message: str,
        model_config: str = "general",
        session_id: Optional[str] = None
    ) -> str:
        """
        Send a chat message.

        Args:
            message: The message to send
            model_config: Model configuration (general, code, noc, etc.)
            session_id: Optional session ID for conversation memory

        Returns:
            The AI response text
        """
        payload = {
            "message": message,
            "model_config": model_config
        }
        if session_id:
            payload["session_id"] = session_id

        response = self.session.post(
            f"{self.base_url}/chat",
            json=payload,
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()["response"]

    def chat_stream(
        self,
        message: str,
        model_config: str = "general"
    ) -> Generator[str, None, None]:
        """
        Stream a chat response.

        Args:
            message: The message to send
            model_config: Model configuration

        Yields:
            Response chunks
        """
        payload = {
            "message": message,
            "model_config": model_config
        }

        response = self.session.post(
            f"{self.base_url}/chat/stream",
            json=payload,
            stream=True,
            timeout=self.timeout
        )
        response.raise_for_status()

        for chunk in response.iter_content(chunk_size=None):
            if chunk:
                yield chunk.decode('utf-8')

    def rag_query(
        self,
        question: str,
        collection: str = "langchain_general",
        model_config: str = "general",
        k: int = 5
    ) -> Dict[str, Any]:
        """
        Query with RAG (Retrieval-Augmented Generation).

        Args:
            question: The question to ask
            collection: Qdrant collection name
            model_config: Model configuration
            k: Number of documents to retrieve

        Returns:
            Dict with 'answer' and 'sources'
        """
        payload = {
            "question": question,
            "collection": collection,
            "model_config": model_config,
            "k": k
        }

        response = self.session.post(
            f"{self.base_url}/rag/query",
            json=payload,
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()

    def rag_conversational(
        self,
        question: str,
        collection: str = "langchain_general",
        session_id: Optional[str] = None,
        model_config: str = "general",
        k: int = 5
    ) -> Dict[str, Any]:
        """
        Conversational RAG query with history support.

        Args:
            question: The question to ask
            collection: Qdrant collection name
            session_id: Session ID for conversation history
            model_config: Model configuration
            k: Number of documents to retrieve

        Returns:
            Dict with 'answer' and 'sources'
        """
        payload = {
            "question": question,
            "collection": collection,
            "model_config": model_config,
            "k": k
        }
        if session_id:
            payload["session_id"] = session_id

        response = self.session.post(
            f"{self.base_url}/rag/conversational",
            json=payload,
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()

    def run_agent(
        self,
        task: str,
        agent_type: str = "devops",
        verbose: bool = False
    ) -> Dict[str, Any]:
        """
        Run an agent task.

        Args:
            task: The task description
            agent_type: Agent type (devops, noc)
            verbose: Enable verbose output

        Returns:
            Dict with 'output' and 'intermediate_steps'
        """
        payload = {
            "task": task,
            "agent_type": agent_type,
            "verbose": verbose
        }

        response = self.session.post(
            f"{self.base_url}/agent/run",
            json=payload,
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()

    def troubleshoot(
        self,
        issue: str,
        verbose: bool = False
    ) -> Dict[str, Any]:
        """
        NOC troubleshooting workflow.

        Args:
            issue: Description of the issue
            verbose: Enable verbose output

        Returns:
            Dict with 'issue', 'analysis', and 'steps_taken'
        """
        payload = {
            "issue": issue,
            "verbose": verbose
        }

        response = self.session.post(
            f"{self.base_url}/agent/troubleshoot",
            json=payload,
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()

    def summarize(
        self,
        text: str,
        prompt_type: str = "general",
        model_config: str = "general"
    ) -> str:
        """
        Summarize text content.

        Args:
            text: Text to summarize
            prompt_type: Type of summary (general, technical, log, config, incident)
            model_config: Model configuration

        Returns:
            Summary text
        """
        payload = {
            "text": text,
            "prompt_type": prompt_type,
            "model_config": model_config
        }

        response = self.session.post(
            f"{self.base_url}/summarize",
            json=payload,
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()["summary"]

    def analyze_logs(
        self,
        log_content: str,
        model_config: str = "general"
    ) -> Dict[str, Any]:
        """
        Analyze log content.

        Args:
            log_content: Log text to analyze
            model_config: Model configuration

        Returns:
            Dict with 'analysis', 'log_length', 'line_count'
        """
        payload = {
            "log_content": log_content,
            "model_config": model_config
        }

        response = self.session.post(
            f"{self.base_url}/summarize/log",
            json=payload,
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()

    def analyze_config(
        self,
        config_content: str,
        config_type: str = "generic",
        model_config: str = "general"
    ) -> Dict[str, Any]:
        """
        Analyze configuration content.

        Args:
            config_content: Configuration text to analyze
            config_type: Type of configuration (cisco-ios, junos, etc.)
            model_config: Model configuration

        Returns:
            Dict with 'analysis', 'config_type', 'config_length'
        """
        payload = {
            "config_content": config_content,
            "config_type": config_type,
            "model_config": model_config
        }

        response = self.session.post(
            f"{self.base_url}/summarize/config",
            json=payload,
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()

    def create_memory(
        self,
        session_id: str,
        memory_type: str = "buffer",
        **kwargs
    ) -> Dict[str, Any]:
        """
        Create a memory session.

        Args:
            session_id: Session identifier
            memory_type: Memory type (buffer, buffer_window, summary, summary_buffer)
            **kwargs: Additional parameters (k for buffer_window, etc.)

        Returns:
            Confirmation dict
        """
        payload = {
            "session_id": session_id,
            "memory_type": memory_type,
            **kwargs
        }

        response = self.session.post(
            f"{self.base_url}/memory/create",
            json=payload,
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()

    def get_memory_history(self, session_id: str) -> List[Dict[str, str]]:
        """
        Get conversation history for a session.

        Args:
            session_id: Session identifier

        Returns:
            List of message dicts
        """
        response = self.session.get(
            f"{self.base_url}/memory/{session_id}/history",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()["history"]

    def clear_memory(self, session_id: str) -> Dict[str, Any]:
        """
        Clear memory for a session.

        Args:
            session_id: Session identifier

        Returns:
            Confirmation dict
        """
        response = self.session.delete(
            f"{self.base_url}/memory/{session_id}/clear",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()

    def list_conversations(self) -> List[Dict[str, Any]]:
        """
        List all stored conversations.

        Returns:
            List of conversation metadata
        """
        response = self.session.get(
            f"{self.base_url}/conversations",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()["conversations"]

    def get_conversation(self, session_id: str) -> Dict[str, Any]:
        """
        Get a specific conversation.

        Args:
            session_id: Session identifier

        Returns:
            Conversation data
        """
        response = self.session.get(
            f"{self.base_url}/conversations/{session_id}",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()

    def delete_conversation(self, session_id: str) -> Dict[str, Any]:
        """
        Delete a conversation.

        Args:
            session_id: Session identifier

        Returns:
            Confirmation dict
        """
        response = self.session.delete(
            f"{self.base_url}/conversations/{session_id}",
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()


# CLI interface
if __name__ == "__main__":
    import argparse
    import sys

    parser = argparse.ArgumentParser(description="LangChain Service CLI")
    parser.add_argument(
        "--url",
        default="http://192.168.0.101:8002",
        help="Service URL"
    )

    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Health command
    subparsers.add_parser("health", help="Check service health")

    # Info command
    subparsers.add_parser("info", help="Get service info")

    # Chat command
    chat_parser = subparsers.add_parser("chat", help="Send chat message")
    chat_parser.add_argument("message", help="Message to send")
    chat_parser.add_argument(
        "-m", "--model",
        default="general",
        help="Model config"
    )
    chat_parser.add_argument(
        "-s", "--session",
        help="Session ID"
    )

    # RAG command
    rag_parser = subparsers.add_parser("rag", help="RAG query")
    rag_parser.add_argument("question", help="Question to ask")
    rag_parser.add_argument(
        "-c", "--collection",
        default="langchain_general",
        help="Collection name"
    )
    rag_parser.add_argument(
        "-k",
        type=int,
        default=5,
        help="Number of documents"
    )

    # Agent command
    agent_parser = subparsers.add_parser("agent", help="Run agent task")
    agent_parser.add_argument("task", help="Task description")
    agent_parser.add_argument(
        "-t", "--type",
        default="devops",
        choices=["devops", "noc"],
        help="Agent type"
    )

    # Summarize command
    sum_parser = subparsers.add_parser("summarize", help="Summarize text")
    sum_parser.add_argument("text", help="Text to summarize (or - for stdin)")
    sum_parser.add_argument(
        "-p", "--prompt-type",
        default="general",
        help="Prompt type"
    )

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    client = LangChainClient(base_url=args.url)

    try:
        if args.command == "health":
            result = client.health()
            print(json.dumps(result, indent=2))

        elif args.command == "info":
            result = client.info()
            print(json.dumps(result, indent=2))

        elif args.command == "chat":
            response = client.chat(
                args.message,
                model_config=args.model,
                session_id=args.session
            )
            print(response)

        elif args.command == "rag":
            result = client.rag_query(
                args.question,
                collection=args.collection,
                k=args.k
            )
            print("Answer:", result["answer"])
            print("\nSources:")
            for i, source in enumerate(result["sources"], 1):
                print(f"  {i}. {source['metadata']}")

        elif args.command == "agent":
            result = client.run_agent(args.task, agent_type=args.type)
            print(result["output"])

        elif args.command == "summarize":
            text = args.text
            if text == "-":
                text = sys.stdin.read()
            summary = client.summarize(text, prompt_type=args.prompt_type)
            print(summary)

    except requests.exceptions.RequestException as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
