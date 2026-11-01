#!/usr/bin/env bash
# Lab 1：建立 Agent 原型並部署到 AgentCore Runtime
source "$(dirname "$0")/lib.sh"

step "Step 1：建立專案"
cd "$PROJECT_PARENT"
[ -d CustomerSupport ] || agentcore create --name CustomerSupport --framework Strands --model-provider Bedrock --memory none
cd "$PROJECT"

step "Step 3：換上客服工具與固定模型"
cp "$LABS/lab1/main.py" app/CustomerSupport/main.py
# 工作坊原版使用 Sonnet 5.5（labs/lab1/load.py）；若帳號尚未開通 5.5，
# 設定 MODEL=sonnet45 改用 Sonnet 4.5（本教材實測使用此版本）
if [ "${MODEL:-sonnet45}" = "sonnet45" ]; then
  cp "$LABS/lab1/load_sonnet45.py" app/CustomerSupport/model/load.py
else
  cp "$LABS/lab1/load.py" app/CustomerSupport/model/load.py
fi
python3 -c "import ast; ast.parse(open('app/CustomerSupport/main.py').read()); print('OK: parses')"
grep -c 'def get_return_policy\|def get_product_info\|def invoke\|def get_or_create_agent' app/CustomerSupport/main.py
grep -o 'model_id="[^"]*"' app/CustomerSupport/model/load.py

step "Step 4–5：本機測試（非互動模式）"
echo "互動測試請執行：agentcore dev --no-browser"

step "Step 6：部署到 AWS"
agentcore deploy -y
agentcore status
agentcore invoke "What can you do?"
