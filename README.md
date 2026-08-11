# latent_forge

Experiments in local AI inference — a collection of documentation and scripts for running, benchmarking, and evaluating large language models locally.

## Overview
Latent Forge documents and automates practical AI infrastructure built from local hardware: model serving, multi-node inference, high-speed networking, storage, containers, accelerators, agent runtimes, monitoring, and performance testing.

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
### Security and reliability

Because this repository is public and contains operational infrastructure examples, security and reliability are treated as part of the design rather than as cleanup work.

- [Security and Reliability](docs/security-reliability.md) — public-repo hygiene, secret handling, service exposure, agent trust boundaries, restart/backoff policy, layered health checks, monitoring guidance, config preflight, and rules for publishing logs and machine-specific details.

The working rule is simple: **make the experiment reproducible without publishing anything that does not need to be public.**

### Local AI operations and model tracking

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
```text
latent_forge/
├── README.md
├── docs/
│   ├── experimentation-log.md
│   ├── hermes-agent.md
│   ├── model-registry.md
│   ├── openclaw-agent.md
│   ├── security-reliability.md
│   └── two-node-gb10-vllm-ray-setup.md
├── inventory/
│   └── ollama-model-inventory-2026-07-16.json
└── scripts/
    ├── benchmark-vllm.sh
    ├── healthcheck.sh
    ├── monitor-local-ai.sh
    ├── start-ray-head.sh
    └── start-ray-worker.sh
```

The repository will expand as additional runtimes, models, accelerators, network layouts, storage patterns, monitoring tools, and agent frameworks are tested.

## Contributing

Open issues or PRs to add new models, scripts, or evaluation datasets.
1. **Document the physical layer.** Cabling, negotiated link speed, routing, and switch-port choice matter.
2. **Pin the working runtime.** Record the container image, CUDA/PyTorch/vLLM versions, and model identifier.
3. **Make networking explicit.** Multi-homed machines should not be allowed to choose distributed-compute paths accidentally.
4. **Persist expensive artifacts.** Model downloads and compilation caches must survive container restarts.
5. **Measure before optimizing.** A configuration that fits a model is not necessarily a configuration that provides low latency.
6. **Separate capacity from throughput.** Multi-node pipeline parallelism can increase model capacity even when single-stream latency does not improve.
7. **Keep application concerns separate.** Latent Forge contains reusable AI infrastructure; application-specific tools, prompts, datasets, and integrations remain with their applications.
8. **Separate the agent layer from the inference layer.** Agent runtimes such as Hermes and OpenClaw should be evaluated independently from Ollama, llama.cpp, vLLM, or cloud model providers.
9. **Preserve failures, not just recipes.** Permission problems, routing mistakes, template incompatibilities, and broken service configurations are part of the experiment and should remain documented after the final configuration works.
10. **Design for a public repository.** Never rely on committed secrets, private data, hard-coded personal paths, or unnecessarily exposed services.
11. **Fail safely.** Validate configuration before starting managed services, use restart backoff, and make unhealthy states obvious rather than silently self-restarting forever.
12. **Monitor without perturbing.** Prefer lightweight observation, distinguish snapshots from time-series evidence, and document how metrics were measured.

## License

See [LICENSE](LICENSE).
Early-stage lab repository. The first documented multi-node configuration is operational and benchmarked, generic local-AI operational assets are being consolidated here, agent runtimes are being evaluated as a separate infrastructure layer, and security/reliability rules now govern what gets published.
