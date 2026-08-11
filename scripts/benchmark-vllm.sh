#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="${ENDPOINT:-http://10.10.10.2:8000/v1/chat/completions}"
MODEL="${MODEL:-Qwen/Qwen3-32B}"
CONCURRENCY="${CONCURRENCY:-4}"
MAX_TOKENS="${MAX_TOKENS:-100}"
PROMPT="${PROMPT:-/no_think Explain pipeline parallelism in exactly three sentences.}"
OUT_DIR="${OUT_DIR:-/tmp/latent-forge-vllm-bench}"

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR"/qwen-*.json "$OUT_DIR"/qwen-*.time

start_ns=$(date +%s%N)

for i in $(seq 1 "$CONCURRENCY"); do
  (
    /usr/bin/time -f '%e' -o "$OUT_DIR/qwen-$i.time" \
      curl -s "$ENDPOINT" \
        -H 'Content-Type: application/json' \
        -d "$(jq -n \
          --arg model "$MODEL" \
          --arg prompt "$PROMPT" \
          --argjson max_tokens "$MAX_TOKENS" \
          '{model:$model,messages:[{role:"user",content:$prompt}],max_tokens:$max_tokens,temperature:0}')" \
        > "$OUT_DIR/qwen-$i.json"
  ) &
done

wait
end_ns=$(date +%s%N)

wall_seconds=$(awk -v s="$start_ns" -v e="$end_ns" 'BEGIN { printf "%.3f", (e-s)/1000000000 }')
total_completion_tokens=0

printf 'Requests: %s\n' "$CONCURRENCY"
printf 'Wall time: %s s\n' "$wall_seconds"

for i in $(seq 1 "$CONCURRENCY"); do
  tokens=$(jq -r '.usage.completion_tokens // 0' "$OUT_DIR/qwen-$i.json")
  elapsed=$(cat "$OUT_DIR/qwen-$i.time")
  total_completion_tokens=$((total_completion_tokens + tokens))
  printf 'Request %s: %s completion tokens, %s s\n' "$i" "$tokens" "$elapsed"
done

aggregate_tps=$(awk -v t="$total_completion_tokens" -v s="$wall_seconds" 'BEGIN { if (s > 0) printf "%.2f", t/s; else print "0" }')

printf 'Total completion tokens: %s\n' "$total_completion_tokens"
printf 'Aggregate completion throughput: %s tok/s\n' "$aggregate_tps"
