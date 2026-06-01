# AI 执行流程说明

本文档说明本项目中 Dockerized OpenAI Symphony 如何驱动 AI Agent 自动处理 Linear Issue、克隆业务仓库、调用 Codex，并在独立 workspace 中执行开发任务。

## 1. 项目角色

本项目本身不是业务代码仓库，而是一个用于运行 OpenAI Symphony 的 Docker 化部署项目。

主要组件如下：

| 组件 | 作用 |
| --- | --- |
| Linear | 任务来源，用户在 Linear 中创建需求或 Bug Issue |
| Symphony | 编排器，负责轮询 Linear、创建 workspace、调度 AI Agent |
| Codex app-server | AI 执行引擎，负责读代码、改代码、运行命令 |
| 业务 Git 仓库 | AI 实际要修改的项目代码仓库 |
| Docker 容器 | 提供 Symphony、Codex、SSH、Git 等运行环境 |
| Dashboard | 浏览器中的 Symphony 状态看板 |

当前 Dashboard 地址：

```text
http://127.0.0.1:4000/
```

## 2. 总体执行链路

AI 处理任务的整体链路如下：

```text
Linear Issue
   ↓
Symphony 轮询 Linear 项目
   ↓
发现处于可执行状态的 Issue
   ↓
创建独立 workspace
   ↓
执行 after_create hook 克隆业务仓库
   ↓
启动 Codex app-server session
   ↓
把 Linear Issue 标题、正文注入 Prompt
   ↓
AI 阅读代码和说明文档
   ↓
AI 修改代码、运行检查
   ↓
AI 输出执行结果
```

## 3. Linear Issue 如何触发 AI

Symphony 会根据 `config/WORKFLOW.md` 中的 tracker 配置连接 Linear。

当前配置示例：

```yaml
tracker:
  kind: linear
  api_key: $LINEAR_API_KEY
  project_slug: "do-meter-357be553595d"
```

执行流程：

1. 用户在 Linear 中创建 Issue。
2. Issue 属于配置的 Linear Project。
3. Issue 状态需要进入 Symphony 会处理的 active 状态，例如 `Todo` 或 `In Progress`。
4. Symphony 轮询到该 Issue 后开始调度 AI Agent。

注意：

- `Backlog` 通常表示待整理/未准备开发的任务，默认不会被 Symphony 执行。
- 如果希望 AI 开始处理任务，应将 Issue 移动到 `Todo`。

## 4. Workspace 创建流程

每个被处理的 Linear Issue 都会对应一个独立 workspace。

workspace 根目录由环境变量控制：

```text
SYMPHONY_WORKSPACE_ROOT=/data/workspaces
```

例如 Linear Issue 是 `DO-5`，则 workspace 通常类似：

```text
/data/workspaces/DO-5
```

这样做的好处：

- 每个 Issue 有独立目录。
- 不同任务之间互不污染。
- 方便查看 AI 修改了哪些文件。
- 方便后续生成 patch、提交分支或人工 review。

## 5. 业务仓库克隆流程

业务代码仓库不是这个 Dockerized Symphony 项目本身，而是通过环境变量指定。

相关 `.env` 配置：

```env
SOURCE_REPO_URL=ssh://git@192.168.3.11:2222/si/products/do-meter/portable/app-qt.git
SOURCE_REPO_BRANCH=main
```

`config/WORKFLOW.md` 中的 hook：

```yaml
hooks:
  after_create: |
    git clone --depth 1 --branch "${SOURCE_REPO_BRANCH:-main}" "$SOURCE_REPO_URL" .
```

执行含义：

1. Symphony 创建空 workspace。
2. 进入 workspace。
3. 执行 `git clone`。
4. 按 `SOURCE_REPO_BRANCH` 指定的分支拉取业务仓库。
5. AI 在该 workspace 内对业务代码进行开发。

如果要切换 AI 开发的业务分支，修改 `.env`：

```env
SOURCE_REPO_BRANCH=upstream/do-meter/feat-arkts-to-qt-5.12
```

然后重启容器：

```bash
docker compose up -d --force-recreate symphony
```

## 6. SSH 私有仓库访问流程

业务仓库是私有仓库，因此容器需要 SSH key。

本项目将宿主机项目内的 `.ssh` 目录挂载到容器：

```yaml
./.ssh:/host-ssh:ro
```

容器启动时，`docker/entrypoint.sh` 会把 `/host-ssh` 中的文件复制到：

```text
/root/.ssh
```

并修正权限，避免 OpenSSH 报错：

```text
Bad owner or permissions on /root/.ssh/config
```

因此，实际流程是：

```text
宿主机 ./.ssh
   ↓ bind mount
容器 /host-ssh
   ↓ entrypoint 复制并 chmod
容器 /root/.ssh
   ↓
git clone 私有仓库
```

注意：

- 不要把私钥提交到 Git。
- `.ssh` 目录中实际密钥文件应保持在 `.gitignore` 中。
- 只提交 `.ssh/.gitkeep` 这类占位文件即可。

## 7. Codex 启动流程

Symphony 通过 `config/WORKFLOW.md` 中的 `codex.command` 启动 Codex：

```yaml
codex:
  command: "$CODEX_BIN app-server"
  approval_policy: never
```

`.env` 中：

```env
CODEX_BIN=codex
OPENAI_API_KEY=...
```

实际执行相当于：

```bash
codex app-server
```

容器镜像内置 Codex 配置文件：

```text
/root/.codex/config.toml
```

该文件来自项目中的：

```text
docker/codex-config.toml
```

当前 provider 配置示例：

```toml
model_provider = "OpenAI"
model = "gpt-5.5"
review_model = "gpt-5.5"

[model_providers.OpenAI]
name = "OpenAI"
base_url = "https://ebeeai.net"
wire_api = "responses"
env_key = "OPENAI_API_KEY"
requires_openai_auth = true
```

其中：

- `base_url` 是 OpenAI-compatible 网关地址。
- `env_key` 指定从 `OPENAI_API_KEY` 环境变量读取 API Key。
- `wire_api = "responses"` 表示使用 Responses API 形式。

## 8. AI 收到的任务 Prompt

`config/WORKFLOW.md` 中 YAML front matter 之后的 Markdown 内容就是发给 AI 的任务模板。

当前示例：

```md
You are working on Linear issue {{ issue.identifier }}.

Title: {{ issue.title }}

Body:
{{ issue.description }}

Follow the repository instructions, make focused changes, run relevant checks, and report proof of work.
```

Symphony 会把 Linear Issue 的真实字段替换进去，例如：

```text
{{ issue.identifier }} → DO-5
{{ issue.title }}      → Linear Issue 标题
{{ issue.description }}→ Linear Issue 正文
```

因此，AI 实际看到的是：

```text
你正在处理 DO-5。
标题是 xxx。
正文是 xxx。
请按仓库说明开发，做聚焦修改，运行检查，并报告结果。
```

## 9. SPEC.md 的作用

`SPEC.md` 不是 Symphony 必须存在的文件，但推荐业务仓库使用。

它通常表示：

```text
需求规格说明文件
```

也就是给 AI 或开发者看的详细开发说明。

推荐 `SPEC.md` 包含：

```md
# SPEC.md

## 背景
说明为什么要做这个需求。

## 目标
说明这次要实现什么。

## 非目标
说明这次明确不做什么。

## 功能需求
列出具体功能点。

## 技术要求
说明涉及模块、接口、数据结构、兼容性等。

## 验收标准
- [ ] 条件 1
- [ ] 条件 2
- [ ] 条件 3

## 测试要求
说明需要运行哪些测试或人工验证步骤。
```

如果业务仓库中存在 `SPEC.md`，建议在 `config/WORKFLOW.md` 的 Prompt 中明确要求 AI 优先读取：

```md
Before making changes:
1. Read SPEC.md if it exists.
2. Read README.md and project instructions if they exist.
3. Identify the minimal files needed for the task.
4. Make focused changes only.
5. Run relevant checks.
6. Report changed files and proof of work.

If SPEC.md exists, treat it as the source of truth for requirements and acceptance criteria.
```

## 10. 推荐的实际使用流程

推荐团队按下面方式使用 AI 开发：

```text
1. 在业务仓库准备需求说明，例如 SPEC.md 或 docs/specs/DO-5.md
2. 在 Linear 创建 Issue
3. 在 Issue 正文中引用需求说明文件路径
4. 将 Issue 状态改为 Todo
5. Symphony 自动发现 Issue
6. Symphony 创建 workspace 并克隆业务仓库指定分支
7. Codex 根据 Issue 和 SPEC.md 执行开发
8. AI 修改代码并运行检查
9. 人工查看 workspace 或生成 patch/PR
10. 人工 review 后合并
```

## 11. 常见状态和日志判断

查看容器状态：

```bash
docker compose ps symphony
```

查看实时日志：

```bash
docker compose logs -f symphony
```

进入容器：

```bash
docker compose exec symphony bash
```

查看 workspace：

```bash
docker compose exec symphony ls -la /data/workspaces
```

测试 Codex 是否可用：

```bash
docker compose exec symphony sh -lc 'cd /data/workspaces/DO-5 && codex exec --skip-git-repo-check "Reply exactly: OK"'
```

如果返回：

```text
OK
```

说明 Codex provider 和 API Key 基本可用。

## 12. 常见问题

### 12.1 Issue 在 Backlog，为什么 AI 没有处理？

`Backlog` 通常不是 active 开发状态。将 Issue 移动到 `Todo` 后，Symphony 才会调度。

### 12.2 报 `unknown variant reject` 怎么办？

说明 Symphony 传给 Codex 的 `approval_policy` 和当前 Codex 版本不兼容。

应在 `config/WORKFLOW.md` 中设置：

```yaml
codex:
  approval_policy: never
```

### 12.3 报 `401 Unauthorized` / `API_KEY_REQUIRED` 怎么办？

说明 Codex 请求模型网关时没有正确携带 API Key。

应确认 `docker/codex-config.toml` 中 provider 有：

```toml
env_key = "OPENAI_API_KEY"
```

并确认 `.env` 中存在：

```env
OPENAI_API_KEY=...
```

修改后重建镜像：

```bash
DOCKER_BUILDKIT=0 docker compose up -d --build symphony
```

### 12.4 私有仓库 clone 失败怎么办？

检查：

1. `.env` 中 `SOURCE_REPO_URL` 是否正确。
2. `.ssh` 中是否有正确私钥。
3. `.ssh/config` 是否配置了正确 Host、Port、IdentityFile。
4. `known_hosts` 是否包含目标 Git 服务。
5. 容器内 `/root/.ssh` 权限是否正确。

### 12.5 如何切换业务仓库分支？

修改 `.env`：

```env
SOURCE_REPO_BRANCH=目标分支名
```

然后重启：

```bash
docker compose up -d --force-recreate symphony
```

## 13. 当前关键配置文件

| 文件 | 作用 |
| --- | --- |
| `.env` | 运行时环境变量，包含 Linear、OpenAI、业务仓库地址等 |
| `.env.example` | 环境变量模板 |
| `config/WORKFLOW.md` | Symphony 工作流配置和 AI Prompt |
| `docker/codex-config.toml` | Codex 模型 provider 配置 |
| `docker-compose.yml` | Docker 服务、端口、volume、env 配置 |
| `docker/entrypoint.sh` | 容器启动脚本，处理 SSH、启动 Symphony |
| `Dockerfile` | 构建 Symphony + Codex 运行镜像 |

## 14. 简短总结

本项目的 AI 执行流程可以概括为：

```text
Linear 派任务 → Symphony 调度 → 创建 workspace → clone 业务仓库 → Codex 执行开发 → 人工 review
```

`SPEC.md` 推荐作为 AI 的需求规格说明文件，用来约束 AI 开发范围、验收标准和测试要求。对于复杂任务，建议优先编写或引用 `SPEC.md`，再让 AI 执行。