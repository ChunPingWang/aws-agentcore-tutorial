# Lab 1｜建立 Agent 原型並部署

> [前置準備](00-prerequisites.md)・[Lab 1](01-lab1-prototype.md)・[Lab 2](02-lab2-memory.md)・[Lab 3](03-lab3-gateway.md)・[Lab 4](04-lab4-security-observability.md)・[Lab 5](05-lab5-evaluations.md)・[Lab 6](06-lab6-frontend.md)・[Lab 7](07-lab7-policy.md)・[清理與總結](08-cleanup-and-findings.md)

- agentcore create → 換上客服工具 → agentcore dev 本機測試
- agentcore deploy → Runtime READY

對應腳本：[`scripts/lab1.sh`](../scripts/lab1.sh)

## Step 1：agentcore create 建立專案

![Step 1：agentcore create 建立專案](images/l1_01_create.jpg)

- agentcore create --name CustomerSupport --framework Strands --model-provider Bedrock --memory none
- CLI 建立專案目錄、初始化 git、加入 Agent、建立 Python 環境
- 不需撰寫 Dockerfile、ECR 或 IAM

## Step 2：專案結構與 agentcore.json

![app/CustomerSupport 是 Agent 程式碼；agentcore/ 放設定與 CDK 專案](images/l1_02_tree.jpg)

app/CustomerSupport 是 Agent 程式碼；agentcore/ 放設定與 CDK 專案

![agentcore.json：runtimes、memories、agentCoreGateways… 所有資源的單一來源](images/l1_03_agentcore_json.jpg)

agentcore.json：runtimes、memories、agentCoreGateways… 所有資源的單一來源

## Step 3：換上客服工具 main.py 與 load.py

![Step 3：換上客服工具 main.py 與 load.py](images/l1_04_code_verify.jpg)

- main.py：@tool get_return_policy、get_product_info＋Exa MCP 網搜
- @app.entrypoint 以 stream_async 串流回應
- load.py：BedrockModel 固定模型 ID
- ast.parse 驗證語法、grep 確認四個函式都在

> 💡 **重點**：程式碼在 repo 的 labs/lab1/，與工作坊內容逐字一致。

## main.py 重點：工具即 Python 函式

```
@tool
def get_return_policy(product_category: str) -> str:
    """Get return policy information for a
    specific product category."""
    category = product_category.lower()
    if category in RETURN_POLICIES:
        policy = RETURN_POLICIES[category]
        return f"Return policy for {category}: ..."

tools = [get_return_policy, get_product_info]
for mcp_client in mcp_clients:   # Exa AI MCP
    if mcp_client:
        tools.append(mcp_client)

@app.entrypoint
async def invoke(payload, context):
    agent = get_or_create_agent()
    stream = agent.stream_async(payload.get("prompt"))
    async for event in stream:
        if "data" in event and isinstance(event["data"], str):
            yield event["data"]
```

**Strands 的設計**

- docstring 就是工具說明，模型據此決定何時呼叫
- MCP Client 可直接當工具清單的一員
- BedrockAgentCoreApp 把函式包成 /invocations HTTP 端點
- 串流輸出讓前端可以邊收邊顯示

## Step 4：agentcore dev 本機啟動

![Step 4：agentcore dev 本機啟動](images/l1_05_dev_tui.jpg)

- agentcore dev --no-browser 在 localhost:8080 啟動 Dev Server
- TUI 介面直接輸入問題測試
- 改程式碼會自動重新載入

> 💡 **重點**：在 CloudShell 的 TUI 中送出要輸入換行；離開用 Ctrl+C。

## Step 5：第一次測試：AccessDeniedException

![Step 5：第一次測試：AccessDeniedException](images/l1_06_dev_access_denied.jpg)

- ConverseStream 呼叫 claude-sonnet-5-5 被拒
- 新帳號第一次使用 Anthropic 模型需先送出 use case 表單
- 這不是程式問題，是帳號層級的模型存取

> ⚠️ **注意**：新帳號請先在 Bedrock 模型目錄送出 Anthropic 使用案例表單（需由帳號擁有者填寫）。

## Step 6：送出 use case 表單並檢查模型可用性

![Bedrock 模型目錄頂端提示需提交 Anthropic 使用案例](images/l1_07_bedrock_usecase_banner.jpg)

Bedrock 模型目錄頂端提示需提交 Anthropic 使用案例

![get-foundation-model-availability：Sonnet 4.5 可用，Sonnet 5.5 仍為 NOT_AVAILABLE](images/l1_15_model_availability.jpg)

get-foundation-model-availability：Sonnet 4.5 可用，Sonnet 5.5 仍為 NOT_AVAILABLE

## Step 7：改用 Claude Sonnet 4.5

![Sonnet 5.5 模型頁：新帳號需要額外時間開通](images/l1_17_sonnet55_page.jpg)

Sonnet 5.5 模型頁：新帳號需要額外時間開通

![load.py 改為 us.anthropic.claude-sonnet-4-5-20250929-v1:0（repo 提供 load_sonnet45.py）](images/l1_18_switch_model.jpg)

load.py 改為 us.anthropic.claude-sonnet-4-5-20250929-v1:0（repo 提供 load_sonnet45.py）

## Step 8：本機測試本地工具

![退貨政策：呼叫 get_return_policy('electronics')，回答 30 天、需原包裝](images/l1_19_dev_return_policy.jpg)

退貨政策：呼叫 get_return_policy('electronics')，回答 30 天、需原包裝

![商品查詢：無線耳機 $79.99。注意：回答把類別寫成 Electronics，工具資料其實是 audio](images/l1_20_dev_product.jpg)

商品查詢：無線耳機 $79.99。注意：回答把類別寫成 Electronics，工具資料其實是 audio

## Step 9：本機測試 MCP 網搜與多工具

![耳機疑難排解：透過 Exa MCP 搜尋網路資料後整理步驟](images/l1_21_dev_websearch.jpg)

耳機疑難排解：透過 Exa MCP 搜尋網路資料後整理步驟

![一句話同時問商品與退貨：Agent 依序呼叫兩個工具再彙整](images/l1_22_dev_multitool.jpg)

一句話同時問商品與退貨：Agent 依序呼叫兩個工具再彙整

## Step 10：agentcore deploy 與 CDK Bootstrap

![deploy 依序：驗證 → 同步 CDK 相依 → 合成 CloudFormation](images/l1_08_deploy_start.jpg)

deploy 依序：驗證 → 同步 CDK 相依 → 合成 CloudFormation

![帳號首次部署提示 CDK bootstrap，確認後建立 CDKToolkit](images/l1_09_cdk_bootstrap.jpg)

帳號首次部署提示 CDK bootstrap，確認後建立 CDKToolkit

## Step 11：部署進度與完成

![建立 IAM Role、Runtime 等資源](images/l1_10_deploy_progress.jpg)

建立 IAM Role、Runtime 等資源

![Deploy to AWS Complete](images/l1_11_deploy_complete.jpg)

Deploy to AWS Complete

> 實測發現：deploy 接 | tail 會把進度輸出吃掉，看起來像卡住；不要對 deploy 使用管線。

## Step 12：確認 Runtime READY 並從雲端呼叫

![agentcore status：CustomerSupport Deployed - Runtime: READY](images/l1_12_status_ready.jpg)

agentcore status：CustomerSupport Deployed - Runtime: READY

![切換模型前雲端呼叫一樣被拒；切到 Sonnet 4.5 重新部署後即正常](images/l1_16_model_test.jpg)

切換模型前雲端呼叫一樣被拒；切到 Sonnet 4.5 重新部署後即正常


---

[← 回到 README](../README.md)
