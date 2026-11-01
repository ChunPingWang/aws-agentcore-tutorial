#!/usr/bin/env bash
# Lab 4：Cognito JWT 保護 Runtime 與 Gateway，並觀察 Traces / Logs
source "$(dirname "$0")/lib.sh"
cd "$PROJECT"

step "Step 1–2：狀態與可觀測性"
agentcore status
agentcore traces list --limit 10 || true

step "Step 3：Runtime 改用 Cognito JWT"
COGNITO_DISCOVERY_URL=$(ssm cognito_discovery_url)
COGNITO_CLIENT_ID=$(ssm client_id)
COGNITO_POOL_ID=$(ssm pool_id)
COGNITO_WEB_CLIENT_ID=$(ssm web_client_id)
DISC="$COGNITO_DISCOVERY_URL" C1="$COGNITO_CLIENT_ID" C2="$COGNITO_WEB_CLIENT_ID" python3 - <<'PY'
import json, os
p="agentcore/agentcore.json"; c=json.load(open(p))
for r in c["runtimes"]:
    if r["name"]=="CustomerSupport":
        h=r.setdefault("requestHeaderAllowlist",[])
        if "Authorization" not in h: h.append("Authorization")
        r["authorizerType"]="CUSTOM_JWT"
        r["authorizerConfiguration"]={"customJwtAuthorizer":{
            "discoveryUrl":os.environ["DISC"],"allowedClients":[os.environ["C1"],os.environ["C2"]]}}
json.dump(c,open(p,"w"),indent=2)
PY
(cd app/CustomerSupport && uv add pyjwt)
cp "$LABS/lab4/main_step3.py" app/CustomerSupport/main.py
agentcore validate
agentcore deploy -y -v

step "建立 Cognito 測試使用者並取得 Token（請操作者本人執行）"
[ -s "$TOKEN_FILE" ] || "$(dirname "$0")/lab4-user-token.sh"
TOKEN=$(token)
SESSION_3=$(uuid)
agentcore invoke "What's the return policy for electronics?" --session-id "$SESSION_3" --bearer-token "$TOKEN" --stream
echo "--- 不帶 Token（應被拒絕）---"
agentcore invoke "What's the return policy for electronics?" --session-id "$SESSION_3" --stream --json || true

step "Step 4：Gateway 改用 JWT（移除後重建）"
agentcore remove gateway --name my-gateway -y
agentcore add gateway --name my-gateway-secure --runtimes CustomerSupport \
  --authorizer-type CUSTOM_JWT --discovery-url "$COGNITO_DISCOVERY_URL" \
  --allowed-clients "$COGNITO_CLIENT_ID,$COGNITO_WEB_CLIENT_ID"
agentcore add gateway-target --type lambda-function-arn --name WarrantyCheck \
  --lambda-arn "$(ssm warranty_check_lambda_arn)" \
  --tool-schema-file app/CustomerSupport/tool/warranty_schema.json --gateway my-gateway-secure
cp "$LABS/lab4/client_step4.py" app/CustomerSupport/mcp_client/client.py
cp "$LABS/lab4/main_step4.py"   app/CustomerSupport/main.py
agentcore validate
agentcore deploy -y -v
SESSION_E=$(uuid)
agentcore invoke "Check the warranty for PROD-001" --session-id "$SESSION_E" --bearer-token "$TOKEN" --stream

step "Step 5：產生測試流量"
SESSION_D=$(uuid)
for q in "Hi, my name is Sarah and I recently bought a USB-C Hub" \
         "What's the return policy for accessories?" \
         "Tell me about the USB-C Hub" \
         "Check the warranty for PROD-002" \
         "Do you remember my name?"; do
  agentcore invoke "$q" --session-id "$SESSION_D" --bearer-token "$TOKEN" --stream
done
