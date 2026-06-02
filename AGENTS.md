# AGENTS.md

## Cursor Cloud specific instructions

This repository is a **Docker wrapper** for [OpenAI Symphony](https://github.com/openai/symphony). There is no host-side `package.json`, `mix.exs`, or application test suite—development means configuring `.env` / `config/WORKFLOW.md` and running the `symphony` Compose service.

### Prerequisites

- **Docker** and **Docker Compose** (plugin). On Cloud Agent VMs, use `sudo docker` / `sudo docker compose` unless your user is in the `docker` group.
- **fuse-overlayfs** storage driver and **iptables-legacy** are required for Docker-in-Docker on these VMs (see VM setup docs).

### First-time / config bootstrap

From the repo root:

```bash
cp .env.example .env
mkdir -p config
cp WORKFLOW.example.md config/WORKFLOW.md
```

Edit `.env` and `config/WORKFLOW.md` before relying on Linear polling or Codex agents (see `README.md`).

### Run Symphony

```bash
sudo docker compose up -d --build
sudo docker compose logs -f symphony
```

Stop: `sudo docker compose down`

### Dashboard access (important)

Symphony’s Phoenix dashboard listens on **`127.0.0.1:4000` inside the container**, not `0.0.0.0`. Published port `4000:4000` often **does not** work from the VM host (`curl` may get “connection reset”).

**Verify inside the container** (always works):

```bash
sudo docker exec openai-symphony curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4000/
```

**Access from the host** (runtime workaround, no repo changes):

```bash
PID=$(sudo docker inspect -f '{{.State.Pid}}' openai-symphony)
sudo nsenter -t "$PID" -n socat TCP-LISTEN:4001,bind=0.0.0.0,reuseaddr,fork TCP:127.0.0.1:4000 &
IP=$(sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' openai-symphony)
socat TCP-LISTEN:4001,bind=127.0.0.1,reuseaddr,fork TCP:${IP}:4001 &
```

Open **http://127.0.0.1:4001/** (“Symphony Observability”).

### Lint / tests

No in-repo lint or unit tests. Validation is operational: container `Up`, dashboard HTTP 200, and (optionally) `sudo docker exec openai-symphony codex --version`.

### Full agent E2E (optional)

Requires secrets and external services: `LINEAR_API_KEY`, valid `project_slug` in `config/WORKFLOW.md`, `OPENAI_API_KEY`, reachable `SOURCE_REPO_URL`, and SSH keys under `./.ssh` for private clones. See `README.md` and `docs/AI_EXECUTION_FLOW.md`.
