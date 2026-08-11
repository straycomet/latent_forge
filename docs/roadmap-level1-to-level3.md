# Roadmap: Level 1 → Level 3

> Goal: evolve Latent Forge from a repeatable local AI lab into a production-style private AI platform without prematurely recreating hyperscaler complexity.

This roadmap uses the maturity model from [Local AI Lab vs Enterprise-Grade Cloud Infrastructure](local-vs-enterprise-cloud-ai-infrastructure.md):

- **Level 1 — Repeatable lab**
- **Level 2 — Managed local platform**
- **Level 3 — Production-style local/private platform**

The objective is not to make a home/local environment look artificially "enterprise." The objective is to add the engineering controls that materially improve reproducibility, safety, observability, recovery, and service quality.

## Current position

Latent Forge is already at **Level 1** and has several Level 2 building blocks.

Validated or implemented capabilities include:

- Ollama, llama.cpp, and vLLM model serving;
- distributed vLLM inference using Ray across two NVIDIA GB10 nodes;
- dedicated 10 GbE model traffic;
- Docker-based runtime isolation;
- persistent model caches;
- OpenAI-compatible endpoints;
- Open WebUI as a separate human-interface layer;
- Hermes and OpenClaw as separate agent-layer experiments;
- reusable service health checks;
- host/GPU/service monitoring scripts;
- documented benchmarks and postmortems;
- security and reliability guidance for a public repository.

The path to Level 3 should therefore focus less on adding inference runtimes and more on **operationalizing what already works**.

# Phase 1 — Complete Level 1

## Objective

Make every validated experiment reproducible from the repository without relying on conversational history or undocumented host state.

## 1. Standardize repository structure

Target:

```text
latent_forge/
├── docs/
├── inventory/
├── monitoring/
├── scripts/
├── services/
├── config/examples/
├── tests/
└── .github/workflows/
```

Tasks:

- separate monitoring utilities from deployment scripts;
- separate reusable service definitions from experiment-specific commands;
- add sanitized configuration examples;
- ensure every operational script has a short README or usage header;
- label documents as validated, experimental, historical, or postmortem.

### Exit criteria

A new user can understand where deployment, monitoring, configuration, and experiment records live without inspecting the whole repository.

## 2. Generalize current scripts

Convert machine-specific values into arguments or environment variables.

Examples:

```bash
HEAD_IP="${HEAD_IP:-10.10.10.2}"
WORKER_IP="${WORKER_IP:-10.10.10.3}"
IFACE="${IFACE:-enP7s7}"
MODEL="${MODEL:-Qwen/Qwen3-32B}"
```

Tasks:

- remove personal home-directory assumptions;
- discover GPUs/interfaces where feasible;
- add `--help` or documented environment variables;
- use `set -euo pipefail` where appropriate;
- return meaningful non-zero exit codes on failure;
- avoid broad `pkill` behavior.

### Exit criteria

Scripts can be reused on another Linux host with configuration changes rather than code edits.

## 3. Consolidate monitoring

Create the first formal monitoring layer.

Initial scope:

- CPU utilization and temperature;
- RAM and swap;
- disk usage and I/O;
- NVIDIA GPU utilization, memory, temperature, and power;
- AMD GPU metrics where available;
- network link speed and counters;
- Docker container state;
- Ollama, llama.cpp, vLLM, Ray, and Open WebUI health;
- systemd service health.

Add the existing Python temperature/load monitor after sanitizing and generalizing it.

Recommended structure:

```text
monitoring/
├── README.md
├── host_monitor.py
├── gpu_monitor.py
├── service_health.sh
└── systemd/
```

### Exit criteria

A single documented command or lightweight UI gives an operator a reliable current-state view of each AI host.

## 4. Add basic repository CI

CI should initially avoid requiring GPUs.

Checks:

- `shellcheck` for shell scripts;
- Python lint/import tests;
- unit tests for monitoring/config utilities;
- Markdown link checks;
- YAML/JSON validation;
- secret scanning;
- Docker Compose syntax validation where applicable.

### Exit criteria

A bad shell script, malformed config, or accidentally committed secret is caught before merge.

# Phase 2 — Level 2: Managed Local Platform

## Objective

Move from "commands that work" to **services that operate predictably**.

## 5. Convert validated runtimes into managed services

Do not automate every experiment. Only operationalize configurations that have already been validated manually.

Candidates:

- Ollama;
- Open WebUI;
- llama.cpp server profiles;
- vLLM/Ray head and worker services;
- monitoring agents.

Use either systemd or Docker Compose deliberately based on the service.

Every managed service should define:

- configuration preflight;
- startup dependencies;
- explicit environment/config file;
- health check;
- restart backoff;
- clean shutdown;
- persistent-state locations;
- log location/retention.

### Exit criteria

After a host reboot, approved services return to a healthy state without manually replaying setup commands.

## 6. Introduce configuration as code

Create sanitized host-role configuration rather than embedding topology in scripts.

Example:

```yaml
nodes:
  inference-head:
    role: ray-head
    interface: enP7s7
    inference_ip: 10.10.10.2

  inference-worker-1:
    role: ray-worker
    interface: enP7s7
    inference_ip: 10.10.10.3
```

Do not publish sensitive host details that do not improve reproducibility.

Then consider Ansible for host configuration once the manual configuration is stable.

Good Ansible candidates:

- packages;
- directories;
- Docker configuration;
- service unit installation;
- firewall rules;
- monitoring agents;
- config deployment.

Avoid automating BIOS, risky driver replacement, or destructive storage operations early.

### Exit criteria

A clean/rebuilt host can be brought close to its intended role from source-controlled configuration plus private secrets.

## 7. Add structured metrics

Move beyond one-shot monitoring into time-series observability.

Suggested architecture:

```text
host exporters
GPU metrics
service metrics
      |
      v
Prometheus-compatible collector
      |
      v
Grafana
```

Start small.

Metrics should include:

- CPU/memory/disk;
- GPU utilization/memory/temperature;
- interface throughput/errors;
- vLLM request rate;
- prompt/generation token throughput;
- queue depth where exposed;
- request latency;
- Ray node health;
- service uptime/restarts.

### Exit criteria

The operator can answer "what happened over the last hour?" rather than only "what is happening right now?"

## 8. Add alerting

Alert only on actionable conditions initially.

Examples:

- model endpoint unavailable;
- expected Ray node missing;
- GPU or CPU sustained thermal issue;
- disk nearly full;
- repeated service restart;
- inference error rate above threshold;
- high network errors on the dedicated model interface.

Avoid alerting on every utilization spike.

### Exit criteria

Failures can be discovered without continuously watching dashboards.

## 9. Formalize backups and recovery

Identify state by category:

### Reconstructable

- Docker images;
- downloaded model weights;
- build caches.

### Important but replaceable

- model registries/inventories;
- generated config;
- benchmark outputs.

### Persistent application state

- Open WebUI database;
- agent memory/workspaces where intentionally retained;
- local operational configuration.

Define backup/restore procedures for the third category.

Test restores, not just backups.

### Exit criteria

A failed disk or corrupted container volume does not require reconstructing important state from memory.

# Phase 3 — Level 2.5: Reliability and Security Hardening

## Objective

Build the controls required before calling the system production-style.

## 10. Centralize secret handling

Move long-lived secrets out of shell history, source files, and unmanaged `.env` sprawl.

Possible local/private approaches:

- systemd credentials;
- SOPS-encrypted configuration;
- Vault or another secret manager if the operational cost is justified;
- short-lived credentials where supported.

Rules:

- no credentials in Git;
- no secrets in Docker images;
- no long-lived agent secrets embedded in prompts;
- rotate leaked credentials immediately.

### Exit criteria

Source-controlled deployment config contains references to secrets, not the secrets themselves.

## 11. Network segmentation and firewall policy

Define service exposure explicitly.

Suggested logical networks:

```text
management / normal LAN
inference east-west network
storage traffic
remote-access overlay
```

Not every physical network needs to be separate, but firewall policy should reflect those roles.

Protect particularly sensitive services:

- Ray control ports;
- vLLM/llama.cpp APIs;
- Ollama;
- Open WebUI administration;
- agent gateways;
- monitoring dashboards.

### Exit criteria

A service is reachable because policy permits it, not simply because it binds to `0.0.0.0`.

## 12. Define SLOs

Choose a small set of service-level objectives.

Example local targets:

```text
Open WebUI availability:        99% during defined operating hours
Inference API availability:     99%
Ray cluster expected nodes:     2/2 when distributed profile is active
P95 interactive request latency: workload-specific
Disk free space:                >15%
```

These do not need enterprise contractual rigor. Their purpose is to make reliability measurable.

### Exit criteria

"Reliable" has explicit operational meaning.

## 13. Add failure testing

Test controlled failures:

- stop a model server;
- stop a Ray worker;
- reboot a host;
- fill a test filesystem near threshold;
- break a config value;
- disconnect the dedicated inference interface;
- restart Open WebUI while preserving its volume.

Record:

```text
failure
expected behavior
actual behavior
detection time
recovery path
data loss
```

### Exit criteria

Recovery procedures are validated rather than assumed.

# Phase 4 — Level 3: Production-Style Private Platform

## Objective

Add controlled deployment, redundancy, auditability, and end-to-end operational visibility.

## 14. Add serving profiles

Create explicit deployment profiles for different goals.

### Capacity profile

Use multiple nodes to host one larger model.

```text
node A + node B
      -> one distributed model instance
```

Best for model capacity.

### Availability profile

Run independent model replicas.

```text
model replica A
model replica B
       |
       v
load balancer
```

Best for failure tolerance.

### Throughput profile

Run several replicas and route/batch requests across them.

Best for concurrent workloads.

The repository should document these as different architectural choices rather than treating "more GPUs" as one generic scaling mode.

### Exit criteria

Deployment topology is selected by workload goal: capacity, availability, or throughput.

## 15. Add a private ingress layer

Place a controlled endpoint in front of model services.

Capabilities should include some subset of:

- TLS;
- authentication;
- rate limiting;
- request-size limits;
- model routing;
- basic audit logs;
- health-based backend selection.

Potential technologies could include a lightweight reverse proxy or an API gateway. Choose the smallest tool that satisfies the requirement.

### Exit criteria

Clients no longer need direct access to individual model-server ports.

## 16. End-to-end observability

Add request correlation across layers:

```text
client
  -> ingress
  -> Open WebUI / agent
  -> model endpoint
  -> distributed worker
```

At minimum capture:

- request ID;
- model;
- start/end latency;
- prompt/completion token counts where appropriate;
- backend selected;
- error class;
- GPU/worker health correlation.

Avoid logging sensitive prompt contents by default.

### Exit criteria

A slow or failed request can be traced to a layer rather than diagnosed from unrelated logs.

## 17. Add controlled deployment workflows

Git changes should become the source for deployment changes.

A conservative local flow:

```text
change
 -> PR / review
 -> CI
 -> merge
 -> explicit deployment
 -> health validation
 -> rollback if unhealthy
```

Avoid auto-deploying experimental model/runtime changes to every host.

Separate:

```text
stable profiles
experimental profiles
```

### Exit criteria

Infrastructure changes are reviewable, testable, and reversible.

## 18. Add inventory and version control for infrastructure state

Track:

- node role;
- OS/kernel;
- GPU/driver;
- Docker version;
- inference runtime versions;
- model/version/checksum;
- service profile;
- network role;
- last validation date.

Do not expose serial numbers, MAC addresses, public IPs, account names, or other unnecessary identifiers in the public repository.

### Exit criteria

The intended software/hardware state of each role is documented and drift can be identified.

## 19. Add an incident/recovery format

Use a lightweight postmortem template:

```text
Summary
Impact
Timeline
Detection
Root cause
Contributing factors
Recovery
Corrective actions
What worked
What did not
```

The restart-loop, routing, permissions, and model-template failures already documented are good examples of why this matters.

### Exit criteria

Significant infrastructure failures produce reusable engineering knowledge rather than disappearing into shell history.

# Recommended implementation order

Do not attempt all of Level 2 simultaneously.

The recommended sequence is:

```text
1. Generalize existing scripts
2. Add Python host/GPU monitor
3. Add repository CI + secret scanning
4. Convert stable services to managed systemd/Compose definitions
5. Introduce configuration as code
6. Add Prometheus-compatible metrics + Grafana
7. Add actionable alerts
8. Formalize backup/restore
9. Centralize secrets
10. Harden network/service exposure
11. Define SLOs
12. Run failure tests
13. Add independent serving replicas
14. Add private ingress/load balancing
15. Add end-to-end request observability
16. Add controlled deployment workflow
```

This order deliberately gets **visibility and reproducibility before orchestration complexity**.

# Suggested project milestones

## Milestone A — Observable Lab

Deliverables:

- sanitized Python host/GPU monitor;
- current-state service dashboard/CLI;
- CI + secret scanning;
- generic monitoring docs.

Result:

> Level 1 completed cleanly.

## Milestone B — Managed AI Hosts

Deliverables:

- systemd/Compose service definitions;
- reusable configuration files;
- reboot-safe startup;
- health checks and restart backoff;
- tested backup/restore.

Result:

> Core Level 2 achieved.

## Milestone C — Historical Observability

Deliverables:

- time-series metrics;
- GPU/CPU/network/service dashboards;
- vLLM request metrics;
- alerts.

Result:

> Level 2 becomes operationally useful rather than merely automated.

## Milestone D — Hardened Private Platform

Deliverables:

- centralized secret handling;
- explicit firewall/service exposure policy;
- SLOs;
- failure testing;
- documented recovery procedures.

Result:

> Ready to begin Level 3 architecture work.

## Milestone E — Production-Style Serving

Deliverables:

- independent model replicas;
- private ingress/load balancing;
- request-level observability;
- controlled deployments and rollback;
- infrastructure inventory/drift checks.

Result:

> Level 3: production-style local/private AI platform.

# What not to add yet

Several enterprise technologies are attractive but would add more complexity than value at the current scale.

Do **not** introduce them simply to make the lab look enterprise-like:

- Kubernetes unless workload count/placement complexity actually demands it;
- service mesh;
- multi-region design;
- elaborate policy engines;
- enterprise SIEM;
- large-scale feature stores;
- complex model registries before model lifecycle requires one;
- autoscaling for fixed local hardware where no elastic capacity exists.

If the platform grows enough that one of these solves a real operational problem, add it then and document why.

# Definition of Level 3 for Latent Forge

Latent Forge reaches Level 3 when the following statement is true:

> A documented private AI service can be deployed from source-controlled configuration, started and recovered automatically, monitored historically, protected by explicit network and secret controls, upgraded through a controlled workflow, and continue serving through at least one planned component failure when its deployment profile is designed for availability.

That is a useful production-style standard without pretending the local environment needs all the machinery of a hyperscale cloud platform.