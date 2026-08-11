# Security and Reliability

Latent Forge is a public infrastructure repository. That changes the standard for what belongs in code, examples, logs, screenshots, and operational documentation.

The goal is to make experiments reproducible **without publishing secrets, private network details that create unnecessary exposure, personal data, or fragile machine-specific assumptions**.

## Security principles

### Never commit secrets

Do not commit:

- API keys
- access tokens
- passwords
- private SSH keys
- OAuth credentials
- cookies or browser session data
- model-provider credentials
- database credentials
- email credentials
- private certificates

Use environment variables or an external secret store. Public examples should use placeholders only.

Good:

```bash
export HF_TOKEN="<your-hugging-face-token>"
```

Bad:

```bash
export HF_TOKEN="hf_actual_secret_here"
```

Where configuration files are required, commit an `.env.example` or sanitized example and keep the real file ignored.

### Sanitize machine-specific information

Hostnames and RFC1918 addresses are often acceptable in reproducible lab documentation, but public documentation should avoid publishing information that provides no engineering value and unnecessarily fingerprints the environment.

Prefer role names in reusable scripts:

```text
head
worker-1
inference-host
storage-host
```

rather than personal usernames, home-directory names, public IP addresses, router identifiers, account emails, or unrelated device names.

When historical experiments depend on specific addresses, label them as example/lab values and make scripts configurable.

### Never publish private application data

Latent Forge should not contain:

- investment holdings or watchlists
- private datasets
- application databases
- personal documents
- email contents
- journals or performance records
- production logs containing user data

Use mock or synthetic examples where data is needed.

### Treat logs as potentially sensitive

Before committing logs, inspect them for:

- tokens
- Authorization headers
- URLs containing credentials
- usernames and home paths
- internal/public IP addresses
- email addresses
- device IDs
- request contents
- file paths revealing private data

Prefer short, manually curated excerpts showing only the failure being documented.

Do not blindly commit `journalctl`, Docker, model-server, agent-runtime, or application logs.

### Keep generated state out of Git

At minimum, `.gitignore` should exclude categories such as:

```gitignore
.env
.env.*
!.env.example

*.log
logs/

.venv/
venv/
__pycache__/
*.pyc

.cache/

# Model weights and local runtime state
*.gguf
*.safetensors
*.bin
models/

# Common agent/runtime state
.openclaw/
.hermes/

# Local databases and user data
*.db
*.sqlite
*.sqlite3
```

Extend this list as new tools are added.

### Minimize privileges

Monitoring and inference scripts should not require root unless the underlying metric genuinely requires it.

Prefer:

- unprivileged processes
- read-only mounts where possible
- dedicated service users for long-running services
- explicit Docker mounts instead of broad host filesystem access
- narrow network exposure

Avoid `--privileged`, mounting `/` into containers, or running services as root merely to avoid fixing permissions.

### Bind services deliberately

Many AI runtimes default to loopback; others are commonly launched on `0.0.0.0` for convenience.

Treat `0.0.0.0` as an explicit security decision, not a harmless default.

Before exposing Ollama, llama.cpp, vLLM, Ray, Open WebUI, Hermes, OpenClaw, Jupyter, or monitoring endpoints beyond localhost, decide:

1. who should reach the service;
2. whether the protocol provides authentication;
3. which network interface should accept traffic;
4. whether host firewall rules are required;
5. whether remote access should instead traverse SSH or a private overlay network.

Do not expose unauthenticated inference or agent endpoints directly to the public Internet.

### Agent runtimes require a stronger trust boundary

Hermes and OpenClaw may have filesystem, terminal, browser, messaging, and credential access. Treat them as privileged automation systems.

Recommended practice:

- enable only necessary tools;
- use dedicated workspaces;
- avoid giving agents unrestricted access to `$HOME`;
- avoid injecting long-lived secrets into prompts;
- keep autonomous/scheduled behavior disabled until interactive behavior is understood;
- inspect third-party skills before installation;
- assume prompts and web content can be adversarial.

A local model does not remove prompt-injection or tool-abuse risk.

## Public-repository hygiene

Before every commit that adds operational output, configuration, screenshots, inventories, or new scripts, check:

```bash
git diff --cached
```

Search for likely secrets before pushing. Example local checks can include tools such as `gitleaks` or `trufflehog`; projects may also enable GitHub secret scanning where available.

If a secret is accidentally committed, deleting it in a later commit is not enough. Revoke/rotate it first, then remove it from repository history where appropriate.

## Reliability principles

### Preflight before start

Long-running services should validate configuration and dependencies before entering restart-managed operation.

A bad configuration value should fail clearly before systemd or Docker begins repeatedly restarting the process.

Recommended preflight categories:

- configuration syntax/schema
- required directories
- file ownership and permissions
- model availability
- disk space
- GPU visibility
- required ports
- network routes
- upstream/downstream endpoints

### Use restart backoff

Avoid tight restart loops.

For systemd services, use bounded restart behavior such as:

```ini
[Service]
Restart=on-failure
RestartSec=10

[Unit]
StartLimitIntervalSec=300
StartLimitBurst=5
```

Exact settings should match the service, but the principle is consistent: a persistent configuration failure should become an obvious stopped service, not thousands of restart attempts.

### Make health checks layered

A process being present is not the same as the system being healthy.

A useful hierarchy is:

1. **Process** — is the service running?
2. **Port** — is it listening where expected?
3. **Protocol** — does the API answer?
4. **Inference** — can it perform a minimal model request?
5. **Distributed state** — are all expected nodes/workers present?
6. **Resource health** — memory, GPU, disk, temperature, network errors.

For example, `docker ps` can be green while the model API is unusable.

### Make monitoring non-invasive

Monitoring should not materially alter the workload it is observing.

Prefer low-frequency reads from:

- `nvidia-smi`
- `/sys/class/hwmon`
- `/proc`
- `docker stats --no-stream`
- service health endpoints
- Ray status APIs
- network interface counters

Avoid aggressive polling that consumes meaningful CPU/GPU resources or floods logs.

### Distinguish snapshots from time-series evidence

A single GPU utilization sample can be misleading, especially in pipeline-parallel or bursty workloads.

Documentation must state whether a number is:

- instantaneous;
- averaged over a window;
- peak;
- sustained;
- measured concurrently across nodes.

Do not infer persistent stage imbalance from asynchronous `nvidia-smi` snapshots taken on different machines.

### Verify the path, not just the endpoint

Distributed inference depends on network selection as much as model configuration.

For multi-homed hosts, validate:

```bash
ip route get <peer-ip>
ethtool <interface>
```

and, where appropriate, benchmark the path with `iperf3`.

A working TCP connection does not prove that the intended high-speed interface is being used.

### Persist expensive state intentionally

Model downloads, compilation output, and runtime caches should survive disposable containers when doing so is safe.

Bind only the specific cache directories required rather than broad home directories.

Examples include Hugging Face and vLLM caches. Do not commit those caches to Git.

### Make scripts configurable and idempotent

Public scripts should avoid hard-coded usernames, hostnames, home paths, and interface names unless the script is explicitly an archival record of one experiment.

Prefer environment variables with documented defaults:

```bash
HEAD_IP="${HEAD_IP:-10.10.10.2}"
IFACE="${IFACE:-enP7s7}"
```

Scripts should be safe to run more than once when practical, and should clearly fail rather than silently partially configure a host.

### Check port ownership before changing services

When a service cannot bind, identify what already owns the port before stopping or killing processes:

```bash
ss -ltnp
```

or:

```bash
sudo ss -ltnp
```

Do not solve address-in-use failures with broad `pkill` commands unless the target process is positively identified.

### Validate test collection itself

A test command that exits incorrectly or collects zero intended tests is not evidence of a healthy project.

CI and local validation should check that:

- the intended test suite was actually collected;
- imports work in a clean environment;
- dependency installation is reproducible;
- failures are not being hidden by shell pipelines or ignored exit codes.

### Keep experimental and stable paths distinct

Latent Forge documents experiments, but examples should clearly label their maturity:

```text
validated
experimental
historical
broken / retained for postmortem
```

Do not present a command as the recommended setup merely because it appeared during troubleshooting.

## Monitoring scope

Monitoring added to Latent Forge should cover four layers:

### Host

- CPU utilization and temperature
- RAM and swap
- disk capacity and I/O
- process/service state
- network link state and counters

### Accelerators

- GPU utilization
- GPU/VRAM or unified-memory usage
- temperature
- power where exposed
- throttling/error state

For heterogeneous hosts, monitoring should discover devices dynamically where possible rather than assuming fixed DRM card numbers.

### AI runtimes

- Ollama
- llama.cpp
- vLLM
- Ray
- Open WebUI
- Hermes/OpenClaw where deployed

### Distributed inference

- expected worker/node count
- per-node resource visibility
- API health
- network path/link speed
- concurrent load behavior

## What belongs in this repository

Good public additions:

- generic monitoring scripts
- sanitized systemd unit templates
- documented command-line tools
- health-check examples
- benchmark methodology
- synthetic/sample outputs
- postmortems with sensitive information removed

Keep private:

- raw host logs
- actual credentials
- personal datasets
- private service inventories
- unredacted screenshots containing account or network information
- machine backups or runtime state

## Reliability standard for examples

A configuration documented as **validated** should include enough evidence to reproduce the claim, ideally:

- operating system / architecture
- relevant hardware
- runtime version
- exact important configuration
- verification command
- observed result
- known limitations

This is deliberately stricter than a personal notes repository. Public infrastructure examples should be useful to someone who does not have the original machine or conversational context.