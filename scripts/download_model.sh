#!/usr/bin/env env bash
# Pull a model via Ollama.
# Usage: bash download_model.sh <model_name>

set -euo pipefail

MODEL="${1:-}"

if [[ -z "$MODEL" ]]; then
  echo "Usage: $0 <model_name>" >&2
  echo "Example: $0 llama3" >&2
  exit 1
fi

if ! command -v ollama &>/dev/null; then
  echo "Error: 'ollama' is not installed or not in PATH." >&2
  echo "Install it from https://ollama.ai" >&2
  exit 1
fi

echo "Pulling model: $MODEL"
ollama pull "$MODEL"
echo "Done."
