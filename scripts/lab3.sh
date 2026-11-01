#!/usr/bin/env bash
# Lab 3：用 AgentCore Gateway 把既有 Lambda 變成 MCP 工具
source "$(dirname "$0")/lib.sh"
cd "$PROJECT"

step "Step 1：取得 Lambda ARN"
WARRANTY_LAMBDA_ARN=$(ssm warranty_check_lambda_arn)
echo "Lambda ARN: $WARRANTY_LAMBDA_ARN"

step "Step 2：工具 Schema"
mkdir -p app/CustomerSupport/tool
touch app/CustomerSupport/tool/__init__.py
cp "$LABS/lab3/warranty_schema.json" app/CustomerSupport/tool/warranty_schema.json

step "Step 3：新增 Gateway 與 Lambda Target"
agentcore add gateway --name my-gateway --runtimes CustomerSupport
agentcore add gateway-target --type lambda-function-arn --name WarrantyCheck \
  --lambda-arn "$WARRANTY_LAMBDA_ARN" \
  --tool-schema-file app/CustomerSupport/tool/warranty_schema.json --gateway my-gateway

step "Step 4：更新 MCP Client 與 main.py"
cp "$LABS/lab3/client.py" app/CustomerSupport/mcp_client/client.py
cp "$LABS/lab3/main.py"   app/CustomerSupport/main.py

step "Step 5：部署"
agentcore deploy -y -v

step "Step 6：測試 Gateway 工具"
SESSION_C=$(uuid)
agentcore invoke "Check the warranty for product PROD-003" \
  --session-id "$SESSION_C" -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream
agentcore invoke "Is the warranty still valid for PROD-002?" \
  --session-id "$SESSION_C" -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream
