# Dockerized OpenAI Symphony

This repository contains a Docker deployment wrapper for [openai/symphony](https://github.com/openai/symphony). The image is built from `docker.1ms.run/ubuntu:24.04`, clones Symphony, installs Erlang/Elixir through `mise`, installs the Codex CLI, builds the Elixir escript, and starts the Symphony service with the Phoenix dashboard enabled.

## Files

- `Dockerfile` - builds Symphony from GitHub on Ubuntu 24.04.
- `docker-compose.yml` - starts the service, publishes port `4000`, and persists logs/workspaces in a named volume.
- `docker/entrypoint.sh` - creates runtime directories and runs `./bin/symphony`.
- `docker/codex-config.toml` - Codex defaults baked into `/root/.codex/config.toml` in the image.
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
4. Set `OPENAI_API_KEY` to the token/key expected by the configured Codex provider.
5. Adjust `codex.command` if your Codex CLI needs extra config flags.

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

The compose file mounts local `./.ssh` into the container as `/root/.ssh:ro` for private GitLab/GitHub repository access:

```yaml
- ./.ssh:/root/.ssh:ro
```

Put the required SSH key and `known_hosts` files in `./.ssh`, for example:

```bash
cp ~/.ssh/id_ed25519 ./.ssh/id_ed25519
ssh-keyscan gitlab.com >> ./.ssh/known_hosts
chmod 600 ./.ssh/id_ed25519
```

Make sure `SOURCE_REPO_URL` uses an SSH URL, for example `git@gitlab.com:your-group/your-project.git`.

Only `.ssh/.gitkeep` is tracked by Git; actual SSH keys are ignored.

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

## Codex defaults

The image copies `docker/codex-config.toml` to `/root/.codex/config.toml` with these defaults:

- `model_provider = "OpenAI"`
- `model = "gpt-5.5"`
- `review_model = "gpt-5.5"`
- `model_reasoning_effort = "xhigh"`
- `disable_response_storage = true`
- `network_access = "enabled"`
- OpenAI-compatible provider base URL: `https://ebeeai.net`
- `features.goals = true`

If you uncomment the optional `codex-home:/root/.codex` volume in `docker-compose.yml`, that volume will override the baked-in config. Copy `docker/codex-config.toml` into the volume first if you want persistence plus these defaults.

## Notes

- Symphony expects a valid `WORKFLOW.md`; the included example is a template and must be customized.
- The Dockerfile installs Node.js because the default workflow uses `codex app-server`.
- The image uses Symphony's upstream `elixir/mise.toml` for Erlang/Elixir versions.
