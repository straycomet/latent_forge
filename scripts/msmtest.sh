MAX_TOKENS="${1:-16}"
echo "max_tokens set to" $MAX_TOKENS
curl -s http://10.10.10.2:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model":"Qwen/Qwen3-32B",
    "messages":[
      {"role":"user","content":"Reply with exactly: OK"}
    ],
    "max_tokens": '$MAX_TOKENS',
    "temperature":0
  }' | python3 -m json.tool
