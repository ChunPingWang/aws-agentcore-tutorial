#!/usr/bin/env bash
# Lab 4：建立 Cognito 測試使用者並取得 Access Token（請由操作者本人執行）
# 帳密為工作坊文件提供的測試值，只存在於工作坊建立的 User Pool 中。
# Token 預設 1 小時到期，到期後重新執行本腳本即可（使用者已存在時會略過建立）。
source "$(dirname "$0")/lib.sh"
POOL=$(ssm pool_id)

aws cognito-idp admin-create-user --user-pool-id "$POOL" \
  --username workshopuser@example.com --temporary-password 'TempPass1!' \
  --user-attributes Name=email,Value=workshopuser@example.com Name=email_verified,Value=true \
  --message-action SUPPRESS --no-cli-pager >/dev/null 2>&1 || echo "使用者已存在，略過建立"
aws cognito-idp admin-set-user-password --user-pool-id "$POOL" \
  --username workshopuser@example.com --password 'WorkshopPass1!' --permanent --no-cli-pager

umask 077
get_token > "${WORK:-$HOME}/.token"
echo "Token 已寫入 ${WORK:-$HOME}/.token（長度 $(wc -c < "${WORK:-$HOME}/.token")）"
# 之後的指令以 --bearer-token "$(cat $WORK/.token)" 使用
