# digiField360 Mobile Developer Handover Package

Welcome! This package contains everything you need to build and integrate the **digiField360 Mobile Application** (React Native / Flutter / iOS / Android / PWA) with the backend API gateway and Salesforce Agentforce.

---

## 📦 Package Contents

| File                                                      | Description                                                                                       |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| 📁 **`digiField360_Mobile_APIs.postman_collection.json`** | Ready-to-import Postman Collection with all 20+ endpoints organized with sample payloads.         |
| 📖 **`MOBILE_DEVELOPER_API_DOCS.md`**                     | Comprehensive API reference documentation with request/response schemas and HTTP status codes.    |
| 📱 **`MOBILE_APP_SERVER_SPEC.md`**                        | Full functional specifications, screen architecture, offline queue strategy, and data flows.      |
| 🌐 **`MCP_SERVER_HOSTING_AND_ARCHITECTURE_SPEC.md`**      | Full architectural answer to AWS requirement, server execution details, and 3 hosting options.    |
| 🛠️ **`OfflineMCPGateway.js`**                             | Ready-to-use JavaScript/TypeScript client gateway helper for offline caching, queueing, and sync. |

---

## 🚀 Quick Start Guide

### 1. Backend Server Base URL

- **24/7 Live Cloud API Server (Primary)**: `https://digifields-360.onrender.com`
- **Local Dev (iOS Simulator & Web)**: `http://localhost:3000`
- **Local Dev (Android Emulator)**: `http://10.0.2.2:3000`

### 2. Testing with Postman

1. Open **Postman**.
2. Click **Import** (top left).
3. Select `digiField360_Mobile_APIs.postman_collection.json`.
4. Run `1.1 GET Health & API Discovery` to confirm connectivity.

### 3. Immediate UI Development (Mock Mode)

You do **NOT** need active Salesforce credentials to start developing the mobile UI.

- Pass header `x-mock-mode: true` (or query param `?mock=true`) with any request.
- The server will return instant, rich mock data for all work orders, equipment history, AI troubleshooting, and offline sync.

### 4. Key Mobile Screen Workflows

1. **Shift Start / Morning Sync**: Call `GET /api/sync/morning-payload?technicianId=TECH-001` to pre-load today's assigned jobs into local SQLite.
2. **On-Site AI Troubleshooting**: Call `POST /api/ai/troubleshoot` with symptoms to get diagnostic steps.
3. **Job Completion & AI Report**: Call `POST /api/work-orders/:id/complete` with notes, parts used, and base64 photos to mark completed and generate the service report.
4. **Offline Queue Sync**: If working in a basement without internet, store mutations locally and replay them via `POST /api/sync/offline-queue` once reconnected.

---

## 📞 Support & Contacts

If you have questions about schema fields, custom objects, or need sample test records, reach out to the Salesforce digiField360 implementation team.
