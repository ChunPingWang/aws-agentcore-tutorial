#!/usr/bin/env bash
# Lab 2：加入 AgentCore Memory（SEMANTIC + SUMMARIZATION）
source "$(dirname "$0")/lib.sh"
cd "$PROJECT"

step "Step 1：新增 Memory 資源"
agentcore add memory --name SharedMemory --strategies SEMANTIC,SUMMARIZATION --expiry 30 || true

step "Step 2–3：記憶 Session Manager 與新版 main.py"
mkdir -p app/CustomerSupport/memory
touch app/CustomerSupport/memory/__init__.py
cp "$LABS/lab2/session.py" app/CustomerSupport/memory/session.py
cp "$LABS/lab2/main.py"    app/CustomerSupport/main.py

step "Step 4：允許自訂 User-Id Header"
python3 - <<'PY'
import json
p="agentcore/agentcore.json"; c=json.load(open(p))
for r in c["runtimes"]:
    if r["name"]=="CustomerSupport":
        h=r.setdefault("requestHeaderAllowlist",[])
        if "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id" not in h:
            h.append("X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id")
json.dump(c,open(p,"w"),indent=2)
PY

step "Step 5：部署"
agentcore deploy -y -v

step "Step 6：跨 Session 記憶測試"
SESSION_A=$(uuid)
agentcore invoke "My name is Sarah and I prefer email updates. I recently bought a Smart Watch." \
  --session-id "$SESSION_A" -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream
sleep 120
SESSION_B=$(uuid)
agentcore invoke "Do you know anything about me?" \
  --session-id "$SESSION_B" -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream
SESSION_NEW_USER=$(uuid)
agentcore invoke "What did I just buy?" \
  --session-id "$SESSION_NEW_USER" -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Alex" --stream
