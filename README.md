# latent_forge

Experiments in local AI inference — a collection of documentation and scripts for running, benchmarking, and evaluating large language models locally.

## Overview

`latent_forge` provides:

- **Scripts** for downloading models, running inference, and benchmarking performance.
- **Tests** for validating model outputs and infrastructure.
- **Documentation** on setup, usage, and tips for local AI experiments.

## Requirements

- Python 3.10+
- [Ollama](https://ollama.ai) or another local inference backend (e.g. llama.cpp, LM Studio)
- Sufficient VRAM/RAM for the models you want to run (see model-specific notes below)

Install Python dependencies:

```bash
pip install -r requirements.txt
```

## Repository Structure

```
latent_forge/
├── README.md            # This file
├── requirements.txt     # Python dependencies
├── scripts/
│   ├── run_inference.py         # Run a single prompt against a local model
│   ├── benchmark.py             # Benchmark tokens-per-second for a model
│   └── download_model.sh        # Helper to pull a model via Ollama
└── tests/
    ├── test_inference.py        # Smoke tests for the inference script
    └── test_benchmark.py        # Tests for the benchmark script
```

## Quick Start

### 1. Pull a model with Ollama

```bash
bash scripts/download_model.sh llama3
```

### 2. Run inference

```bash
python scripts/run_inference.py --model llama3 --prompt "Explain transformers in one sentence."
```

### 3. Benchmark

```bash
python scripts/benchmark.py --model llama3 --runs 5
```

### 4. Run tests

```bash
python -m pytest tests/
```

## Scripts

### `scripts/run_inference.py`

Sends a prompt to a locally running model via the Ollama HTTP API and prints the response.

| Argument | Default | Description |
|---|---|---|
| `--model` | `llama3` | Model name as known to Ollama |
| `--prompt` | *(required)* | The prompt text |
| `--host` | `http://localhost:11434` | Ollama API base URL |
| `--temperature` | `0.7` | Sampling temperature |

### `scripts/benchmark.py`

Measures tokens-per-second for a given model across multiple runs.

| Argument | Default | Description |
|---|---|---|
| `--model` | `llama3` | Model name |
| `--prompt` | `"Hello!"` | Prompt used for each run |
| `--runs` | `3` | Number of timed runs |
| `--host` | `http://localhost:11434` | Ollama API base URL |

### `scripts/download_model.sh`

Thin wrapper around `ollama pull`. Pass the model name as the first argument.

```bash
bash scripts/download_model.sh mistral
```

## Tips

- Keep models on an NVMe SSD for best load times.
- Prefer quantised models (Q4_K_M or Q5_K_M) for a good quality/speed trade-off on consumer hardware.
- Set `OLLAMA_NUM_PARALLEL=1` to avoid OOM errors when VRAM is tight.

## Contributing

Open issues or PRs to add new models, scripts, or evaluation datasets.

## License

See [LICENSE](LICENSE).
