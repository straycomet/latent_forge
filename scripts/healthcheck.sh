#!/usr/bin/env bash
set -u

LOG_DIR="${LATENT_FORGE_LOG_DIR:-$HOME/.local/state/latent-forge}"
LOG_FILE="$LOG_DIR/healthcheck.log"

mkdir -p "$LOG_DIR"

ts() {
  date +"%Y-%m-%d %H:%M:%S"
}

log() {
  echo "$(ts) | $1" | tee -a "$LOG_FILE"
}

check_service() {
  local svc="$1"

  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    log "OK service active: $svc"
  else
    log "WARN service inactive or unavailable: $svc"
  fi
}

check_http() {
  local name="$1"
  local url="$2"

  if curl -fsS --max-time 10 "$url" >/dev/null; then
    log "OK endpoint reachable: $name"
  else
    log "WARN endpoint unreachable: $name at $url"
  fi
}

check_container() {
  local name="$1"

  if ! command -v docker >/dev/null 2>&1; then
    log "WARN docker not installed; cannot inspect container: $name"
    return
  fi

  if docker inspect "$name" >/dev/null 2>&1; then
    local status restart
    status=$(docker inspect "$name" --format '{{.State.Status}}')
    restart=$(docker inspect "$name" --format '{{.HostConfig.RestartPolicy.Name}}')
    log "OK container found: $name status=$status restart=$restart"
  else
    log "WARN container missing: $name"
  fi
}

check_disk() {
  local usage
  usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

  if [ "$usage" -ge 90 ]; then
    log "WARN disk usage high: ${usage}%"
  else
    log "OK disk usage: ${usage}%"
  fi
}

check_gpu() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    if nvidia-smi >/dev/null 2>&1; then
      local gpu
      gpu=$(nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu --format=csv,noheader | head -1)
      log "OK gpu visible: $gpu"
    else
      log "FAIL nvidia-smi failed"
    fi
  else
    log "WARN nvidia-smi not installed"
  fi
}

log "----- Latent Forge healthcheck start -----"

check_service docker
check_service tailscaled
check_service ssh
check_service ollama

check_container open-webui

check_http "Open WebUI" "${OPEN_WEBUI_URL:-http://localhost:3000}"
check_http "Ollama" "${OLLAMA_TAGS_URL:-http://localhost:11434/api/tags}"

check_disk
check_gpu

log "----- Latent Forge healthcheck end -----"
