#!/usr/bin/env bash
# 共用設定：每支 lab 腳本都會 source 這個檔案
set -euo pipefail
[ -f ~/.agentcore-env ] && { set +u; . ~/.agentcore-env; set -u; }
TUTORIAL_DIR="${TUTORIAL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LABS="$TUTORIAL_DIR/labs"
PROJECT_PARENT="${PROJECT_PARENT:-${WORK:-$HOME}}"
PROJECT="$PROJECT_PARENT/CustomerSupport"
APP="$PROJECT/app/CustomerSupport"
step() { printf '\n\033[34m==> %s\033[0m\n' "$*"; }
uuid() { python3 -c 'import uuid; print(uuid.uuid4())'; }
ssm()  { aws ssm get-parameter --name "/app/customersupport/agentcore/$1" --query Parameter.Value --output text; }
# 由 lab4-user-token.sh 產生的 Token 檔（操作者本人執行）
TOKEN_FILE="${TOKEN_FILE:-${WORK:-$HOME}/.token}"
token() { [ -s "$TOKEN_FILE" ] || { echo "請先執行 scripts/lab4-user-token.sh 取得 Token" >&2; return 1; }; cat "$TOKEN_FILE"; }
get_token() {
  aws cognito-idp initiate-auth --auth-flow USER_PASSWORD_AUTH \
    --client-id "$(ssm web_client_id)" \
    --auth-parameters "USERNAME=workshopuser@example.com,PASSWORD=WorkshopPass1!" \
    --query 'AuthenticationResult.AccessToken' --output text
}
