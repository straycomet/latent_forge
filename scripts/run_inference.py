#!/usr/bin/env python3
"""Run a single prompt against a locally running Ollama model."""

import argparse
import sys

import requests


def run_inference(model: str, prompt: str, host: str, temperature: float) -> str:
    """Send a prompt to Ollama and return the response text."""
    url = f"{host.rstrip('/')}/api/generate"
    payload = {
        "model": model,
        "prompt": prompt,
        "options": {"temperature": temperature},
        "stream": False,
    }
    response = requests.post(url, json=payload, timeout=120)
    response.raise_for_status()
    return response.json().get("response", "")


def main() -> None:
    parser = argparse.ArgumentParser(description="Run inference against a local model via Ollama.")
    parser.add_argument("--model", default="llama3", help="Model name (default: llama3)")
    parser.add_argument("--prompt", required=True, help="Prompt text")
    parser.add_argument("--host", default="http://localhost:11434", help="Ollama API base URL")
    parser.add_argument("--temperature", type=float, default=0.7, help="Sampling temperature")
    args = parser.parse_args()

    try:
        result = run_inference(args.model, args.prompt, args.host, args.temperature)
        print(result)
    except requests.exceptions.ConnectionError:
        print(f"Error: could not connect to Ollama at {args.host}. Is it running?", file=sys.stderr)
        sys.exit(1)
    except requests.exceptions.HTTPError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
