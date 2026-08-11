# OpenClaw — Setup, Use, and Lab Evaluation

OpenClaw is an open-source personal AI assistant/agent runtime with a persistent Gateway, messaging integrations, workspace state, tools, skills, and support for multiple model providers.

This document separates **current upstream setup guidance** from **our actual lab experience**. The latter matters because OpenClaw was functionally interesting but operationally much less reliable than Hermes during testing.

## Status in this lab

**Lab verdict: promising, but buggy in our environment.**

OpenClaw successfully connected to a fully local model stack and exposed a usable assistant UI, but the installation generated several operational failures around container permissions, configuration validation, service restarts, and local-model chat-template behavior.

This is a statement about our observed deployment, not a claim that every OpenClaw installation is unstable.

## Test environment

The primary lab setup was:

```text
Host: Ubuntu Linux
Machine: fiberink-MS-7D75
CPU: AMD Ryzen 7 7700X
RAM: 64 GB
GPU: NVIDIA RTX 5070 12 GB
OpenClaw workspace: /home/fiberink/.openclaw
OpenClaw gateway: Docker container, non-root `node` user
Container state path: /home/node/.openclaw
Inference: local llama.cpp OpenAI-compatible endpoint
Initial endpoint: http://127.0.0.1:8080/v1
Later endpoint: http://172.18.0.1:8081/v1 from the container
Model tested: Gemma 3 12B GGUF / Gemma3-12b-it-heretic Q4_K_M
Cloud APIs: intentionally avoided
Sandbox mode: all
Browser/web tools: enabled
```

The architectural goal was a completely local agent:

```text
Browser / OpenClaw UI
        |
        v
 OpenClaw Gateway
   (Docker)
        |
        v
 OpenAI-compatible API
        |
        v
   llama.cpp server
        |
        v
 local Gemma model
```

## Current upstream installation

As of August 2026, the recommended upstream installer for macOS, Linux, and WSL2 is:

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

The installer provisions a supported Node runtime when needed and launches onboarding.

The package-manager path is also supported:

```bash
npm install -g openclaw@latest
openclaw onboard --install-daemon
```

Upstream currently recommends a recent Node release; check the install documentation rather than pinning an old Node version from this document.

After onboarding, verify the Gateway:

```bash
openclaw gateway status
```

For foreground debugging:

```bash
openclaw gateway stop
openclaw gateway --port 18789 --verbose
```

## Docker-based lab setup

Our original test used Docker rather than the newer preferred installer flow.

Useful operational commands were:

```bash
docker compose up -d
```

Ephemeral CLI checks:

```bash
docker compose run --rm cli status
docker compose run --rm cli configure
docker compose run --rm cli devices list
```

Gateway logs:

```bash
docker logs -f <gateway-container>
```

Because the Gateway ran inside Docker as user `node`, the same OpenClaw state appeared at different paths on host and container:

```text
Host:      /home/fiberink/.openclaw
Container: /home/node/.openclaw
```

That distinction became important during troubleshooting.

## Connecting to a local llama.cpp model

The working pattern was to expose llama.cpp's OpenAI-compatible API and point OpenClaw at it as an OpenAI-compatible provider.

From the container, the model server was reached via a host-reachable bridge address rather than the container's own loopback. A tested configuration used:

```text
baseUrl: http://172.18.0.1:8081/v1
API mode: openai-completions
model: gemma-3-12b-it-heretic.Q4_K_M.gguf
```

The important networking lesson is that `127.0.0.1` inside the OpenClaw container refers to the OpenClaw container itself, not the host's llama.cpp process. A host bridge address or host-network mode is therefore required unless both services live in the same container/network namespace.

## Skills

One command used during testing was:

```bash
npx clawhub install coding-agent
```

Inside the running Gateway container, the more appropriate form was:

```bash
docker compose exec openclaw-gateway npx clawhub install coding-agent
```

Skills were then inspected with:

```bash
docker compose exec openclaw-gateway node dist/index.js skills list
```

## Failure modes observed

### 1. Workspace permissions inside the non-root container

Repeated skill installation attempts failed with:

```text
EACCES: permission denied, mkdir '/home/node/.openclaw/workspace/skills'
```

This persisted even after permissive `chmod` attempts on the host-side OpenClaw directory.

The lesson was that host file mode changes alone are not enough when bind mounts, UID/GID ownership, container users, and created subdirectories disagree. Container identity and bind-mount ownership need to be designed explicitly rather than repaired with `chmod 777`.

### 2. Device-token mismatch and state resets

During setup we encountered device-token/state mismatch behavior. One recovery step used was:

```bash
rm -rf /home/fiberink/.openclaw/devices
```

This forced device state to be recreated. It worked as a recovery technique, but destructive state resets are not desirable as a normal operating procedure.

### 3. Container-name conflicts

Repeated Docker setup/debug cycles led to container-name conflicts. This was ordinary Docker lifecycle friction rather than an OpenClaw-specific architectural flaw, but it added to the operational noise.

### 4. `systemctl --user` unavailable inside Docker

Some command paths assumed a user-level systemd environment. That is not normally available inside a basic application container, so commands oriented around desktop/service installation did not map cleanly onto our Docker deployment.

### 5. CLI-vs-Gateway command confusion

OpenClaw exposes commands intended for different execution contexts. During debugging, running a CLI-oriented command against the wrong container/process made troubleshooting harder. Treat the persistent Gateway and ephemeral administration CLI as separate roles.

### 6. Invalid configuration caused a restart loop

A later native/systemd deployment on `fiberink-MS-7D75` used OpenClaw `v2026.4.5` and hit a particularly ugly failure mode.

`~/.openclaw/openclaw.json` contained an invalid value for:

```text
channels.discord.streaming
```

The accepted values were:

```text
off
partial
block
progress
```

Because the configuration was rejected at startup, `openclaw-gateway.service` exited with `status=1/FAILURE`; systemd restarted it continuously. The restart counter reached roughly 16,700 attempts before diagnosis.

A useful command for finding that failure was:

```bash
journalctl -b -1 --no-pager | tail -100
```

The logs recommended:

```bash
openclaw doctor --fix
```

The larger lesson is that configuration validation should happen before service activation. A bad enum value should not be able to create a high-frequency restart loop without a circuit breaker.

### 7. Local Gemma chat-template incompatibility

OpenClaw successfully reached llama.cpp and the UI successfully reached the local model, so connectivity was not the problem.

llama.cpp received:

```text
POST /v1/chat/completions
```

but then returned HTTP 500 from the Gemma Jinja chat template:

```text
Conversation roles must alternate user/assistant/user/assistant/...
```

At the time, OpenClaw was configured for the local provider using:

```text
baseUrl: http://172.18.0.1:8081/v1
api: openai-completions
model: gemma-3-12b-it-heretic.Q4_K_M.gguf
```

This is an important distinction: the failure was not an inability to reach the inference server. It was an incompatibility between the message history OpenClaw emitted and the strict role sequence expected by that llama.cpp/Gemma chat template.

Potential fixes live at the integration boundary: use a compatible chat template, normalize the role history, or choose a model/template combination tolerant of OpenClaw's message structure.

## What worked well

### Fully local architecture

OpenClaw could operate against a local OpenAI-compatible llama.cpp endpoint. That means the agent stack does not inherently require cloud inference.

### Rich personal-assistant concept

The Gateway, workspace, skills, messaging channels, browser capabilities, and persistent state form a strong personal-agent architecture.

### Broad channel ecosystem

Current OpenClaw releases support a very large number of messaging channels and companion surfaces. For an always-on personal agent, this is one of its biggest attractions.

### Good separation of workspace from application source

Current upstream guidance keeps config and workspace under `~/.openclaw`, which is the correct conceptual boundary for persistent personal state.

## Weaknesses observed

### Operational fragility

The lab hit enough independent failures that OpenClaw never felt boring to operate. For infrastructure software, "boring" is a compliment.

### Configuration can fail hard

An invalid config value caused the Gateway to fail continuously under systemd. Better preflight validation and restart backoff would reduce blast radius.

### Container permission ergonomics

Running as a non-root user is correct from a security perspective, but the bind-mounted workspace/skills experience was rough in our test deployment.

### Local-model integration is not automatically model-agnostic

An OpenAI-compatible endpoint does not guarantee behavioral compatibility. Chat templates, system messages, tool-role messages, and history shaping can still break a local model.

### Many moving parts

Gateway, workspace, devices, skills, channels, model provider, browser tooling, service manager, and optional containers create a wide debugging surface.

## OpenClaw versus Hermes — lab conclusion

| Area | Hermes | OpenClaw |
|---|---|---|
| Basic installation | Smooth in our testing | More friction |
| Diagnostics | Strong | Useful, but we still hit hard failures |
| Local model support | Flexible | Flexible, but template integration bit us |
| Persistent agent features | Strong | Strong |
| Messaging ecosystem | Broad | Extremely broad |
| Container ergonomics | Reasonable | Permission/state issues observed |
| Operational stability in this lab | **Solid** | **Buggy** |
| Current preference | **Preferred** | Experimental |

This table records our own test experience rather than a universal ranking.

## Recommended role in Latent Forge

Keep OpenClaw documented and periodically retest it because the architecture is compelling and the project moves quickly. For now:

- use Hermes for the dependable general-purpose agent layer;
- treat OpenClaw as an experimental runtime;
- test OpenClaw first with its CLI/Gateway and one provider before adding channels, skills, browser tooling, and unattended services;
- validate config before installing/enabling the daemon;
- for local models, test `/v1/chat/completions` directly with the exact message structure before blaming networking;
- when containerized, explicitly align host-directory ownership with the container UID/GID.

## Upstream references

- OpenClaw installation documentation
- OpenClaw getting-started documentation
- openclaw/openclaw GitHub repository

Current upstream installation commands were checked in August 2026. Historical lab commands and failures above are preserved because they describe what actually happened during our deployment, even where current OpenClaw releases may have improved the behavior.