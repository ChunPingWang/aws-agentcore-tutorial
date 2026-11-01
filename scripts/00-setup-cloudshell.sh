#!/usr/bin/env bash
# 在 AWS CloudShell（us-east-1）準備 Workshop 所需工具：Node.js 22、uv、AgentCore CLI
# CloudShell 的家目錄只有 1 GB，大型檔案（Node、Python、套件快取、專案）放在 /tmp/workshop。
# 注意：/tmp 在 CloudShell 工作階段結束後會清空；執行 99-backup-state.sh 可把部署狀態備份到家目錄。
set -euo pipefail

export WORK=/tmp/workshop
mkdir -p "$WORK"

cat > ~/.agentcore-env <<'ENV'
export WORK=/tmp/workshop
export NVM_DIR=/tmp/workshop/.nvm
export UV_CACHE_DIR=/tmp/workshop/.uv-cache
export UV_PYTHON_INSTALL_DIR=/tmp/workshop/.uv-python
export UV_TOOL_DIR=/tmp/workshop/.uv-tools
export npm_config_cache=/tmp/workshop/.npm
export PATH="$HOME/.local/bin:$PATH"
export AWS_DEFAULT_REGION=us-east-1
export AWS_REGION=us-east-1
if [ -s "$NVM_DIR/nvm.sh" ]; then . "$NVM_DIR/nvm.sh"; fi
ENV
grep -q agentcore-env ~/.bashrc || echo '[ -f ~/.agentcore-env ] && . ~/.agentcore-env' >> ~/.bashrc
set +eu   # nvm.sh 不相容 set -eu
# shellcheck disable=SC1090
. ~/.agentcore-env

# 1. Node.js 22（nvm）
if ! command -v node >/dev/null || [[ "$(node --version)" != v22* ]]; then
  mkdir -p "$NVM_DIR"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | PROFILE=/dev/null bash
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install 22
  nvm alias default 22
fi
set -euo pipefail

# 2. uv
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh

# 3. AgentCore CLI（Workshop 指定版本）
npm install -g @aws/agentcore@0.30.0

# 4. git 身分（agentcore create 會初始化 git）
git config --global user.name  >/dev/null || git config --global user.name  "agentcore-lab"
git config --global user.email >/dev/null || git config --global user.email "agentcore-lab@example.com"

echo "---- 驗證 ----"
aws sts get-caller-identity --query Arn --output text | sed -E 's/[0-9]{12}/************/'
node --version
uv --version
agentcore --version
