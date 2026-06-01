# Dockerized OpenAI Symphony

This repository contains a Docker deployment wrapper for [openai/symphony](https://github.com/openai/symphony). The image is built from `docker.1ms.run/ubuntu:24.04`, clones Symphony, installs Erlang/Elixir through `mise`, installs the Codex CLI, builds the Elixir escript, and starts the Symphony service with the Phoenix dashboard enabled.

## Files

- `Dockerfile` - builds Symphony from GitHub on Ubuntu 24.04.
- `docker-compose.yml` - starts the service, publishes port `4000`, and persists logs/workspaces in a named volume.
- `docker/entrypoint.sh` - creates runtime directories and runs `./bin/symphony`.
- `.env.example` - environment template.
- `WORKFLOW.example.md` - starter Symphony workflow configuration.

## Quick start

```bash
cp .env.example .env
mkdir -p config
cp WORKFLOW.example.md config/WORKFLOW.md
```

Edit `.env` and `config/WORKFLOW.md`:

1. Set `LINEAR_API_KEY`.
2. Set your Linear `project_slug` in `config/WORKFLOW.md`.
3. Set `SOURCE_REPO_URL` to the repository agents should clone for workspaces.
4. Adjust `codex.command` if your Codex CLI needs extra config flags.

Build and start:

```bash
docker compose up -d --build
```

Open the dashboard:

```text
http://localhost:4000
```

View logs:

```bash
docker compose logs -f symphony
```

Stop:

```bash
docker compose down
```

## Private repositories

If `hooks.after_create` clones a private repository over SSH, uncomment this volume in `docker-compose.yml`:

```yaml
- ~/.ssh:/root/.ssh:ro
```

Make sure the host has the required deploy key/SSH config and that `SOURCE_REPO_URL` uses an SSH URL.

## Runtime data

The compose file persists runtime state in the `symphony-data` volume:

- `/data/logs` - Symphony logs.
- `/data/workspaces` - issue workspaces created by Symphony.

The workflow file is bind-mounted from `./config/WORKFLOW.md`, so you can edit it without rebuilding the image. Restart the container after changing environment variables:

```bash
docker compose restart symphony
```

## Build customization

You can change build args in `docker-compose.yml`:

- `SYMPHONY_REPO` - Git repository to clone.
- `SYMPHONY_REF` - branch/tag/commit-ish to build.
- `CODEX_PACKAGE` - npm package installed globally for the `codex` command.

## Notes

- Symphony expects a valid `WORKFLOW.md`; the included example is a template and must be customized.
- The Dockerfile installs Node.js because the default workflow uses `codex app-server`.
- The image uses Symphony's upstream `elixir/mise.toml` for Erlang/Elixir versions.
