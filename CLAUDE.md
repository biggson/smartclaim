# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Setup

Copy `.env.example` to `.env` (if present) and set:
```
PROJECT_ENDPOINT=<Azure AI Foundry project endpoint>
MODEL_DEPLOYMENT_NAME=gpt-4o-mini
```

Install dependencies (the `--pre` flag is required for the preview SDK):
```bash
pip install --pre -r requirements.txt
```

Authenticate locally:
```bash
az login
```
`DefaultAzureCredential` picks up the Azure CLI session automatically.

## Running

**Local dev server:**
```bash
uvicorn app.main:app --reload --port 8000
```

**Individual lab scripts:**
```bash
python labs/lab0_test_connection.py
python labs/lab1_hello_agent.py
# ... through lab8
```

**Production (Azure App Service):**
```bash
bash startup.sh
```

## Architecture

### Core flow

`app/main.py` (FastAPI routes) → `app/agent_service.py` (AgentService) → Azure AI Foundry (Microsoft Foundry Agent Service + Azure OpenAI)

`AgentService` is a stateful singleton that manages the entire agent lifecycle:
1. **File upload** — CSVs are uploaded to OpenAI Files (for Code Interpreter) and read into memory (`self.claims_data`); markdown/text docs are vectorized into a vector store (RAG).
2. **Agent creation** (`_create_agent`) — Called after every upload. Assembles a tool list (code_interpreter, file_search, custom function schemas) and calls `project_client.agents.create_version()`.
3. **Chat / function call loop** (`chat`) — Each user message opens a fresh conversation, then loops up to 10 rounds resolving function calls before returning the final text.
4. **Analytics** (`analytics_chat`) — Pre-aggregates the in-memory CSV in Python, injects the summary into the prompt, and returns both a text response and a `chart` dict for Chart.js rendering. Also saves a PNG via matplotlib to `outputs/`.

### Microsoft Foundry Agent Service v2.x patterns

These are non-obvious SDK constraints that differ from standard OpenAI usage:

- **`responses.create()` with `agent_reference`**: pass agent name/version in `extra_body={"agent_reference": {...}}`. Do **not** pass `tools=` here — tools live on the agent definition, and including `tools=` causes HTTP 400.
- **Multi-turn function call loop**: first call uses `conversation=conversation_id`; follow-up calls (submitting tool results) use `previous_response_id=response.id` instead of `conversation=`.
- **Agent versioning**: `project_client.agents.create_version(agent_name=..., definition=PromptAgentDefinition(...))` — multiple versions coexist under the same name.
- **Vector stores**: accessed via `openai_client.vector_stores.*` (not `project_client`).

### Custom function tools

Two tools are registered on the agent and executed locally (not by the model):

- `get_claim_status(claim_id)` — searches `self.claims_data` (the uploaded CSV) by claim ID.
- `calculate_fraud_risk(incident_type, claim_amount, region, days_since_policy_start)` — rule-based scoring, returns a JSON risk score and level.

`utils/business_functions.py` contains the same logic reading directly from `data/contoso_claims_data.csv`, used by the standalone lab scripts (labs 5–6).

### Labs

`labs/` is a progressive learning sequence (lab0–lab8) covering connection testing, basic agents, data generation, RAG (file_search), Code Interpreter, function tools, multi-tool, Tavily web search, and production patterns (OpenTelemetry tracing, versioning, error handling). Each lab is self-contained but shares `utils/config.py` for client setup.

### Data

- `data/contoso_claims_data.csv` — synthetic insurance claims dataset (claim IDs in `CLM-XXXX` format)
- `data/contoso_insurance_policy.md` — policy document used for RAG demos
- `outputs/` — chart PNGs saved by `analytics_chat()`
