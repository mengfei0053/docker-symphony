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
  # Current Codex accepts: untrusted, on-failure, on-request, granular, never.
  # Use never for unattended Symphony agent runs.
  approval_policy: never
  # Disable Codex's own OS sandbox. Codex defaults to "workspace-write", which wraps every
  # command in bubblewrap (bwrap). In this unprivileged Docker container bwrap cannot create
  # user namespaces ("bwrap: No permissions to create a new namespace"), so every command
  # fails before running and agents loop without progress. The container itself is the
  # isolation boundary (Symphony runs with --i-understand-...-without-the-usual-guardrails),
  # so Codex runs without its redundant inner sandbox.
  thread_sandbox: danger-full-access
  turn_sandbox_policy:
    type: dangerFullAccess
server:
  # The entrypoint also passes --port; keep this for explicit config readability.
  port: 4000
---

You are working on Linear issue {{ issue.identifier }}.

Title: {{ issue.title }}

Body:
{{ issue.description }}

Follow the repository instructions, make focused changes, run relevant checks, and report proof of work.
