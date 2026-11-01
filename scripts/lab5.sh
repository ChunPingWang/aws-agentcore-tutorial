#!/usr/bin/env bash
# Lab 5：AgentCore Evaluations（線上評估＋隨需評估）
source "$(dirname "$0")/lib.sh"
cd "$PROJECT"

step "Step 1–2：建立並部署線上評估"
agentcore add online-eval --name QualityMonitor --runtime CustomerSupport \
  --evaluator Builtin.GoalSuccessRate Builtin.Correctness Builtin.ToolSelectionAccuracy \
  --sampling-rate 100 --enable-on-create
agentcore deploy -y -v
agentcore status

step "Step 3：產生測試互動"
TOKEN=$(token)
SESSION_EVAL=$(uuid)
for q in "What can you tell me about the Smart Watch? What's the price and warranty?" \
         "I bought headphones last week but they're not working. What's the return policy for audio products?" \
         "Check the warranty status for product PROD-001" \
         "I want to return my USB-C Hub. What's the policy, and can you check if it's still under warranty?" \
         "What kind of support can you provide? List your capabilities."; do
  agentcore invoke "$q" --session-id "$SESSION_EVAL" --bearer-token "$TOKEN" --stream
done

step "Step 5：隨需評估（等待 Trace 索引約數分鐘）"
sleep 300
agentcore run eval --runtime CustomerSupport --evaluator Builtin.GoalSuccessRate Builtin.Correctness --days 1

step "Step 6：評估歷史與線上評估日誌"
agentcore evals history --runtime CustomerSupport --limit 5
agentcore logs evals --runtime CustomerSupport --since 30m | tail -50
