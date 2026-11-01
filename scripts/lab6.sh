#!/usr/bin/env bash
# Lab 6：Flask 客戶前端
# CloudShell 無法以瀏覽器開啟 localhost:8501，因此本腳本以 curl 驗證：
#  (1) Flask 伺服器能向 Cognito 取得 Token 並渲染頁面
#  (2) 以同一組 JWT 直接呼叫 AgentCore REST API（即聊天頁在瀏覽器中做的事）
source "$(dirname "$0")/lib.sh"
cd "$PROJECT"

step "Step 1：安裝套件"
(cd app/CustomerSupport && uv add flask boto3 requests)

step "Step 2–3：建立 Flask 伺服器與聊天頁"
mkdir -p app/CustomerSupport/frontend/templates
touch app/CustomerSupport/frontend/__init__.py
cp "$LABS/lab6/frontend.py" app/CustomerSupport/frontend/frontend.py
if [ -f "$LABS/lab6/index.html" ]; then
  cp "$LABS/lab6/index.html" app/CustomerSupport/frontend/templates/index.html
else
  echo "請從 Workshop 頁面「Click to see index.html」複製內容到 app/CustomerSupport/frontend/templates/index.html"
fi

step "Step 4：開啟 Cognito Web Client 的 USER_PASSWORD_AUTH"
aws cognito-idp update-user-pool-client --user-pool-id "$(ssm pool_id)" --client-id "$(ssm web_client_id)" \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --supported-identity-providers COGNITO --allowed-o-auth-flows code \
  --allowed-o-auth-scopes openid email profile --allowed-o-auth-flows-user-pool-client \
  --callback-urls "http://localhost:8501/" --logout-urls "http://localhost:8501/" --no-cli-pager >/dev/null

step "Step 5：以 REST API 驗證（等同聊天頁的呼叫）"
TOKEN=$(token)
RUNTIME_ARN=$(python3 -c "import json;print(json.load(open('agentcore/.cli/deployed-state.json'))['targets']['default']['resources']['runtimes']['CustomerSupport']['runtimeArn'])")
ENC_ARN=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$RUNTIME_ARN")
SID=$(uuid)
for q in "What products do you have?" "Check warranty for PROD-002" "My name is Alex" "What's my name?"; do
  echo "### $q"
  curl -sS -N -X POST "https://bedrock-agentcore.${AWS_REGION}.amazonaws.com/runtimes/${ENC_ARN}/invocations?qualifier=DEFAULT" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -H "X-Amzn-Bedrock-AgentCore-Runtime-Session-Id: $SID" \
    -d "$(python3 -c 'import json,sys;print(json.dumps({"prompt":sys.argv[1]}))' "$q")"
  echo
done
