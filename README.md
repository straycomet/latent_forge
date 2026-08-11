# Latent Forge

**Open-source infrastructure experiments for local and distributed AI.**

Latent Forge documents and automates practical AI infrastructure built from local hardware: model serving, multi-node inference, high-speed networking, storage, containers, accelerators, agent runtimes, and performance testing.

The focus is reproducibility. Each experiment records the hardware, network topology, runtime configuration, exact commands that worked, validation steps, measured results, and a short postmortem for failures that materially changed the final design.

## Current experiments

### Two-node NVIDIA GB10 inference with vLLM + Ray

A dense, unquantized `Qwen/Qwen3-32B` model was split across two NVIDIA GB10 nodes using vLLM pipeline parallelism over a dedicated 10 GbE network.

Validated results:

- 2 physical GB10 nodes
- Ray distributed executor
- pipeline parallelism: 2 stages
- tensor parallelism: 1
- dedicated 10 GbE path: ~9.4 Gbit/s each direction
- model: `Qwen/Qwen3-32B`, BF16/unquantized
- context: 16,384 tokens
- single request: ~3.6 completion tokens/s
- four concurrent requests: ~14.0 completion tokens/s aggregate

Full setup and benchmark:

- [Two-Node NVIDIA GB10 vLLM + Ray Setup and Benchmark](docs/two-node-gb10-vllm-ray-setup.md)

### Agent runtimes: Hermes and OpenClaw

Latent Forge also records hands-on evaluations of general-purpose autonomous-agent runtimes rather than treating them as interchangeable wrappers around an LLM.

- [Hermes Agent — Setup, Use, and Lab Evaluation](docs/hermes-agent.md) — current preferred agent runtime; solid in our testing, with good diagnostics, persistent memory, skills, messaging gateways, and broad provider support.
- [OpenClaw — Setup, Use, and Lab Evaluation](docs/openclaw-agent.md) — compelling architecture and broad channel support, but substantially more operationally fragile in our lab. The notes preserve Docker permission failures, state/device issues, a systemd restart loop caused by invalid config, and a local Gemma/llama.cpp chat-template incompatibility.

The current lab conclusion is deliberately empirical: **Hermes is preferred; OpenClaw remains experimental and worth periodically retesting.**

### Local AI operations and model tracking

The repository also contains reusable local-AI operational assets that were separated from the ChartSense application repository:

- [Model registry](docs/model-registry.md) — historical model choices and lessons learned
- [Experimentation log](docs/experimentation-log.md) — infrastructure experiments such as remote Open WebUI over Tailscale
- [Ollama inventory snapshot](inventory/ollama-model-inventory-2026-07-16.json) — a point-in-time local model inventory
- `scripts/healthcheck.sh` — generic checks for Docker, SSH, Tailscale, Ollama, Open WebUI, disk, and NVIDIA GPU visibility
- `scripts/monitor-local-ai.sh` — one-shot host, GPU, Ollama, Docker, Tailscale, and AI service-port status

## Repository layout

```text
latent_forge/
├── README.md
├── docs/
│   ├── experimentation-log.md
│   ├── hermes-agent.md
│   ├── model-registry.md
│   ├── openclaw-agent.md
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

The repository will expand as additional runtimes, models, accelerators, network layouts, storage patterns, and agent frameworks are tested.

## Design principles

1. **Document the physical layer.** Cabling, negotiated link speed, routing, and switch-port choice matter.
2. **Pin the working runtime.** Record the container image, CUDA/PyTorch/vLLM versions, and model identifier.
3. **Make networking explicit.** Multi-homed machines should not be allowed to choose distributed-compute paths accidentally.
4. **Persist expensive artifacts.** Model downloads and compilation caches must survive container restarts.
5. **Measure before optimizing.** A configuration that fits a model is not necessarily a configuration that provides low latency.
6. **Separate capacity from throughput.** Multi-node pipeline parallelism can increase model capacity even when single-stream latency does not improve.
7. **Keep application concerns separate.** Latent Forge contains reusable AI infrastructure; application-specific tools, prompts, datasets, and integrations remain with their applications.
8. **Separate the agent layer from the inference layer.** Agent runtimes such as Hermes and OpenClaw should be evaluated independently from Ollama, llama.cpp, vLLM, or cloud model providers.
9. **Preserve failures, not just recipes.** Permission problems, routing mistakes, template incompatibilities, and broken service configurations are part of the experiment and should remain documented after the final configuration works.

## Status

Early-stage lab repository. The first documented multi-node configuration is operational and benchmarked, generic local-AI operational assets are being consolidated here, and agent runtimes are now being evaluated as a separate infrastructure layer.