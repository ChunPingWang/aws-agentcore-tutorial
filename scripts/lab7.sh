#!/usr/bin/env bash
# Lab 7：以 Cedar Policy 治理 Agent 行為（退款上限）
source "$(dirname "$0")/lib.sh"
cd "$PROJECT"

step "Step 1：新增退款 Lambda 工具"
REFUND_LAMBDA_ARN=$(ssm refund_lambda_arn)
cp "$LABS/lab7/refund_schema.json" app/CustomerSupport/tool/refund_schema.json
agentcore add gateway-target --type lambda-function-arn --name ProcessRefund \
  --lambda-arn "$REFUND_LAMBDA_ARN" \
  --tool-schema-file app/CustomerSupport/tool/refund_schema.json --gateway my-gateway-secure
agentcore deploy -y -v
TOKEN=$(token)
agentcore invoke "I'd like a refund of \$500 for order ORD-12345 because the item was defective" \
  --session-id "$(uuid)" --bearer-token "$TOKEN" --stream

step "Step 2：Policy Engine（ENFORCE）"
agentcore add policy-engine --name CustomerSupportPolicyEngine \
  --description "Governs customer support agent tool access — refund limits and tool permissions" \
  --attach-to-gateways my-gateway-secure --attach-mode ENFORCE

step "Step 3：Cedar 政策"
GATEWAY_ID=$(aws bedrock-agentcore-control list-gateways \
  --query "items[?contains(name, 'my-gateway-secure')].gatewayId | [0]" --output text)
GATEWAY_ARN=$(aws bedrock-agentcore-control get-gateway --gateway-identifier "$GATEWAY_ID" --query gatewayArn --output text)
agentcore add policy --name refund_limit_policy --engine CustomerSupportPolicyEngine \
  --description "Allow refunds under 100 dollars only" \
  --statement "permit(principal, action == AgentCore::Action::\"ProcessRefund___process_refund\", resource == AgentCore::Gateway::\"${GATEWAY_ARN}\") when { context.input.amount < 100 };"
agentcore add policy --name warranty_check_policy --engine CustomerSupportPolicyEngine \
  --description "Allow all authenticated users to check warranties" \
  --statement "permit(principal, action == AgentCore::Action::\"WarrantyCheck___check_warranty\", resource == AgentCore::Gateway::\"${GATEWAY_ARN}\") when { (principal is AgentCore::OAuthUser) };" \
  --validation-mode IGNORE_ALL_FINDINGS
agentcore deploy -y -v

step "Step 4：驗證政策"
TOKEN=$(token)
for q in "I need a refund of \$50 for order ORD-12345. The item arrived damaged." \
         "Process a refund of \$500 for order ORD-67890. I want a full refund." \
         "Check the warranty for PROD-002"; do
  agentcore invoke "$q" --session-id "$(uuid)" --bearer-token "$TOKEN" --stream
done

step "Step 5（Bonus）：自然語言產生 Cedar"
agentcore add policy --name refund_reason_policy --engine CustomerSupportPolicyEngine \
  --generate "Forbid refunds when the reason does not contain the word defective" --gateway my-gateway-secure
agentcore deploy -y -v
for q in "I need a refund of \$50 for order ORD-99999 because the item was defective" \
         "I need a refund of \$50 for order ORD-11111 because I changed my mind"; do
  agentcore invoke "$q" --session-id "$(uuid)" --bearer-token "$TOKEN" --stream
done
