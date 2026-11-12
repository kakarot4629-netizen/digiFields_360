# digiField360.ai — Mobile Developer Real-Time API & Salesforce Integration Plan

This document outlines the architecture, API contracts, and execution steps for integrating the **digiField360.ai Flutter / Mobile Application** with the live Salesforce Platform via the **Node.js API Gateway**.

---

## 🔑 Key Architectural Highlights

1. **Zero Hardcoded IDs (Dynamic Variable Chaining)**:
   - `POST /api/auth/login` automatically populates `{{authToken}}` and `{{technicianId}}`.
   - `GET /api/work-orders` or `GET /api/sync/morning-payload` dynamically sets `{{workOrderId}}`.
   - Creating records dynamically sets `{{recordId}}` and `{{accountId}}`.
   - Submitting parts requests dynamically sets `{{partsRequestId}}`.
   - Uploading photos/signatures dynamically sets `{{contentVersionId}}`.
2. **100% Real-Time Salesforce Data**:
   - Queries and updates live Salesforce objects: `Work_Order__c`, `Technician__c`, `Job_History__c`, `ContentVersion`, `ContentDocumentLink`.
3. **Public 24/7 Cloud Gateway**:
   - Base URL: `https://digifields-360.onrender.com` (connects from any physical phone, emulator, or computer over the internet).
4. **Offline-First & Replay Queue**:
   - Local SQLite database caches morning payloads and records mutations in `offline_sync_queue`.
   - Mutations replay atomically to `POST /api/sync/offline-queue` with idempotent `operationId`.

---

## 📱 24-Screen Implementation Matrix

```text
digiField360 Mobile Developer API Architecture (15 Modules)
├── 1. Authentication & Profile (Screens 01, 02, 23)
│   ├── 1.1 Health Check & API Discovery (GET /health)
│   ├── 1.2 Login & Token Exchange (POST /api/auth/login) [Saves {{authToken}}, {{technicianId}}]
│   ├── 1.3 Refresh Token (POST /api/auth/refresh)
│   ├── 1.4 Get Authenticated Profile (GET /api/technician/profile)
│   ├── 1.5 Get Full User Details & Shift Summary (GET /api/user/details)
│   └── 1.6 Register Device Push Token (POST /api/devices/register)
│
├── 2. Shift Morning Sync & Dashboard (Screens 03, 04)
│   ├── 2.1 Morning Pre-Load Sync (GET /api/sync/morning-payload?technicianId={{technicianId}})
│   ├── 2.2 Technician Dashboard Summary (GET /api/dashboard)
│   └── 2.3 Sync Engine Status (GET /api/sync/status)
│
├── 3. Jobs & Work Orders Lifecycle (Screens 05, 06, 07)
│   ├── 3.1 List Assigned Work Orders (GET /api/work-orders?status=Assigned) [Saves {{workOrderId}}]
│   ├── 3.2 Get Work Order Detail & History (GET /api/work-orders/{{workOrderId}})
│   ├── 3.3 Transition Status: En Route (PATCH /api/work-orders/{{workOrderId}}/status)
│   ├── 3.4 Transition Status: On Site (PATCH /api/work-orders/{{workOrderId}}/status)
│   ├── 3.5 Transition Status: In Progress (PATCH /api/work-orders/{{workOrderId}}/status)
│   └── 3.6 Transition Status: Parts Awaited (PATCH /api/work-orders/{{workOrderId}}/status)
│
├── 4. GPS Geofencing & Telemetry (Screens 08, 09)
│   ├── 4.1 GPS Check-In with Geofence Validation (POST /api/jobs/{{workOrderId}}/check-in)
│   ├── 4.2 Batch GPS Telemetry Tracking (POST /api/gps/batch)
│   └── 4.3 Update Real-Time Location (POST /api/technician/location)
│
├── 5. Activity Log & Labor Tracking (Screen 10)
│   ├── 5.1 Get Activities for Job (GET /api/jobs/{{workOrderId}}/activities)
│   ├── 5.2 Log Labor Time & Activity (POST /api/work-orders/{{workOrderId}}/time-log)
│   └── 5.3 Update Activity Entry (PUT /api/activities/{{activityId}})
│
├── 6. Photo Capture & Evidence (Screen 11)
│   └── 6.1 Upload Job Site Photo (POST /api/attachments/upload) [Creates ContentVersion & ContentDocumentLink]
│
├── 7. Parts Catalogue & Management (Screens 12, 13, 14, 15)
│   ├── 7.1 Search Parts Catalogue (GET /api/parts?query=compressor)
│   ├── 7.2 Get Part Details (GET /api/parts/{{partId}})
│   ├── 7.3 Submit Parts Request (POST /api/jobs/{{workOrderId}}/parts-requests) [Saves {{partsRequestId}}]
│   ├── 7.4 Get Parts Request Status (GET /api/jobs/{{workOrderId}}/parts-requests)
│   └── 7.5 Record Consumed Parts (POST /api/jobs/{{workOrderId}}/parts-used)
│
├── 8. Customer & Asset History (Screen 16)
│   ├── 8.1 Get Customer Details (GET /api/jobs/{{workOrderId}}/customer)
│   ├── 8.2 Get Asset Specs (GET /api/assets/{{assetId}})
│   └── 8.3 Get Equipment Past Service History (GET /api/assets/{{assetId}}/history)
│
├── 9. Checklist, Signature & Job Completion (Screens 17, 18, 19)
│   ├── 9.1 Get Job Checklist (GET /api/jobs/{{workOrderId}}/checklist)
│   ├── 9.2 Submit Completed Checklist (POST /api/jobs/{{workOrderId}}/checklist)
│   ├── 9.3 Upload Customer Digital Signature (POST /api/attachments/upload)
│   └── 9.4 Complete Work Order & Trigger AI Report (POST /api/work-orders/{{workOrderId}}/complete)
│
├── 10. GuruAI & Smart Troubleshooting (Screen 20)
│   ├── 10.1 GuruAI Diagnostic Chat (POST /api/ai/guru)
│   ├── 10.2 Generate AI Pre-Job Briefing (POST /api/ai/pre-job-briefing)
│   └── 10.3 Natural Language to SOQL Query (POST /api/ai/query)
│
├── 11. Technician Attendance (Screen 21)
│   ├── 11.1 Morning Punch-In with GPS (POST /api/attendance/check-in)
│   ├── 11.2 Evening Punch-Out (POST /api/attendance/check-out)
│   └── 11.3 Get Attendance Today & History (GET /api/attendance/today)
│
├── 12. Notifications & Alerts (Screen 22)
│   ├── 12.1 Get Active Notifications (GET /api/notifications)
│   └── 12.2 Mark Notification As Read (PATCH /api/notifications/{{notificationId}}/read)
│
├── 13. Offline Queue & Atomic Sync (Section 25-27)
│   └── 13.1 Replay Offline Mutation Queue (POST /api/sync/offline-queue)
│
├── 14. Live Salesforce SObject CRUD (Real-Time)
│   ├── 14.1 Query SObjects (GET /api/data/Work_Order__c)
│   ├── 14.2 Create Record (POST /api/data/Work_Order__c) [Saves {{recordId}}]
│   ├── 14.3 Get Record by ID (GET /api/data/Work_Order__c/{{recordId}})
│   ├── 14.4 Update Record (PATCH /api/data/Work_Order__c/{{recordId}})
│   ├── 14.5 Describe SObject Metadata (GET /api/schema/Work_Order__c)
│   └── 14.6 Direct SOQL Query (POST /api/data/query)
│
└── 15. Model Context Protocol (MCP) Tools (JSON-RPC 2.0)
    ├── 15.1 Discover Tools (tools/list)
    ├── 15.2 Call Tool: sobject_query
    └── 15.3 Call Tool: sobject_create
```

---

## 🚀 Postman Quick-Start Instructions

1. Open **Postman**.
2. Click **Import** and select:
   * `digiField360_Salesforce_Live_APIs.postman_collection.json`
   * `digiField360_Salesforce_Live.postman_environment.json`
3. Set active environment to **"digiField360 Live Cloud Environment"**.
4. Run `1. Authentication & Profile` > `1.2 Login`.
5. Execute requests sequentially or use **Run Collection** for full automated verification!
