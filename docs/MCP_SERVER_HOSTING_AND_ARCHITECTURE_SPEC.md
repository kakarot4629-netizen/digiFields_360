# digiField360 MCP Server & Backend Hosting Architecture Specification

> **Document Target Audience**: Mobile Application Developers, Frontend Engineers, DevOps & Implementation Leads  
> **Last Updated**: August 2026  
> **Status**: Approved Architecture Reference

---

## 🎯 Executive Summary & Direct Answers

| Question | Short Answer | Details |
| --- | --- | --- |
| **Is AWS Mandatory?** | ❌ **NO** | AWS is **not mandatory**. You do not need an AWS account or EC2/Lambda setup to build, test, or run the digiField360 mobile app. |
| **Does the MCP Server need to be hosted?** | ⚡ **NO for Dev/Testing**,  <br>✅ **YES for Production** | During development & mobile UI integration, the server runs locally via `node scripts/mcp-server.js` + `ngrok`. For production, it can be hosted natively on Salesforce or on a 1-click cloud host like Render.com. |
| **How does the MCP Server run?** | 🟢 **Node.js HTTP & JSON-RPC** | It runs as a lightweight, zero-dependency Node.js server exposing REST APIs and JSON-RPC 2.0 endpoints for Salesforce tools and AI Agentforce actions. |

---

## 🏗️ 1. How the MCP Server Runs

The digiField360 repository provides a unified backend gateway located at:
📁 **`scripts/mcp-server.js`**

This server exposes two interface styles on port `3000` (or `process.env.PORT`):

```
                       ┌─────────────────────────────────────────────────┐
                       │           digiField360 Mobile App               │
                       │     (React Native / Flutter / iOS / Android)    │
                       └───────────────────────┬─────────────────────────┘
                                               │
                                       HTTPS Requests
                                               │
                                               ▼
                       ┌─────────────────────────────────────────────────┐
                       │          digiField360 MCP Server Gateway        │
                       │            (scripts/mcp-server.js)              │
                       └───────────────┬─────────────────┬───────────────┘
                                       │                 │
                        REST Endpoints │                 │ JSON-RPC 2.0
                        (/api/...)     │                 │ (/mcp)
                                       ▼                 ▼
                       ┌──────────────────┐   ┌──────────────────────────┐
                       │ REST API Router  │   │     MCP Tools Router     │
                       │ - Auth & Sync    │   │ - sobject_query          │
                       │ - Work Orders    │   │ - sobject_create         │
                       │ - AI Troubleshoot│   │ - ai_pre_job_briefing    │
                       └────────┬─────────┘   └──────────┬───────────────┘
                                │                        │
                                └────────────┬───────────┘
                                             │
                                             ▼
                       ┌─────────────────────────────────────────────────┐
                       │        Salesforce Org / Agentforce AI           │
                       │          (REST API & Agentforce MCP)            │
                       └─────────────────────────────────────────────────┘
```

### 🔑 Server Capabilities:
1. **REST Endpoints (`/api/...`)**: Mobile authentication, work order management, status updates, and morning payload sync.
2. **MCP JSON-RPC 2.0 (`/mcp`)**: Context protocol for executing queries (`sobject_query`), creating records (`sobject_create`), generating AI Pre-Job Briefings (`ai_pre_job_briefing`), and generating AI Service Reports (`ai_service_report`).
3. **Mock Mode (`x-mock-mode: true`)**: Allows mobile developers to test **all 20+ endpoints** instantly with rich mock data without requiring active Salesforce org connectivity.

---

## 🌐 2. Three Hosting Options (Where & How to Host)

You can choose the hosting option that matches your current project stage:

### 🧪 Option 1: Local Development & Handover (Recommended for Now)
* **Cost**: $0 / Free
* **Setup Time**: 1 minute
* **Best For**: Mobile developers building UI, testing offline sync, and connecting emulators or real phones.
* **How it works**:
  1. Start backend server locally:
     ```powershell
     node scripts/mcp-server.js
     ```
  2. Expose local port via ngrok:
     ```powershell
     npx ngrok http 3000
     ```
  3. Mobile App connects to the ngrok URL (e.g. `https://xxxx.ngrok-free.app`).

---

### ☁️ Option 2: 24/7 Free Cloud Hosting via Render / Railway (Recommended for Staging/QA)
* **Cost**: $0 (Free Tier)
* **Setup Time**: 5 minutes
* **Best For**: Staging, QA testing, client demos where you need a permanent 24/7 server without keeping a local PC powered on.
* **How it works**:
  1. Create a free account on [Render.com](https://render.com) or [Railway.app](https://railway.app).
  2. Connect your GitHub repository: `kakarot4629-netizen/digiFields_360`.
  3. Set Build Command: `npm install`
  4. Set Start Command: `node scripts/mcp-server.js`
  5. Render automatically provides a permanent HTTPS URL:
     `https://digifield360-api.onrender.com`

---

### 🏛️ Option 3: Salesforce Native Hosted MCP Server (Production Enterprise)
* **Cost**: Included with Salesforce Org
* **Setup Time**: 15 minutes (Salesforce Admin configuration)
* **Best For**: Production deployment with zero custom backend infrastructure.
* **How it works**:
  1. In Salesforce Setup, enable **Salesforce Hosted MCP Server**.
  2. Configure Connected App (OAuth 2.0 + PKCE) for mobile login.
  3. Mobile App connects directly to:
     `https://[your-salesforce-domain].my.salesforce.com/services/mcp/v1`

---

## 📊 Hosting Option Comparison Matrix

| Option | Hosted On | Mandatory? | Monthly Cost | URL Permanence | Best Phase |
| --- | --- | --- | --- | --- | --- |
| **Option 1 (ngrok)** | Local PC + Tunnel | No | $0 | Session-based | Initial UI Dev & Demo |
| **Option 2 (Render/Railway)** | Render Cloud | No | $0 (Free Tier) | Permanent HTTPS | Staging & Mobile QA |
| **Option 3 (Salesforce Native)** | Salesforce Org | No | $0 (Existing Org) | Permanent HTTPS | Production |
| **Option 4 (AWS)** | AWS EC2 / App Runner | No | ~$5 - $20/mo | Permanent HTTPS | Enterprise Scale |

---

## 📱 Mobile App `.env` Configuration Reference

The mobile developer should configure their mobile application environment file (`.env`) depending on the active environment:

```env
# ── Local Development (Option 1) ──
# API_BASE_URL=https://xxxx.ngrok-free.app
# MCP_SERVER_URL=https://xxxx.ngrok-free.app/mcp

# ── Staging Server (Option 2) ──
# API_BASE_URL=https://digifield360-api.onrender.com
# MCP_SERVER_URL=https://digifield360-api.onrender.com/mcp

# ── Salesforce Production Native (Option 3) ──
# API_BASE_URL=https://your-org.my.salesforce.com
# MCP_SERVER_URL=https://your-org.my.salesforce.com/services/mcp/v1

# ── Mock Mode Header for Offline/Sandbox Testing ──
ENABLE_MOCK_MODE=true
```

---

## 🚀 Quick Verification Checklist for Mobile Developer

- [x] Postman Collection imported (`digiField360_Mobile_APIs.postman_collection.json`)
- [x] Server running on local port `3000` or cloud host URL
- [x] Test `GET /health` returns `{"status":"online","service":"digiField360 Mobile MCP API Server"}`
- [x] Test `POST /mcp` returns JSON-RPC response for tool queries
