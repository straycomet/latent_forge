# Latent Forge

**Open-source infrastructure experiments for local and distributed AI.**

Latent Forge documents and automates practical AI infrastructure built from local hardware: model serving, multi-node inference, high-speed networking, storage, containers, accelerators, and performance testing.

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

## Repository layout

```text
latent_forge/
├── README.md
├── docs/
│   └── two-node-gb10-vllm-ray-setup.md
└── scripts/
    ├── start-ray-head.sh
    ├── start-ray-worker.sh
    └── benchmark-vllm.sh
```

The repository will expand as additional runtimes, models, accelerators, network layouts, and storage patterns are tested.

## Design principles

1. **Document the physical layer.** Cabling, negotiated link speed, routing, and switch-port choice matter.
2. **Pin the working runtime.** Record the container image, CUDA/PyTorch/vLLM versions, and model identifier.
3. **Make networking explicit.** Multi-homed machines should not be allowed to choose distributed-compute paths accidentally.
4. **Persist expensive artifacts.** Model downloads and compilation caches must survive container restarts.
5. **Measure before optimizing.** A configuration that fits a model is not necessarily a configuration that provides low latency.
6. **Separate capacity from throughput.** Multi-node pipeline parallelism can increase model capacity even when single-stream latency does not improve.

## Status

Early-stage lab repository. The first documented configuration is operational and benchmarked.