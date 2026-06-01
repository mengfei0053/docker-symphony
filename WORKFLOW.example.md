---
tracker:
  kind: linear
  # Keep unset to read from LINEAR_API_KEY at runtime.
  api_key: $LINEAR_API_KEY
  # Replace with your Linear project slug, or set LINEAR_PROJECT_SLUG in .env and edit this value.
  project_slug: "your-linear-project-slug"
workspace:
  # Mounted volume path inside the container.
  root: $SYMPHONY_WORKSPACE_ROOT
hooks:
  after_create: |
    git clone --depth 1 "$SOURCE_REPO_URL" .
agent:
  max_concurrent_agents: 2
  max_turns: 20
codex:
  # The Docker image installs @openai/codex globally. Adjust flags/model for your environment.
  command: "$CODEX_BIN app-server"
server:
  # The entrypoint also passes --port; keep this for explicit config readability.
  port: 4000
---

You are working on Linear issue {{ issue.identifier }}.

Title: {{ issue.title }}

Body:
{{ issue.description }}

Follow the repository instructions, make focused changes, run relevant checks, and report proof of work.
