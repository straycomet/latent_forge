# Latent Forge

**Open-source infrastructure experiments for local and distributed AI.**

Latent Forge documents practical AI infrastructure built and tested on local hardware: model serving, multi-node inference, high-speed networking, storage, containers, accelerators, agent runtimes, monitoring, user interfaces, and performance testing.

The emphasis is reproducibility. Each experiment should record the relevant hardware, runtime, network path, exact commands, validation steps, observed results, and meaningful failures.

## What has been implemented or tested

### Inference runtimes

- **Ollama** — convenient local model management and serving.
- **llama.cpp** — GGUF inference, CUDA/Vulkan experimentation, OpenAI-compatible serving, and local model integration testing.
- **vLLM** — OpenAI-compatible model serving and distributed inference. The current documented configuration runs unquantized `Qwen/Qwen3-32B` across two NVIDIA GB10 nodes with Ray and pipeline parallelism.

These are treated as different tools for different jobs rather than interchangeable wrappers.

### User interface

- **Open WebUI** — implemented as the browser-based access and orchestration layer over local inference backends. See [Open WebUI — Setup, Use, and Lab Notes](docs/openwebui.md).

### Agent runtimes

- **Hermes Agent** — currently preferred; solid in lab testing. See [Hermes Agent — Setup, Use, and Lab Evaluation](docs/hermes-agent.md).
- **OpenClaw** — compelling architecture but buggy in the tested environment; retained as experimental. See [OpenClaw — Setup, Use, and Lab Evaluation](docs/openclaw-agent.md).

### Distributed inference

The first fully documented multi-node experiment uses:

- 2 NVIDIA GB10 systems
- Ray distributed executor
- vLLM
- pipeline parallelism: 2
- tensor parallelism: 1
- dedicated 10 GbE path at approximately 9.4 Gbit/s
- `Qwen/Qwen3-32B` in BF16
- 16,384-token context

Observed benchmark results:

- single request: about 3.6 completion tokens/s
- four concurrent requests: about 14 completion tokens/s aggregate

See [Two-Node NVIDIA GB10 vLLM + Ray Setup and Benchmark](docs/two-node-gb10-vllm-ray-setup.md).

### Enterprise architecture comparison

The lab is intentionally small, but many of the concerns are the same ones that appear in enterprise AI platforms: model serving, distributed scheduling, east-west networking, caching, API boundaries, monitoring, identity, reliability, and workload isolation.

See [Local AI Lab vs Enterprise-Grade Cloud Infrastructure](docs/local-vs-enterprise-cloud-ai-infrastructure.md) for a detailed comparison of the current stack with a typical enterprise cloud inference platform, including where the local environment already uses production-style patterns and where enterprise systems add high availability, autoscaling, IAM, centralized secrets, observability, governance, CI/CD, and infrastructure-as-code.

## Repository structure

```text
latent_forge/
├── README.md
├── docs/
│   ├── experimentation-log.md
│   ├── hermes-agent.md
│   ├── local-vs-enterprise-cloud-ai-infrastructure.md
│   ├── model-registry.md
│   ├── openclaw-agent.md
│   ├── openwebui.md
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

## Runtime roles

A useful way to think about the stack is:

```text
Open WebUI     -> human interface / orchestration
Hermes         -> autonomous agent layer
Ollama         -> convenient local model runtime
llama.cpp      -> flexible GGUF inference and experimentation
vLLM           -> higher-throughput and distributed serving
Ray            -> distributed execution layer for the current vLLM cluster
```

Keeping these responsibilities separate makes the lab easier to troubleshoot and lets one layer change without forcing a redesign of the others.

## Local AI operations and model tracking

Reusable operational assets include:

- [Model registry](docs/model-registry.md) — historical model choices and lessons learned
- [Experimentation log](docs/experimentation-log.md) — infrastructure experiments and observations
- [Ollama inventory snapshot](inventory/ollama-model-inventory-2026-07-16.json) — point-in-time local model inventory
- `scripts/healthcheck.sh` — generic service, disk, and NVIDIA GPU checks
- `scripts/monitor-local-ai.sh` — host, GPU, Ollama, Docker, Tailscale, memory, disk, and AI service-port status

## Security and reliability

Because this repository is public and contains operational infrastructure examples, security and reliability are treated as design requirements rather than cleanup work.

See [Security and Reliability](docs/security-reliability.md) for guidance on:

- secret handling and repository hygiene
- sanitizing logs, screenshots, inventories, and machine-specific details
- service exposure and network binding
- agent trust boundaries
- configuration preflight and restart backoff
- layered health checks
- monitoring methodology
- public-safe examples and reproducibility

The working rule is simple: **make the experiment reproducible without publishing anything that does not need to be public.**

## Design principles

1. **Document the physical layer.** Cabling, negotiated link speed, routing, and switch-port choice matter.
2. **Pin the working runtime.** Record container images, CUDA/PyTorch/runtime versions, and model identifiers.
3. **Make networking explicit.** Multi-homed machines should not be allowed to choose distributed-compute paths accidentally.
4. **Persist expensive artifacts intentionally.** Model downloads and compilation caches should survive disposable containers when appropriate, but should never be committed to Git.
5. **Measure before optimizing.** A configuration that fits a model is not necessarily one that provides good latency or throughput.
6. **Separate capacity from throughput.** Multi-node inference may increase model capacity without improving single-stream latency.
7. **Keep application concerns separate.** Latent Forge contains reusable AI infrastructure; application-specific prompts, datasets, tools, and integrations stay with their applications.
8. **Separate agent, UI, and inference layers.** Open WebUI, Hermes/OpenClaw, Ollama, llama.cpp, and vLLM solve different problems.
9. **Preserve failures, not just recipes.** Routing mistakes, permission issues, template incompatibilities, and broken service configurations are valuable experimental evidence.
10. **Design for a public repository.** Never rely on committed secrets, private data, hard-coded personal paths, or unnecessarily exposed services.
11. **Fail safely.** Validate configuration before starting managed services and use restart backoff.
12. **Monitor without perturbing.** Prefer lightweight observation and distinguish snapshots from time-series evidence.

## Status

Early-stage lab repository. Multi-node vLLM inference is operational and benchmarked, llama.cpp and Ollama have been used for local model serving and experimentation, Open WebUI is implemented as the browser interface, and Hermes/OpenClaw are being evaluated as a separate agent layer.