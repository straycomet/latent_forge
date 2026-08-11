# Model Registry

| Model | Size | Purpose | Status |
|---|---|---|---|
| Gemma 3 12B | 6.8G | General assistant | Active |
| Qwen2.5 7B | 4.4G | Coding/tools | Active |
| Phi-4 Mini | 2.7G | Lightweight | Active |
| Qwen3.5 397B | 88G | Large-MoE experiment | Experimental |
| Llama 3.2 3B | 12G | HF conversion testing | Archived |

## Lessons Learned

### Large MoE Models

Technically runnable.
Operationally impractical on current hardware.

### 7B–12B Models

Current sweet spot for:

- latency
- memory
- usability
- tool usage

### Small Models

Excellent for:

- scripting
- utilities
- fast inference
- constrained environments
