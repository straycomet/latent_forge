#!/usr/bin/env python3
"""Benchmark tokens-per-second for a locally running Ollama model."""

import argparse
import statistics
import sys
import time

import requests


def run_timed(model: str, prompt: str, host: str) -> float:
    """Run one inference call and return tokens-per-second."""
    url = f"{host.rstrip('/')}/api/generate"
    payload = {"model": model, "prompt": prompt, "stream": False}

    start = time.perf_counter()
    response = requests.post(url, json=payload, timeout=300)
    response.raise_for_status()
    elapsed = time.perf_counter() - start

    data = response.json()
    eval_count = data.get("eval_count", 0)
    if elapsed > 0 and eval_count > 0:
        return eval_count / elapsed
    return 0.0


def main() -> None:
    parser = argparse.ArgumentParser(description="Benchmark a local model via Ollama.")
    parser.add_argument("--model", default="llama3", help="Model name (default: llama3)")
    parser.add_argument("--prompt", default="Hello!", help="Prompt used for each timed run")
    parser.add_argument("--runs", type=int, default=3, help="Number of timed runs (default: 3)")
    parser.add_argument("--host", default="http://localhost:11434", help="Ollama API base URL")
    args = parser.parse_args()

    print(f"Benchmarking model '{args.model}' over {args.runs} run(s)...")
    results: list[float] = []

    for i in range(1, args.runs + 1):
        try:
            tps = run_timed(args.model, args.prompt, args.host)
            results.append(tps)
            print(f"  Run {i}: {tps:.1f} tokens/s")
        except requests.exceptions.ConnectionError:
            print(f"Error: could not connect to Ollama at {args.host}. Is it running?", file=sys.stderr)
            sys.exit(1)
        except requests.exceptions.HTTPError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            sys.exit(1)

    if results:
        print(f"\nResults for '{args.model}':")
        print(f"  Mean:   {statistics.mean(results):.1f} tokens/s")
        print(f"  Median: {statistics.median(results):.1f} tokens/s")
        if len(results) > 1:
            print(f"  Stdev:  {statistics.stdev(results):.1f} tokens/s")


if __name__ == "__main__":
    main()
