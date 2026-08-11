# Two-Node NVIDIA GB10 vLLM + Ray Setup and Benchmark

> Status: working configuration validated on 2026-08-11.
>
> This document captures the configuration that worked. It intentionally avoids repeating intermediate attempts. A short failure summary appears at the end.

## 1. Goal

Run one unquantized large language model across two NVIDIA GB10 systems using vLLM and Ray, with model execution split across the two GPUs over a dedicated 10 GbE network.

Validation model:

- `Qwen/Qwen3-32B`
- BF16 / unquantized
- OpenAI-compatible vLLM API
- Ray distributed executor
- pipeline parallelism across two physical nodes

The final setup successfully served chat completions from either machine.

## 2. Hardware and Node Roles

| Role | Hostname | Dedicated 10 GbE IP | GPU | CPU resources exposed to Ray |
|---|---|---:|---|---:|
| Head | `gx10-0b5a` | `10.10.10.2/24` | NVIDIA GB10 | 20 CPUs |
| Worker | `vroomfondel` | `10.10.10.3/24` | NVIDIA GB10 | 20 CPUs |

Both systems reported:

- NVIDIA driver: `580.173.02`
- CUDA reported by `nvidia-smi`: `13.0`
- NVIDIA GB10 GPU
- 128 GB class unified-memory system

The NVIDIA vLLM container reported:

- PyTorch: `2.11.0a0+eb65b36914.nv26.02`
- CUDA runtime used by PyTorch: `13.1`
- vLLM: `0.15.1+befbc472`
- GPU: `NVIDIA GB10`

## 3. Network Topology and Cabling

The two machines use `enP7s7` for the dedicated high-speed inference network.

```text
gx10-0b5a   enP7s7   10.10.10.2/24
vroomfondel enP7s7   10.10.10.3/24
```

Both hosts also have normal LAN addresses on `192.168.1.x`. The `10.10.10.x` addresses are explicitly used for Ray and distributed model traffic so the cluster does not select the slower/general-purpose LAN path.

### Physical connection

Each GB10 system is connected by Ethernet patch cabling to a 10 GbE-capable switch port. The exact cable category/model was not recorded during this session, so it is intentionally not invented here. The validated fact is that both links negotiated at 10,000 Mb/s full duplex.

One early performance problem was caused by one machine being plugged into a 2.5 GbE switch port. Moving it to a 10 GbE port corrected the throughput.

### Verify link speed

Run on each host:

```bash
sudo ethtool enP7s7 | grep -E 'Speed|Duplex|Link detected'
```

Expected:

```text
Speed: 10000Mb/s
Duplex: Full
Link detected: yes
```

### Verify routing

From `gx10-0b5a`:

```bash
ip route get 10.10.10.3
```

From `vroomfondel`:

```bash
ip route get 10.10.10.2
```

The route should use `enP7s7`.

### Verify network performance

Install `iperf3` if needed:

```bash
sudo apt update
sudo apt install -y iperf3
```

On one node:

```bash
iperf3 -s
```

On the other:

```bash
iperf3 -c 10.10.10.2
```

Reverse direction:

```bash
iperf3 -c 10.10.10.2 -R
```

Validated throughput after correcting the switch port:

- forward: approximately `9.41 Gbit/s`
- reverse: approximately `9.42 Gbit/s`
- sub-millisecond ping latency

## 4. Docker Preparation

Docker was already installed on both hosts.

Allow the normal user to run Docker without `sudo`:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Verify:

```bash
docker ps
```

## 5. vLLM Installation Choice

vLLM was run from NVIDIA's NGC container instead of being installed directly into the host Python environment.

Image:

```text
nvcr.io/nvidia/vllm:26.02-py3
```

Pull it on both nodes:

```bash
docker pull nvcr.io/nvidia/vllm:26.02-py3
```

### Verify vLLM, PyTorch, CUDA, and GB10

Run on both machines:

```bash
docker run --rm --gpus all \
  --entrypoint /usr/bin/python3 \
  nvcr.io/nvidia/vllm:26.02-py3 \
  -c 'import torch, vllm; print("torch:", torch.__version__); print("cuda:", torch.version.cuda); print("vllm:", vllm.__version__); print("device:", torch.cuda.get_device_name(0))'
```

Validated output:

```text
torch: 2.11.0a0+eb65b36914.nv26.02
cuda: 13.1
vllm: 0.15.1+befbc472
device: NVIDIA GB10
```

## 6. Persistent Model and Compile Caches

Create cache directories on both hosts:

```bash
mkdir -p ~/.cache/huggingface ~/.cache/vllm
```

Mount them into the containers:

```text
$HOME/.cache/huggingface -> /root/.cache/huggingface
$HOME/.cache/vllm        -> /root/.cache/vllm
```

This is important. Containers are created with `--rm`; without host mounts, downloaded model weights and vLLM compilation artifacts disappear when a container exits.

## 7. Start the Head Container

Run on `gx10-0b5a`:

```bash
docker run --rm -it \
  --gpus all \
  --network host \
  --ipc host \
  --shm-size=16g \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  -v "$HOME/.cache/vllm:/root/.cache/vllm" \
  --name vllm-ray-head \
  nvcr.io/nvidia/vllm:26.02-py3 \
  bash
```

## 8. Start the Worker Container

Run on `vroomfondel`:

```bash
docker run --rm -it \
  --gpus all \
  --network host \
  --ipc host \
  --shm-size=16g \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  -v "$HOME/.cache/vllm:/root/.cache/vllm" \
  --name vllm-ray-worker \
  nvcr.io/nvidia/vllm:26.02-py3 \
  bash
```

Open another shell into a running container when needed:

```bash
docker exec -it vllm-ray-head bash
```

or:

```bash
docker exec -it vllm-ray-worker bash
```

## 9. Start the Ray Head

Inside `vllm-ray-head` on `gx10-0b5a`:

```bash
export VLLM_HOST_IP=10.10.10.2
export NCCL_SOCKET_IFNAME=enP7s7
export GLOO_SOCKET_IFNAME=enP7s7

ray start --head \
  --node-ip-address=10.10.10.2 \
  --port=6379 \
  --disable-usage-stats
```

Expected key output:

```text
Local node IP: 10.10.10.2
Ray runtime started.
```

## 10. Join the Ray Worker

Inside `vllm-ray-worker` on `vroomfondel`:

```bash
export VLLM_HOST_IP=10.10.10.3
export NCCL_SOCKET_IFNAME=enP7s7
export GLOO_SOCKET_IFNAME=enP7s7

ray start \
  --address=10.10.10.2:6379 \
  --node-ip-address=10.10.10.3
```

## 11. Verify the Ray Cluster

```bash
ray status --address=10.10.10.2:6379
```

Validated state:

```text
Active:
2 nodes

Resources:
0.0/40.0 CPU
0.0/2.0 GPU
```

Explicitly verify node IPs and resources from the head:

```bash
python3 - <<'PY'
import ray
ray.init(address="auto")
for n in ray.nodes():
    if n["Alive"]:
        print(n["NodeManagerAddress"], n["Resources"])
PY
```

Validated result included:

```text
10.10.10.2 ... GPU: 1.0 ... CPU: 20.0 ...
10.10.10.3 ... GPU: 1.0 ... CPU: 20.0 ...
```

This check matters because both hosts are multi-homed. Do not proceed if Ray identifies them by the `192.168.1.x` LAN addresses.

## 12. Start Qwen3-32B with vLLM

Run from the head container:

```bash
vllm serve Qwen/Qwen3-32B \
  --distributed-executor-backend ray \
  --tensor-parallel-size 1 \
  --pipeline-parallel-size 2 \
  --host 0.0.0.0 \
  --port 8000 \
  --gpu-memory-utilization 0.70 \
  --max-model-len 16384
```

### Parallelism choice

Each node has one GB10 GPU, so the working layout is:

```text
Tensor parallel size:   1
Pipeline parallel size: 2
```

The workers reported:

```text
rank 0 ... PP rank 0 ... TP rank 0
rank 1 ... PP rank 1 ... TP rank 0
```

### Context choice

At the model's default 40,960-token context and `--gpu-memory-utilization 0.70`, vLLM could not allocate enough KV-cache memory. The working configuration uses:

```text
--max-model-len 16384
```

### Successful load timing

With the model available locally:

```text
Loading weights took 139.16 seconds
```

Engine profile, KV-cache creation, and warmup:

```text
init engine (profile, create kv cache, warmup model) took 44.80 seconds
```

Successful API startup:

```text
Started server process
Waiting for application startup.
Application startup complete.
```

## 13. Verify the API Listener

From the head host:

```bash
ss -ltn | grep :8000
```

Validated:

```text
LISTEN 0 2048 0.0.0.0:8000 0.0.0.0:*
```

## 14. Verify the Model Endpoint

From `vroomfondel`:

```bash
curl http://10.10.10.2:8000/v1/models
```

The response identified:

```text
Qwen/Qwen3-32B
max_model_len: 16384
owned_by: vllm
```

This verifies that the service is reachable across the dedicated network, not just on localhost.

## 15. Basic Chat Completion Test

```bash
curl http://10.10.10.2:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B",
    "messages": [
      {"role": "user", "content": "Explain pipeline parallelism across two GPU nodes in three sentences."}
    ],
    "max_tokens": 500
  }'
```

This completed successfully. Qwen3's default thinking behavior generated a long `<think>` section first.

Observed usage:

```text
prompt_tokens:     21
completion_tokens: 483
total_tokens:      504
```

## 16. Non-Thinking Interactive Test

```bash
time curl -s http://10.10.10.2:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B",
    "messages": [
      {"role": "user", "content": "/no_think Explain pipeline parallelism across two GPU nodes in exactly three sentences."}
    ],
    "max_tokens": 150,
    "temperature": 0
  }' > /tmp/qwen-test.json

cat /tmp/qwen-test.json
```

Measured wall time:

```text
real 0m21.673s
```

Usage:

```text
prompt_tokens:     24
completion_tokens: 78
total_tokens:      102
```

Approximate single-request decode throughput:

```text
~3.6 completion tokens/second
```

The `/no_think` instruction reduced perceived latency by avoiding hundreds of reasoning tokens. It did not materially change the underlying per-stream decode rate.

## 17. Four-Request Concurrency Test

```bash
for i in {1..4}; do
  (
    time curl -s http://10.10.10.2:8000/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d '{
        "model": "Qwen/Qwen3-32B",
        "messages": [
          {"role": "user", "content": "/no_think Explain pipeline parallelism in exactly three sentences."}
        ],
        "max_tokens": 100,
        "temperature": 0
      }' > /tmp/qwen-$i.json
  ) &
done
wait
```

Measured completion times:

```text
22.768 s
22.767 s
23.338 s
23.338 s
```

Token counts:

```text
Request 1: 81 completion tokens
Request 2: 82 completion tokens
Request 3: 82 completion tokens
Request 4: 81 completion tokens
```

Total completion tokens: `326`.

Approximate wall-clock interval: `23.34 seconds`.

Aggregate decode throughput:

```text
~14.0 completion tokens/second
```

The key result is that four concurrent requests finished in approximately the same wall-clock time as one request:

```text
Single request:  ~21.7 s for 78 output tokens
Four concurrent: ~23.3 s for 326 output tokens total
```

This demonstrates effective continuous batching. Single-stream latency remained modest, while aggregate serving throughput scaled substantially with concurrent requests.

## 18. GPU Utilization Observed During Testing

One unsynchronized pair of `nvidia-smi` samples showed:

`vroomfondel`:

```text
GPU-Util: 96%
RayWorkerWrapper GPU memory: ~84,042 MiB
```

`gx10-0b5a` at a different instant:

```text
GPU-Util: 1%
RayWorkerWrapper GPU memory: ~82,421 MiB
```

These were instantaneous samples taken at different times, so they should not be interpreted as proof that one pipeline stage was idle. Both Ray workers held substantial GPU/unified memory and both nodes participated in the pipeline.

Future performance work should capture synchronized GPU utilization and network-interface counters during the same inference interval.

## 19. Repeatable Startup Sequence

### Head: `gx10-0b5a`

Start the head container, then inside it:

```bash
export VLLM_HOST_IP=10.10.10.2
export NCCL_SOCKET_IFNAME=enP7s7
export GLOO_SOCKET_IFNAME=enP7s7

ray start --head \
  --node-ip-address=10.10.10.2 \
  --port=6379 \
  --disable-usage-stats
```

### Worker: `vroomfondel`

Start the worker container, then inside it:

```bash
export VLLM_HOST_IP=10.10.10.3
export NCCL_SOCKET_IFNAME=enP7s7
export GLOO_SOCKET_IFNAME=enP7s7

ray start \
  --address=10.10.10.2:6379 \
  --node-ip-address=10.10.10.3
```

### Back on the head

Verify:

```bash
ray status --address=10.10.10.2:6379
```

Then serve:

```bash
vllm serve Qwen/Qwen3-32B \
  --distributed-executor-backend ray \
  --tensor-parallel-size 1 \
  --pipeline-parallel-size 2 \
  --host 0.0.0.0 \
  --port 8000 \
  --gpu-memory-utilization 0.70 \
  --max-model-len 16384
```

Verify:

```bash
curl http://10.10.10.2:8000/v1/models
```

## 20. What This Test Demonstrated

The validated architecture ran an unquantized dense 32B model across two NVIDIA GB10 nodes using Docker, NVIDIA's vLLM NGC image, Ray, NCCL, vLLM pipeline parallelism, and dedicated 10 GbE Ethernet.

Observed behavior:

- dense Qwen3-32B BF16 successfully split across two GB10 GPUs
- approximately `3.5-3.6 tok/s` for a single output stream
- approximately `14 tok/s` aggregate across four concurrent requests
- four requests completed with only a small wall-clock increase versus one request

The primary benefit of the second node in this configuration is model capacity and concurrent serving throughput, not lower single-stream latency.

## 21. Short Summary of Failed Attempts

### Wrong switch port limited the network

One host was initially connected to a 2.5 GbE switch port, yielding about 2.35 Gbit/s. Moving it to a 10 GbE port produced about 9.4 Gbit/s in both directions.

### Ray selected the wrong network identity

Because both machines have `10.10.10.x` and `192.168.1.x` addresses, an early placement group referred to `192.168.1.23` while the intended Ray cluster used the dedicated 10 GbE network.

The fix was explicit configuration of:

```text
VLLM_HOST_IP
--node-ip-address
NCCL_SOCKET_IFNAME=enP7s7
GLOO_SOCKET_IFNAME=enP7s7
```

with `10.10.10.2` on the head and `10.10.10.3` on the worker.

### Full context exceeded the configured KV cache

At `--gpu-memory-utilization 0.70` with the model's 40,960-token context, vLLM reported that 10.0 GiB of KV cache was required but only 8.09 GiB was available on one stage.

The working configuration reduced context to:

```text
--max-model-len 16384
```

### Ephemeral model cache was lost

The first containers used `--rm` without host-mounted Hugging Face/vLLM cache directories. When those containers exited, downloaded weights and compile artifacts disappeared.

The fix was:

```text
-v "$HOME/.cache/huggingface:/root/.cache/huggingface"
-v "$HOME/.cache/vllm:/root/.cache/vllm"
```

### One Ray worker disappeared during model loading

One attempt failed during safetensor loading with:

```text
ray.exceptions.ActorUnavailableError
RpcError: Socket closed
```

The checked host logs did not show a kernel OOM kill, NVIDIA XID, GPU reset, or segfault. After recreating the containers, restarting Ray cleanly with explicit 10 GbE addresses, and relaunching vLLM, model loading and serving succeeded.

### Generic vLLM image was not retained

The generic `vllm/vllm-openai:latest` image was explored, but its runtime/entrypoint behavior did not match the desired ARM64/GB10 workflow. The working image is:

```text
nvcr.io/nvidia/vllm:26.02-py3
```
