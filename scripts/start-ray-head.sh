#!/usr/bin/env bash
set -euo pipefail

HEAD_IP="${HEAD_IP:-10.10.10.2}"
IFACE="${IFACE:-enP7s7}"
RAY_PORT="${RAY_PORT:-6379}"

export VLLM_HOST_IP="$HEAD_IP"
export NCCL_SOCKET_IFNAME="$IFACE"
export GLOO_SOCKET_IFNAME="$IFACE"

ray start --head \
  --node-ip-address="$HEAD_IP" \
  --port="$RAY_PORT" \
  --disable-usage-stats

ray status --address="$HEAD_IP:$RAY_PORT"
