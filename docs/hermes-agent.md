# Hermes Agent — Setup, Use, and Lab Evaluation

Hermes Agent is an open-source autonomous-agent runtime from Nous Research. It is designed to run as a persistent personal agent with tools, memory, skills, messaging gateways, scheduling, browser automation, and support for multiple LLM providers.

This document separates **current upstream behavior** from **our lab experience** so that future breakage is not confused with what was actually observed.

## Status in this lab

**Lab verdict: solid.**

Hermes has been the more dependable of the two general-purpose agent runtimes tested here. The installation and operating model are straightforward, its CLI exposes useful diagnostics, and the platform is less fragile in day-to-day use than OpenClaw was during our test period.

The positive assessment above is an empirical lab conclusion, not a claim that Hermes is bug-free.

## Supported platforms

As of August 2026, upstream treats these as Tier-1 platforms:

- macOS on Apple Silicon
- Linux and WSL2 on x86_64 or aarch64
- Windows 10/11
- Docker on x86_64 or aarch64

This makes Hermes particularly convenient for mixed local-AI labs containing Apple Silicon and ARM64 Linux hosts.

## Installation

### macOS, Linux, WSL2, or Android/Termux

The current upstream installer is:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

After installation, reload the shell:

```bash
source ~/.bashrc
```

or on macOS/zsh:

```bash
source ~/.zshrc
```

Then verify the installation:

```bash
hermes doctor
```

The per-user installer normally places:

```text
~/.hermes/hermes-agent/    application code
~/.local/bin/hermes        CLI launcher
~/.hermes/                 configuration, sessions, memory, skills
```

The installer handles its own Python environment and supporting dependencies. Avoid replacing that managed environment with a random system `pip install`; upstream explicitly treats PyPI/Homebrew installation paths as unsupported.

### Headless install

For a headless machine that does not need browser automation:

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-browser
```

That is useful for compute nodes where Hermes is being used primarily as an orchestration layer rather than as a desktop browser agent.

## Initial configuration

The full wizard is:

```bash
hermes setup
```

Useful focused configuration commands are:

```bash
hermes model
hermes tools
hermes gateway setup
hermes config set
```

`hermes model` chooses the model/provider. This means Hermes itself does not have to own inference: the agent runtime can be separated from whichever local or remote model server is providing inference.

After changing configuration, validate it with:

```bash
hermes doctor
```

and, after upgrades or configuration-schema changes:

```bash
hermes config check
hermes config migrate
```

## Basic use

Start an interactive session with:

```bash
hermes
```

The useful operating pattern is to think of Hermes as the **agent layer**, not the model itself:

```text
User / messaging channel
        |
        v
   Hermes Agent
        |
        +-- memory
        +-- tools
        +-- skills
        +-- terminal/browser
        +-- schedules
        |
        v
   selected LLM provider
```

Hermes supports persistent sessions and memory, reusable skills, tool execution, subagents, and messaging gateways. The gateway can expose the same agent through surfaces such as Telegram, Discord, Slack, WhatsApp, and Signal.

For a local-AI lab, a sensible progression is:

1. Get the CLI working first.
2. Configure the desired model/provider.
3. Enable only the tools actually needed.
4. Run `hermes doctor` until the environment is clean.
5. Add messaging gateways only after local CLI behavior is stable.
6. Add autonomous/scheduled work last.

This isolates failures much better than configuring models, browser automation, messaging, and unattended execution simultaneously.

## Operations

Useful commands:

```bash
hermes                    # interactive agent
hermes model              # select/configure LLM provider
hermes tools              # configure tools
hermes gateway setup      # configure messaging channels
hermes doctor             # diagnose installation/configuration
hermes update             # update using detected install method
```

For system-service deployments, remember that `~/.local/bin` may not be present in the service account's PATH. Verify which launcher is being executed:

```bash
which hermes
hermes doctor
```

## Strengths

### Clean installation model

The official installer creates and manages the runtime rather than assuming the host already has the exact Python/Node ecosystem it expects. That reduces environment drift.

### Good diagnostics

`hermes doctor`, configuration checks, and migration commands give the operator explicit ways to diagnose broken installations and stale config.

### Broad runtime support

Apple Silicon, ARM64 Linux, x86 Linux, Windows, WSL2, and Docker are all first-class enough to make Hermes useful across a heterogeneous lab.

### Strong agent feature set

Hermes combines persistent memory, skills, tools, messaging, scheduling, browser automation, and subagents without tying the user to one IDE or one model provider.

### Separation of agent and inference layers

The agent can remain the control plane while inference comes from another provider or local serving stack. Architecturally, that fits well with a lab where Ollama, vLLM, llama.cpp, and remote APIs may coexist.

### Lab reliability

In our testing, Hermes was substantially less troublesome operationally than OpenClaw. It is currently the preferred general-purpose autonomous-agent runtime in this repository.

## Weaknesses / trade-offs

### Large attack surface

Any autonomous agent with terminal, filesystem, browser, messaging, and persistent credentials has substantial privileges. The convenience comes with a meaningful security boundary.

### More moving parts than a plain model server

Hermes is not a replacement for Ollama or vLLM. It adds orchestration, memory, tools, gateways, and automation, which means more state and more components to understand.

### Browser dependencies can be unnecessary overhead

Headless compute nodes may not need Playwright/Chromium at all. Use `--skip-browser` when those capabilities are not required.

### Agent quality still depends on the underlying model

A solid runtime cannot make a weak local model plan reliably, use tools correctly, or reason through long autonomous jobs. Runtime reliability and model competence are separate dimensions.

## Recommended role in Latent Forge

Use Hermes when the requirement is:

- a persistent autonomous agent rather than simple inference;
- cross-session memory;
- reusable learned skills;
- terminal/browser/tool execution;
- messaging access to the agent;
- scheduled or delegated work;
- an agent layer that can sit above multiple model backends.

For raw high-throughput model serving, keep using the dedicated inference runtimes. Hermes belongs one layer above them.

## Upstream references

- Nous Research Hermes Agent documentation
- NousResearch/hermes-agent GitHub repository
- Hermes Agent installation and platform-support documentation

Commands in this document were checked against upstream documentation in August 2026.