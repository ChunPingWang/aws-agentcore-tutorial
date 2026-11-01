#!/usr/bin/env bash
# 清理：依工作坊 Summary → Clean Up 步驟移除所有資源
#   1. agentcore remove all + agentcore deploy  → 移除 Runtime / Memory / Gateway / Identity / Evaluation / Policy
#   2. 刪除前置 CloudFormation 堆疊             → Cognito、warranty/refund Lambda、IAM 角色、SSM 參數
#   3.（選用）刪除 CDKToolkit 堆疊與其 S3 / ECR  → 只在這個帳號不再使用 CDK 時才做
source "$(dirname "$0")/lib.sh"
PREREQ_STACK="${PREREQ_STACK:-agentcore-workshop-prereqs}"   # 工作坊預設名稱為 prereqs

step "1/3 移除 AgentCore 資源"
if [ -d "$PROJECT" ]; then
  cd "$PROJECT"
  agentcore remove all -y 2>/dev/null || agentcore remove all
  agentcore deploy -y          # 不要接 | tail，否則看不到進度且 state 可能未寫回
  aws cloudformation wait stack-delete-complete --stack-name AgentCore-CustomerSupport-default 2>/dev/null || true
else
  echo "找不到 $PROJECT，改為直接刪除 AgentCore 堆疊"
  aws cloudformation delete-stack --stack-name AgentCore-CustomerSupport-default
  aws cloudformation wait stack-delete-complete --stack-name AgentCore-CustomerSupport-default
fi

step "2/3 刪除前置堆疊：$PREREQ_STACK"
aws cloudformation delete-stack --stack-name "$PREREQ_STACK"
aws cloudformation wait stack-delete-complete --stack-name "$PREREQ_STACK"

step "3/3（選用）CDKToolkit"
if [ "${DELETE_CDK_BOOTSTRAP:-false}" = "true" ]; then
  B=$(aws cloudformation describe-stack-resources --stack-name CDKToolkit \
      --query "StackResources[?ResourceType=='AWS::S3::Bucket'].PhysicalResourceId" --output text)
  for b in $B; do
    python3 - "$b" <<'PY'
import boto3, sys
b = boto3.resource("s3").Bucket(sys.argv[1]); b.object_versions.delete()
PY
  done
  aws cloudformation delete-stack --stack-name CDKToolkit
  aws cloudformation wait stack-delete-complete --stack-name CDKToolkit
else
  echo "略過（設定 DELETE_CDK_BOOTSTRAP=true 才刪除）"
fi

step "殘留檢查"
aws bedrock-agentcore-control list-agent-runtimes --query 'agentRuntimes[].agentRuntimeName' --output text || true
aws bedrock-agentcore-control list-memories      --query 'memories[].id' --output text || true
aws bedrock-agentcore-control list-gateways      --query 'items[].name' --output text || true
aws logs describe-log-groups --log-group-name-prefix /aws/bedrock-agentcore --query 'logGroups[].logGroupName' --output text || true
echo "CloudWatch 日誌群組不會自動刪除，如需刪除請手動處理。"
