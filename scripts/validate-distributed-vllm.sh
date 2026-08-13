#!/usr/bin/env bash
# Validate a two-node Ray/vLLM cluster without changing persistent configuration.
# Designed for the Latent Forge vectrol (head) + vroomfondel (worker) lab.

set -uo pipefail

HEAD_HOST="${HEAD_HOST:-vectrol}"
HEAD_IP="${HEAD_IP:-10.10.10.2}"
WORKER_HOST="${WORKER_HOST:-vroomfondel}"
WORKER_IP="${WORKER_IP:-10.10.10.3}"
REMOTE_SSH="${REMOTE_SSH:-${USER}@${WORKER_IP}}"
RAY_HEAD_CONTAINER="${RAY_HEAD_CONTAINER:-vllm-ray-head}"
RAY_WORKER_CONTAINER="${RAY_WORKER_CONTAINER:-vllm-ray-worker}"
RAY_HEAD_SERVICE="${RAY_HEAD_SERVICE:-ray-head}"
RAY_WORKER_SERVICE="${RAY_WORKER_SERVICE:-ray-worker}"
VLLM_SERVICE="${VLLM_SERVICE:-vllm}"
VLLM_PORT="${VLLM_PORT:-8000}"
IPERF_PORT="${IPERF_PORT:-5202}"
EXPECTED_LINK_MBPS="${EXPECTED_LINK_MBPS:-10000}"
MIN_IPERF_GBPS="${MIN_IPERF_GBPS:-8.0}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=5)

PASS=0
WARN=0
FAIL=0
LOCAL_IFACE=""
REMOTE_IFACE=""

section() { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }
pass()    { printf '\033[1;32mPASS\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
warn()    { printf '\033[1;33mWARN\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
fail()    { printf '\033[1;31mFAIL\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
info()    { printf 'INFO %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

remote() {
  ssh "${SSH_OPTS[@]}" "$REMOTE_SSH" "$@"
}

service_state() {
  systemctl is-active "$1" 2>/dev/null || true
}

container_state() {
  docker inspect -f '{{.State.Status}}' "$1" 2>/dev/null || true
}

iface_for_peer_local() {
  ip route get "$WORKER_IP" 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}'
}

iface_for_peer_remote() {
  remote "ip route get '$HEAD_IP' 2>/dev/null | awk '{for (i=1;i<=NF;i++) if (\$i==\"dev\") {print \$(i+1); exit}}'" 2>/dev/null || true
}

read_speed_local() {
  ethtool "$1" 2>/dev/null | awk -F': ' '/^[[:space:]]*Speed:/ {gsub(/Mb\/s/,"",$2); print $2; exit}'
}

read_speed_remote() {
  remote "ethtool '$1' 2>/dev/null | awk -F': ' '/^[[:space:]]*Speed:/ {gsub(/Mb\\/s/,\"\",\$2); print \$2; exit}'" 2>/dev/null || true
}

check_numeric_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {exit !(a+0 >= b+0)}'
}

section "Identity and routes"
LOCAL_HOST=$(hostname -s 2>/dev/null || hostname)
info "local hostname=$LOCAL_HOST expected=$HEAD_HOST"
if [[ "$LOCAL_HOST" == "$HEAD_HOST" ]]; then pass "head hostname is $HEAD_HOST"; else warn "head hostname is $LOCAL_HOST, expected $HEAD_HOST"; fi

if ip -4 addr show | grep -qw "$HEAD_IP"; then pass "head owns $HEAD_IP"; else fail "head does not own $HEAD_IP"; fi

if ping -I "$HEAD_IP" -c 3 -W 1 "$WORKER_IP" >/dev/null 2>&1; then
  pass "direct-link ping $HEAD_IP -> $WORKER_IP works"
else
  fail "cannot ping $WORKER_IP from source $HEAD_IP"
fi

LOCAL_IFACE=$(iface_for_peer_local)
if [[ -n "$LOCAL_IFACE" ]]; then
  pass "route to $WORKER_IP uses local interface $LOCAL_IFACE"
  ip -br addr show "$LOCAL_IFACE" 2>/dev/null || true
else
  fail "could not determine local interface for $WORKER_IP"
fi

if remote "true" >/dev/null 2>&1; then
  pass "SSH to worker via $REMOTE_SSH works"
else
  fail "SSH to worker via $REMOTE_SSH failed; remote checks will be limited"
fi

REMOTE_HOST_ACTUAL=$(remote "hostname -s" 2>/dev/null || true)
if [[ "$REMOTE_HOST_ACTUAL" == "$WORKER_HOST" ]]; then pass "worker hostname is $WORKER_HOST"; else warn "worker hostname='$REMOTE_HOST_ACTUAL', expected '$WORKER_HOST'"; fi

if remote "ip -4 addr show | grep -qw '$WORKER_IP'" >/dev/null 2>&1; then pass "worker owns $WORKER_IP"; else fail "worker does not own $WORKER_IP"; fi

REMOTE_IFACE=$(iface_for_peer_remote)
if [[ -n "$REMOTE_IFACE" ]]; then
  pass "worker route to $HEAD_IP uses interface $REMOTE_IFACE"
  remote "ip -br addr show '$REMOTE_IFACE'" 2>/dev/null || true
else
  fail "could not determine worker interface for $HEAD_IP"
fi

section "Physical link negotiation"
if have ethtool && [[ -n "$LOCAL_IFACE" ]]; then
  ethtool "$LOCAL_IFACE" 2>/dev/null | grep -E 'Speed:|Duplex:|Link detected:' || true
  LOCAL_SPEED=$(read_speed_local "$LOCAL_IFACE")
  if [[ "$LOCAL_SPEED" =~ ^[0-9]+$ ]]; then
    if (( LOCAL_SPEED >= EXPECTED_LINK_MBPS )); then pass "head negotiated ${LOCAL_SPEED} Mb/s"; else warn "head negotiated ${LOCAL_SPEED} Mb/s, expected >= ${EXPECTED_LINK_MBPS} Mb/s"; fi
  else
    warn "could not read head link speed"
  fi
else
  warn "ethtool unavailable or local interface unknown"
fi

if [[ -n "$REMOTE_IFACE" ]]; then
  remote "ethtool '$REMOTE_IFACE' 2>/dev/null | grep -E 'Speed:|Duplex:|Link detected:'" || true
  REMOTE_SPEED=$(read_speed_remote "$REMOTE_IFACE")
  if [[ "$REMOTE_SPEED" =~ ^[0-9]+$ ]]; then
    if (( REMOTE_SPEED >= EXPECTED_LINK_MBPS )); then pass "worker negotiated ${REMOTE_SPEED} Mb/s"; else warn "worker negotiated ${REMOTE_SPEED} Mb/s, expected >= ${EXPECTED_LINK_MBPS} Mb/s"; fi
  else
    warn "could not read worker link speed"
  fi
fi

section "Interface counters"
if [[ -n "$LOCAL_IFACE" ]]; then
  ip -s link show "$LOCAL_IFACE" || true
fi
if [[ -n "$REMOTE_IFACE" ]]; then
  remote "ip -s link show '$REMOTE_IFACE'" || true
fi

section "10 GbE throughput test"
if have iperf3 && remote "command -v iperf3 >/dev/null" >/dev/null 2>&1; then
  # Start a temporary one-shot server on the worker. It exits after the test.
  remote "nohup iperf3 -s -1 -p '$IPERF_PORT' >/tmp/latent-forge-iperf3.log 2>&1 </dev/null &" >/dev/null 2>&1 || true
  sleep 1
  IPERF_JSON=$(iperf3 -c "$WORKER_IP" -B "$HEAD_IP" -p "$IPERF_PORT" -P 4 -J 2>/dev/null || true)
  if [[ -n "$IPERF_JSON" ]]; then
    BPS=$(printf '%s' "$IPERF_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("end",{}).get("sum_received",{}).get("bits_per_second",0))' 2>/dev/null || echo 0)
    GBPS=$(awk -v b="$BPS" 'BEGIN {printf "%.2f", b/1000000000}')
    info "4-stream forward throughput: ${GBPS} Gb/s"
    if check_numeric_ge "$GBPS" "$MIN_IPERF_GBPS"; then pass "forward throughput is consistent with a healthy 10 GbE path"; else warn "forward throughput ${GBPS} Gb/s is below ${MIN_IPERF_GBPS} Gb/s"; fi
  else
    fail "forward iperf3 test failed"
  fi

  remote "nohup iperf3 -s -1 -p '$IPERF_PORT' >/tmp/latent-forge-iperf3.log 2>&1 </dev/null &" >/dev/null 2>&1 || true
  sleep 1
  IPERF_R_JSON=$(iperf3 -c "$WORKER_IP" -B "$HEAD_IP" -p "$IPERF_PORT" -P 4 -R -J 2>/dev/null || true)
  if [[ -n "$IPERF_R_JSON" ]]; then
    BPS_R=$(printf '%s' "$IPERF_R_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("end",{}).get("sum_received",{}).get("bits_per_second",0))' 2>/dev/null || echo 0)
    GBPS_R=$(awk -v b="$BPS_R" 'BEGIN {printf "%.2f", b/1000000000}')
    info "4-stream reverse throughput: ${GBPS_R} Gb/s"
    if check_numeric_ge "$GBPS_R" "$MIN_IPERF_GBPS"; then pass "reverse throughput is consistent with a healthy 10 GbE path"; else warn "reverse throughput ${GBPS_R} Gb/s is below ${MIN_IPERF_GBPS} Gb/s"; fi
  else
    fail "reverse iperf3 test failed"
  fi
else
  warn "iperf3 is missing locally or remotely; throughput test skipped"
fi

section "GPU and host memory"
if have nvidia-smi; then
  nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null || nvidia-smi 2>/dev/null || true
else
  warn "nvidia-smi not found on head"
fi
free -h || true
remote "nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null || nvidia-smi 2>/dev/null || true; free -h" 2>/dev/null || true

section "Previous-boot crash evidence"
PREV=$(journalctl -k -b -1 --no-pager 2>/dev/null | grep -Ei 'oom|out of memory|killed process|nvrm|xid|cuda|gpu|segfault|panic|watchdog' | tail -80 || true)
if [[ -n "$PREV" ]]; then
  warn "head previous boot contains possible crash indicators"
  printf '%s\n' "$PREV"
else
  pass "no obvious OOM/NVIDIA/Xid/panic indicators found in accessible previous-boot kernel log"
fi

PREV_REMOTE=$(remote "journalctl -k -b -1 --no-pager 2>/dev/null | grep -Ei 'oom|out of memory|killed process|nvrm|xid|cuda|gpu|segfault|panic|watchdog' | tail -80" 2>/dev/null || true)
if [[ -n "$PREV_REMOTE" ]]; then
  warn "worker previous boot contains possible crash indicators"
  printf '%s\n' "$PREV_REMOTE"
else
  info "no obvious worker previous-boot crash indicators found (or remote journal not accessible)"
fi

section "Docker containers"
if have docker; then
  HEAD_CONT=$(container_state "$RAY_HEAD_CONTAINER")
  if [[ "$HEAD_CONT" == "running" ]]; then pass "$RAY_HEAD_CONTAINER is running"; else fail "$RAY_HEAD_CONTAINER state='$HEAD_CONT'"; fi
  docker inspect "$RAY_HEAD_CONTAINER" --format 'restart={{.HostConfig.RestartPolicy.Name}} status={{.State.Status}}' 2>/dev/null || true
else
  fail "docker not available on head"
fi

REMOTE_CONT=$(remote "docker inspect -f '{{.State.Status}}' '$RAY_WORKER_CONTAINER' 2>/dev/null" 2>/dev/null || true)
if [[ "$REMOTE_CONT" == "running" ]]; then pass "$RAY_WORKER_CONTAINER is running"; else fail "$RAY_WORKER_CONTAINER state='$REMOTE_CONT'"; fi
remote "docker inspect '$RAY_WORKER_CONTAINER' --format 'restart={{.HostConfig.RestartPolicy.Name}} status={{.State.Status}}' 2>/dev/null" || true

section "systemd services"
for svc in "$RAY_HEAD_SERVICE" "$VLLM_SERVICE"; do
  STATE=$(service_state "$svc")
  if [[ "$STATE" == "active" ]]; then pass "$svc is active"; else fail "$svc state='$STATE'"; fi
  systemctl --no-pager -l status "$svc" 2>/dev/null | tail -12 || true
done

REMOTE_STATE=$(remote "systemctl is-active '$RAY_WORKER_SERVICE' 2>/dev/null" 2>/dev/null || true)
if [[ "$REMOTE_STATE" == "active" ]]; then pass "$RAY_WORKER_SERVICE is active on worker"; else fail "$RAY_WORKER_SERVICE state='$REMOTE_STATE' on worker"; fi
remote "systemctl --no-pager -l status '$RAY_WORKER_SERVICE' 2>/dev/null | tail -12" || true

section "vLLM service safety settings"
VLLM_CMD=$(systemctl show "$VLLM_SERVICE" -p ExecStart --value 2>/dev/null || true)
if grep -q -- '--gpu-memory-utilization 0.70' <<<"$VLLM_CMD"; then pass "vLLM service has --gpu-memory-utilization 0.70"; else warn "vLLM service does not show --gpu-memory-utilization 0.70"; fi
if grep -q -- '--pipeline-parallel-size 2' <<<"$VLLM_CMD"; then pass "vLLM service requests pipeline parallel size 2"; else warn "vLLM service does not show pipeline parallel size 2"; fi
HEAD_VLLM_ENV=$(systemctl show "$VLLM_SERVICE" -p Environment --value 2>/dev/null || true)
if grep -q "VLLM_HOST_IP=$HEAD_IP" <<<"$HEAD_VLLM_ENV"; then pass "vLLM service pins VLLM_HOST_IP=$HEAD_IP"; else warn "vLLM.service does not pin VLLM_HOST_IP=$HEAD_IP"; fi

HEAD_RAY_CMD=$(systemctl show "$RAY_HEAD_SERVICE" -p ExecStart --value 2>/dev/null || true)
if grep -q -- "--node-ip-address=$HEAD_IP" <<<"$HEAD_RAY_CMD"; then pass "Ray head pins node IP $HEAD_IP"; else warn "Ray head service does not pin node IP $HEAD_IP"; fi

REMOTE_RAY_CMD=$(remote "systemctl show '$RAY_WORKER_SERVICE' -p ExecStart --value 2>/dev/null" 2>/dev/null || true)
if grep -q -- "--node-ip-address=$WORKER_IP" <<<"$REMOTE_RAY_CMD"; then pass "Ray worker pins node IP $WORKER_IP"; else warn "Ray worker service does not pin node IP $WORKER_IP"; fi

section "Ray cluster"
RAY_STATUS=$(docker exec "$RAY_HEAD_CONTAINER" ray status 2>&1 || true)
printf '%s\n' "$RAY_STATUS"
GPU_TOTAL=$(grep -Eo '[0-9.]+/[0-9.]+ GPU' <<<"$RAY_STATUS" | head -1 | cut -d/ -f2 | awk '{print $1}' || true)
if [[ "$GPU_TOTAL" == "2.0" || "$GPU_TOTAL" == "2" ]]; then pass "Ray sees two GPUs"; else fail "Ray does not report two GPUs (reported total='${GPU_TOTAL:-unknown}')"; fi
if grep -q 'node:192\.168\.' <<<"$RAY_STATUS"; then warn "Ray/vLLM placement demand references a 192.168.x.x node; expected direct-link 10.10.10.x addressing"; else pass "no 192.168.x.x placement demand visible in ray status"; fi

section "vLLM API"
if ss -ltn 2>/dev/null | grep -q ":$VLLM_PORT "; then pass "something is listening on TCP $VLLM_PORT"; else warn "nothing is currently listening on TCP $VLLM_PORT"; fi
if curl -fsS --max-time 5 "http://$HEAD_IP:$VLLM_PORT/v1/models" >/tmp/latent-forge-models.json 2>/dev/null; then
  pass "vLLM /v1/models responds"
  python3 -m json.tool /tmp/latent-forge-models.json 2>/dev/null || cat /tmp/latent-forge-models.json
else
  fail "vLLM API is not responding at http://$HEAD_IP:$VLLM_PORT/v1/models"
fi
rm -f /tmp/latent-forge-models.json

section "Recent service errors"
journalctl -u "$RAY_HEAD_SERVICE" -u "$VLLM_SERVICE" --since '-20 min' --no-pager 2>/dev/null | grep -Ei 'error|fail|fatal|oom|killed|broken pipe|channel closed|no available node|waiting for creating' | tail -100 || true
remote "journalctl -u '$RAY_WORKER_SERVICE' --since '-20 min' --no-pager 2>/dev/null | grep -Ei 'error|fail|fatal|oom|killed|broken pipe|channel closed|connection' | tail -100" 2>/dev/null || true

section "Summary"
printf 'PASS=%d WARN=%d FAIL=%d\n' "$PASS" "$WARN" "$FAIL"
printf 'Expected topology: %s(%s) <-> %s(%s), target link >= %s Mb/s, iperf target >= %s Gb/s\n' \
  "$HEAD_HOST" "$HEAD_IP" "$WORKER_HOST" "$WORKER_IP" "$EXPECTED_LINK_MBPS" "$MIN_IPERF_GBPS"
printf '\nThis script is diagnostic only. It does not restart services, alter network settings, or change Ray/vLLM configuration.\n'

if (( FAIL > 0 )); then
  exit 2
elif (( WARN > 0 )); then
  exit 1
else
  exit 0
fi
