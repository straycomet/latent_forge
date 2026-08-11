#!/usr/bin/env bash

echo "=== Time ==="
date

echo
echo "=== Host ==="
hostname
uptime

echo
echo "=== GPU / NVIDIA ==="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi
else
  echo "nvidia-smi not found"
fi

echo
echo "=== Ollama loaded models ==="
if command -v ollama >/dev/null 2>&1; then
  ollama ps
else
  echo "ollama not found"
fi

echo
echo "=== Ollama service ==="
systemctl is-active ollama 2>/dev/null || echo "ollama service status unavailable"

echo
echo "=== Memory ==="
free -h

echo
echo "=== Disk ==="
df -h /

echo
echo "=== Docker containers ==="
if command -v docker >/dev/null 2>&1; then
  docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
else
  echo "docker not found"
fi

echo
echo "=== Docker stats snapshot ==="
if command -v docker >/dev/null 2>&1; then
  docker stats --no-stream
fi

echo
echo "=== Tailscale ==="
if command -v tailscale >/dev/null 2>&1; then
  tailscale status | head -30
else
  echo "tailscale not found"
fi

echo
echo "=== Listening AI service ports ==="
ss -ltn 2>/dev/null | grep -E ':(3000|8000|11434)\b' || echo "No standard Open WebUI, vLLM, or Ollama ports detected"
