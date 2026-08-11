#!/usr/bin/env bash
set -euo pipefail

HEAD_IP="${HEAD_IP:-10.10.10.2}"
WORKER_IP="${WORKER_IP:-10.10.10.3}"
IFACE="${IFACE:-enP7s7}"
RAY_PORT="${RAY_PORT:-6379}"

export VLLM_HOST_IP="$WORKER_IP"
export NCCL_SOCKET_IFNAME="$IFACE"
export GLOO_SOCKET_IFNAME="$IFACE"

ray start \
  --address="$HEAD_IP:$RAY_PORT" \
  --node-ip-address="$WORKER_IP"

ray status --address="$HEAD_IP:$RAY_PORT"
