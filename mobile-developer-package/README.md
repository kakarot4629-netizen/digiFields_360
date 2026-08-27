# digiField360 Mobile Developer Handover Package

Welcome! This package contains everything you need to build and integrate the **digiField360 Mobile Application** (React Native / Flutter / iOS / Android / PWA) with the live Salesforce Platform via the **digiField360 MCP & REST API Gateway**.

---

## 📦 Package Contents

| File | Description |
| :--- | :--- |
| 📁 **`digiField360_Salesforce_Live_APIs.postman_collection.json`** | Ready-to-import Postman Collection with generic CRUD, domain APIs, AI diagnostics, and MCP tools with test scripts. |
| 🌐 **`digiField360_Salesforce_Live.postman_environment.json`** | Postman Environment pre-configured with `baseUrl`, `instanceUrl`, `username`, `password`, and dynamic variable chaining. |
| 📖 **`SALESFORCE_MCP_API_INTEGRATION_GUIDE.md`** | Comprehensive production integration guide, authentication details, full endpoint specifications, and error handling dictionary. |
| 📱 **`MOBILE_APP_SERVER_SPEC.md`** | Full functional specifications, screen architecture, offline queue strategy, and data flows. |
| 🌐 **`MCP_SERVER_HOSTING_AND_ARCHITECTURE_SPEC.md`** | Full architectural details, server execution, and hosting options (Local + ngrok, Render.com 24/7, Salesforce Native). |
| 🛠️ **`OfflineMCPGateway.js`** | Ready-to-use JavaScript/TypeScript client gateway helper for offline caching, queueing, and sync. |

---

## 🚀 Quick Start Guide

### 1. Start the Backend Gateway Locally
```powershell
node scripts/mcp-server.js
```
*Base URLs:*
- **Local Dev (iOS Simulator & Web)**: `http://localhost:3000`
- **Local Dev (Android Emulator)**: `http://10.0.2.2:3000`
- **24/7 Cloud Staging (Primary)**: `https://digifields-360.onrender.com`

### 2. Verify with Automated Test Suite
```powershell
node scripts/test-mobile-apis.js
```
*Expected Result: 36 Passed, 0 Failed.*

### 3. Testing with Postman
1. Open **Postman**.
2. Click **Import** (top left).
3. Select `digiField360_Salesforce_Live_APIs.postman_collection.json`.
4. Select `digiField360_Salesforce_Live.postman_environment.json`.
5. Set the active environment to **"digiField360 Live Environment"**.
6. Run `1. Authentication & Profile` > `1.2 Login` to authenticate.

---

## 💡 Key Mobile Integration Workflows

1. **Live Salesforce CRUD**: Query records with `GET /api/data/:sobject`, retrieve by ID with `GET /api/data/:sobject/:id`, insert with `POST /api/data/:sobject`, update with `PATCH /api/data/:sobject/:id`, delete with `DELETE /api/data/:sobject/:id`.
2. **Morning Pre-Load Cache**: Call `GET /api/sync/morning-payload?technicianId={{technicianId}}` at shift start to populate local SQLite.
3. **On-Site AI Troubleshooting**: Call `POST /api/ai/troubleshoot` with symptoms to get step-by-step diagnostic checklists from Salesforce Knowledge.
4. **Job Completion & Service Report**: Call `POST /api/work-orders/:id/complete` with technician notes, parts used, signatures, and photos to automatically create `ContentVersion` attachments and generate the AI completion report.
5. **Offline Queue Sync**: Queue changes locally in SQLite when offline and replay them atomically via `POST /api/sync/offline-queue` when connectivity is restored.
