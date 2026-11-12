# digiField360.ai — Mobile Developer Handover Package

Welcome! This package contains everything you need to build, test, and integrate the **digiField360.ai Mobile Application** (Flutter / React Native / iOS / Android / PWA) with the live Salesforce Platform via the **digiField360 API Gateway & MCP Server**.

---

## 📦 Package Contents

| File | Description |
| :--- | :--- |
| 📁 **`digiField360_Salesforce_Live_APIs.postman_collection.json`** | Comprehensive 15-module Postman Collection covering all 24 screens with automated variable chaining and tests. |
| 🌐 **`digiField360_Salesforce_Live.postman_environment.json`** | Postman Environment for 24/7 Cloud Staging (`https://digifields-360.onrender.com`). |
| 💻 **`digiField360_Local_Development.postman_environment.json`** | Postman Environment for Local Development (`http://localhost:3000` / `http://10.0.2.2:3000`). |
| 📖 **`MOBILE_DEVELOPER_API_DOCS.md`** | Comprehensive developer API reference with request/response samples, error codes, and sequence guide. |
| 📱 **`MOBILE_APP_SERVER_SPEC.md`** | Architecture specification, screen lists, offline SQLite strategy, and data models. |
| 🌐 **`MCP_SERVER_HOSTING_AND_ARCHITECTURE_SPEC.md`** | Hosting options (Local, Cloud, Salesforce Native) and JSON-RPC 2.0 MCP tool specifications. |
| 🛠️ **`OfflineMCPGateway.js`** | Helper library for client-side offline queueing, mutation replay, and SQLite sync. |

---

## 🚀 Quick Start Guide for Mobile Developers

### 1. Start the Local Backend Server (Optional if using Cloud)
```powershell
node scripts/mcp-server.js
```
*Base URLs:*
- **Local Dev (iOS Simulator & Web)**: `http://localhost:3000`
- **Local Dev (Android Emulator)**: `http://10.0.2.2:3000`
- **24/7 Cloud Staging (Live Salesforce)**: `https://digifields-360.onrender.com`

### 2. Verify with Automated Test Suite
```powershell
node scripts/test-mobile-apis.js
```
*Expected Result: 44 Passed, 0 Failed.*

### 3. Import & Execute with Postman
1. Open **Postman**.
2. Click **Import** (top-left button).
3. Select `digiField360_Salesforce_Live_APIs.postman_collection.json`.
4. Select `digiField360_Salesforce_Live.postman_environment.json` (or `digiField360_Local_Development.postman_environment.json`).
5. Set active environment to **"digiField360 Live Cloud Environment"** (or **"digiField360 Local Development"**).
6. Run **`1. Authentication & Profile` > `1.2 Login`** — this automatically captures `{{authToken}}` and `{{technicianId}}`.
7. You can now execute any request or run the entire collection via **Run Collection**!

---

## ⚡ Automated Variable Chaining (Zero Hardcoding)

| Action in Postman | Auto-Captured Variable | Purpose in Subsequent Requests |
| :--- | :--- | :--- |
| **1.2 Login** | `{{authToken}}`, `{{technicianId}}` | Injected into all `Authorization: Bearer` headers. |
| **2.1 Morning Sync / 3.1 List Jobs** | `{{workOrderId}}` | Used in all Job Detail, Status, GPS, Activity, Photo, Signature, and Complete calls. |
| **14.2 Create Record (Account/WO)** | `{{recordId}}`, `{{accountId}}` | Used in Single Record Read, Update, and Child Record queries. |
| **6.1 Upload Photo / 9.3 Signature** | `{{contentVersionId}}` | Verifies Salesforce `ContentVersion` creation. |
| **7.3 Submit Parts Request** | `{{partsRequestId}}` | Used to track depot dispatch status. |
| **5.2 Log Activity** | `{{activityId}}` | Used in Activity Update calls. |

---

## 📱 24-Screen Implementation Mapping

| Module | Screen # & Name | Primary API Endpoint |
| :--- | :--- | :--- |
| **Auth** | 01. Splash Screen | `GET /health`, `GET /api/sync/morning-payload` |
| **Auth** | 02. Login Screen | `POST /api/auth/login`, `POST /api/auth/refresh` |
| **Auth** | 03. Sync Status Screen | `GET /api/sync/status`, `POST /api/sync/offline-queue` |
| **Dashboard** | 04. Technician Home | `GET /api/dashboard`, `GET /api/work-orders?status=Assigned` |
| **Jobs** | 05. Today's Jobs | `GET /api/work-orders`, `GET /api/jobs/today` |
| **Jobs** | 06. Job Detail | `GET /api/work-orders/:id` |
| **Jobs** | 07. Job Status Lifecycle | `PATCH /api/work-orders/:id/status` (`En Route`, `On Site`, `In Progress`, `Parts Awaited`) |
| **GPS** | 08. GPS Check-In | `POST /api/jobs/:id/check-in` (Geofence distance calculation) |
| **GPS** | 09. GPS Tracking | `POST /api/gps/batch`, `POST /api/technician/location` |
| **Activities** | 10. Activity Log | `GET & POST /api/jobs/:id/activities`, `PUT /api/activities/:id` |
| **Photos** | 11. Photo Capture | `POST /api/attachments/upload` (Salesforce `ContentVersion`) |
| **Parts** | 12. Parts Catalogue | `GET /api/parts`, `GET /api/parts/search` |
| **Parts** | 13. Parts Request | `POST /api/jobs/:id/parts-requests` |
| **Parts** | 14. Request Detail | `GET /api/jobs/:id/parts-requests` |
| **Parts** | 15. Parts Used | `POST /api/jobs/:id/parts-used` |
| **Customer** | 16. Customer & Asset | `GET /api/jobs/:id/customer`, `GET /api/assets/:id/history` |
| **Safety** | 16.5 Safety Check | `GET /api/work-orders/:id/safety-check`, `POST /api/work-orders/:id/safety-check`, `POST /api/work-orders/:id/safety-escalation` |
| **Checklist** | 17. Dynamic Checklist | `GET /api/work-orders/:id/checklist`, `PATCH /api/work-orders/:id/checklist/:itemId`, `POST /api/work-orders/:id/checklist/submit`, `GET /api/checklist/templates` |
| **Completion**| 18. Customer Signature | `POST /api/attachments/upload` |
| **Completion**| 19. Job Completion | `POST /api/work-orders/:id/complete` (Updates `Work_Order__c`, inserts `Job_History__c`) |
| **GuruAI** | 20. GuruAI Chat | `POST /api/ai/guru`, `POST /api/ai/troubleshoot`, `POST /api/ai/query` |
| **Attendance**| 21. Attendance | `POST /api/attendance/check-in`, `POST /api/attendance/check-out`, `GET /api/attendance/today` |
| **Notifs** | 22. Notification Center | `GET /api/notifications`, `PATCH /api/notifications/:id/read`, `POST /api/devices/register` |
| **Profile** | 23. Technician Profile | `GET /api/technician/profile`, `GET /api/user/details` |
| **Settings** | 24. Settings | Multi-language, sync triggers, mock mode toggle |
