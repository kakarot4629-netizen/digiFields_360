# Salesforce Live MCP & REST API Integration Guide

> **Document Type**: Production Developer Specification & Integration Manual  
> **Target Audience**: Mobile Engineers (React Native / Flutter / iOS / Android), Salesforce Architects, Backend Integrators  
> **Backend Implementation**: `scripts/mcp-server.js`  
> **Salesforce API Version**: REST API v66.0 / v67.0 | Agentforce | Lightning Platform  
> **Version**: 2.0 (Live Production Specification)  

---

## 📋 Table of Contents

1. [Architectural Overview & Integration Topology](#1-architectural-overview--integration-topology)
2. [Authentication, Security & Token Lifecycle](#2-authentication-security--token-lifecycle)
3. [Generic Salesforce Live CRUD APIs](#3-generic-salesforce-live-crud-apis)
4. [digiField360 Domain Operations APIs](#4-digifield360-domain-operations-apis)
5. [Agentforce AI & Diagnostic Tools](#5-agentforce-ai--diagnostic-tools)
6. [Model Context Protocol (MCP) JSON-RPC 2.0 Specification](#6-model-context-protocol-mcp-json-rpc-20-specification)
7. [Real-Time Data Freshness & Event-Driven Push Strategy](#7-real-time-data-freshness--event-driven-push-strategy)
8. [Comprehensive Error Handling & Salesforce Status Codes](#8-comprehensive-error-handling--salesforce-status-codes)
9. [Project Directory & File Structure](#9-project-directory--file-structure)
10. [Mobile Developer Quick-Start & Handoff Checklist](#10-mobile-developer-quick-start--handoff-checklist)

---

## 1. Architectural Overview & Integration Topology

The **digiField360 MCP Server** serves as a secure, high-performance API gateway between client applications (mobile devices, web frontends, AI agents) and the live **Salesforce Lightning Platform**.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            MOBILE APPLICATION                               │
│                 (React Native / Flutter / Swift / Kotlin)                   │
│                                                                             │
│   ┌──────────────────────────┐             ┌─────────────────────────────┐  │
│   │   Mobile UI & Screens    │             │   Local SQLite / Encrypted  │  │
│   │  (Work Orders, AI Chat)  │             │   Mutation Queue (Offline)  │  │
│   └────────────┬─────────────┘             └──────────────┬──────────────┘  │
│                │                                          │                 │
│                └────────────────────┬─────────────────────┘                 │
│                                     │ HTTPS Requests                        │
│                                     ▼                                       │
│                       ┌───────────────────────────┐                         │
│                       │   OfflineMCPGateway.js    │                         │
│                       └─────────────┬─────────────┘                         │
└─────────────────────────────────────┼───────────────────────────────────────┘
                                      │ HTTPS (REST / JSON-RPC 2.0)
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                 digiField360 BACKEND GATEWAY & MCP SERVER                   │
│                        (scripts/mcp-server.js)                              │
│                                                                             │
│   ┌───────────────────────────────────┬─────────────────────────────────┐   │
│   │         REST API ROUTER           │     MCP JSON-RPC 2.0 ROUTER     │   │
│   │  - /api/auth/login                │  - sobject_query                │   │
│   │  - /api/data/:sobject (CRUD)      │  - sobject_get                  │   │
│   │  - /api/sync/morning-payload      │  - sobject_create               │   │
│   │  - /api/sync/offline-queue        │  - sobject_update               │   │
│   │  - /api/ai/troubleshoot           │  - sobject_delete               │   │
│   │  - /api/work-orders/:id/complete  │  - get_related_records          │   │
│   └─────────────────┬─────────────────┴────────────────┬────────────────┘   │
│                     │                                  │                    │
│                     └─────────────────┬────────────────┘                    │
│                                       ▼                                     │
│                     ┌───────────────────────────────────┐                   │
│                     │    Salesforce Token Manager &     │                   │
│                     │    Live Error Translation Layer   │                   │
│                     └─────────────────┬─────────────────┘                   │
└───────────────────────────────────────┼─────────────────────────────────────┘
                                        │ Salesforce REST API v67.0 / OAuth
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     SALESFORCE CLOUD / AGENTFORCE ORG                       │
│                                                                             │
│   ┌───────────────────────┐  ┌───────────────────────┐  ┌────────────────┐  │
│   │ Standard Objects      │  │ Custom F360 Objects   │  │ Agentforce AI  │  │
│   │ - Account             │  │ - Work_Order__c       │  │ - Prompt Tmpl  │  │
│   │ - Contact             │  │ - Technician__c       │  │ - Knowledge RAG│  │
│   │ - ContentVersion (PDF)│  │ - Job_History__c      │  │ - Apex Actions │  │
│   └───────────────────────┘  └───────────────────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Separation of Responsibilities

| Component | Primary Responsibility |
| :--- | :--- |
| **Mobile Application** | Presents UI, captures field data, queues offline mutations in SQLite, records GPS coordinates. |
| **OfflineMCPGateway.js** | Manages local caching, network state listener, mutation sequencing (FIFO), and automatic replay. |
| **MCP Server Gateway** | Authenticates users, signs JWTs, relays REST & MCP tool calls directly to Salesforce, handles OAuth tokens securely, translates errors. |
| **Salesforce Lightning Org** | Master database (System of Record), executes Validation Rules, Agentforce AI reasoning, and Invocable Apex workflows. |

---

## 2. Authentication, Security & Token Lifecycle

### 2.1 Security Architecture
1. **Zero Secret Exposure**: Mobile clients **never** store Salesforce Consumer Secrets or master credentials.
2. **JWT Bearer Token Relay**: Mobile apps authenticate against `/api/auth/login` and receive a signed JWT token (`HS256`, 2-hour TTL).
3. **Automatic Salesforce OAuth Refresh**: The gateway automatically refreshes its connection to Salesforce using refresh tokens or local CLI credentials without interrupting mobile client requests.

### 2.2 Auth Endpoints

#### `POST /api/auth/login`
Authenticates technician credentials or exchanges OAuth authorization codes.

* **Headers**: `Content-Type: application/json`
* **Request Body**:
  ```json
  {
    "username": "piyush.channe.3868c7575da5@agentforce.com",
    "password": "ImIronMan@3000"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "tokenType": "Bearer",
    "expiresIn": 7200,
    "instanceUrl": "https://orgfarm-4036b01401-dev-ed.develop.my.salesforce.com",
    "technician": {
      "id": "a02g500000Bvf9mAAB",
      "name": "Piyush Channe",
      "email": "piyush.channe.3868c7575da5@agentforce.com",
      "skills": ["Generator", "HVAC", "Compressor", "Electrical"],
      "firstTimeFixRate": 95.0,
      "isActive": true,
      "preferredLanguage": "en"
    }
  }
  ```
* **Error Response (401 Unauthorized)**:
  ```json
  {
    "success": false,
    "error": "Invalid username or password",
    "code": "INVALID_CREDENTIALS"
  }
  ```

#### `POST /api/auth/refresh`
* **Headers**: `Content-Type: application/json`
* **Request Body**: `{ "refreshToken": "eyJhbGci..." }`
* **Success Response (200 OK)**: `{ "success": true, "accessToken": "new_jwt...", "expiresIn": 7200 }`

---

## 3. Generic Salesforce Live CRUD APIs

These endpoints allow mobile developers to perform full CRUD operations on **any standard or custom Salesforce object** (`Account`, `Contact`, `Work_Order__c`, `Technician__c`, `Job_History__c`, etc.) in real-time.

### 3.1 List & Filter Records (`GET /api/data/:sobject`)

* **Method**: `GET`
* **Path**: `/api/data/:sobject` (e.g. `/api/data/Account` or `/api/data/Work_Order__c`)
* **Headers**: `Authorization: Bearer <TOKEN>`
* **Query Parameters**:
  * `fields` (string, optional): Comma-separated field list (Default: `Id, Name, CreatedDate`).
  * `where` (string, optional): SOQL filter condition (e.g. `Industry = 'Energy' AND BillingCity = 'Pune'`).
  * `orderBy` (string, optional): Sort clause (e.g. `AnnualRevenue DESC NULLS LAST`).
  * `limit` (integer, optional): Maximum records to return (Default: `20`, Max: `2000`).
  * `offset` (integer, optional): Pagination offset.
* **Example Request**:
  `GET /api/data/Account?fields=Id,Name,Industry,BillingCity,AnnualRevenue&limit=10&orderBy=AnnualRevenue DESC`
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "sobject": "Account",
    "soql": "SELECT Id, Name, Industry, BillingCity, AnnualRevenue FROM Account ORDER BY AnnualRevenue DESC LIMIT 10",
    "count": 10,
    "totalSize": 142,
    "records": [
      {
        "Id": "001g500000123ABC",
        "Name": "Serum BioTech Campus",
        "Industry": "Biotechnology",
        "BillingCity": "Pune",
        "AnnualRevenue": 85000000
      }
    ]
  }
  ```

---

### 3.2 Get Record by ID (`GET /api/data/:sobject/:id`)

* **Method**: `GET`
* **Path**: `/api/data/:sobject/:id` (e.g. `/api/data/Account/001g500000123ABC`)
* **Headers**: `Authorization: Bearer <TOKEN>`
* **Query Parameters**: `fields` (optional)
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "sobject": "Account",
    "id": "001g500000123ABC",
    "record": {
      "Id": "001g500000123ABC",
      "Name": "Serum BioTech Campus",
      "Industry": "Biotechnology",
      "BillingCity": "Pune",
      "Phone": "+91 20 2690 0000",
      "AnnualRevenue": 85000000,
      "CreatedDate": "2026-08-15T09:30:00.000+0000"
    }
  }
  ```
* **Error Response (404 Not Found)**:
  ```json
  {
    "success": false,
    "mode": "live_salesforce",
    "status": 404,
    "error": "The requested resource does not exist",
    "errorCode": "NOT_FOUND"
  }
  ```

---

### 3.3 Create New Record (`POST /api/data/:sobject`)

* **Method**: `POST`
* **Path**: `/api/data/:sobject` (e.g. `/api/data/Account` or `/api/data/Work_Order__c`)
* **Headers**: `Authorization: Bearer <TOKEN>`, `Content-Type: application/json`
* **Request Body**:
  ```json
  {
    "Name": "Apex Industrial Power Systems",
    "Industry": "Energy",
    "Type": "Customer - Direct",
    "BillingCity": "Pune",
    "BillingState": "Maharashtra",
    "Phone": "+91 20 2740 5500",
    "AnnualRevenue": 45000000
  }
  ```
* **Success Response (201 Created)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "sobject": "Account",
    "id": "001g500000987XYZ",
    "createdAt": "2026-08-27T10:35:00.000Z",
    "message": "Record created successfully in Account."
  }
  ```
* **Validation Error Response (400 Bad Request)**:
  ```json
  {
    "success": false,
    "mode": "live_salesforce",
    "status": 400,
    "error": "Required fields are missing: [Name]",
    "errorCode": "REQUIRED_FIELD_MISSING",
    "fields": ["Name"]
  }
  ```

---

### 3.4 Update Record (`PATCH /api/data/:sobject/:id`)

* **Method**: `PATCH`
* **Path**: `/api/data/:sobject/:id`
* **Headers**: `Authorization: Bearer <TOKEN>`, `Content-Type: application/json`
* **Request Body**:
  ```json
  {
    "Phone": "+91 20 2740 9999",
    "AnnualRevenue": 52000000
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "sobject": "Account",
    "id": "001g500000987XYZ",
    "updatedFields": ["Phone", "AnnualRevenue"],
    "updatedAt": "2026-08-27T10:36:00.000Z",
    "message": "Record 001g500000987XYZ in Account updated successfully in Salesforce."
  }
  ```

---

### 3.5 Delete Record (`DELETE /api/data/:sobject/:id`)

* **Method**: `DELETE`
* **Path**: `/api/data/:sobject/:id`
* **Headers**: `Authorization: Bearer <TOKEN>`
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "sobject": "Account",
    "id": "001g500000987XYZ",
    "deletedAt": "2026-08-27T10:37:00.000Z",
    "message": "Record 001g500000987XYZ in Account deleted successfully from Salesforce."
  }
  ```

---

### 3.6 Get Child Related Records (`GET /api/data/:sobject/:id/:relationship`)

* **Method**: `GET`
* **Path**: `/api/data/:sobject/:id/:relationship` (e.g. `/api/data/Account/001g500000123ABC/Contacts`)
* **Headers**: `Authorization: Bearer <TOKEN>`
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "sobject": "Account",
    "recordId": "001g500000123ABC",
    "relationship": "Contacts",
    "totalSize": 2,
    "records": [
      {
        "Id": "003g500000111XYZ",
        "Name": "Dr. Rajesh Mehta",
        "Title": "Facility Director",
        "Email": "rajesh.mehta@serumbio.com",
        "Phone": "+91 98220 12345"
      }
    ]
  }
  ```

---

### 3.7 Direct SOQL Query (`POST /api/data/query`)

* **Method**: `POST`
* **Path**: `/api/data/query`
* **Request Body**:
  ```json
  {
    "soql": "SELECT Id, Name, Status__c, Priority__c, Equipment_Type__c, Equipment_ID__c, Site_Address__c FROM Work_Order__c WHERE Status__c IN ('Assigned', 'In Progress') ORDER BY Priority__c ASC LIMIT 10"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "totalSize": 3,
    "done": true,
    "records": [ ... ]
  }
  ```

---

### 3.8 Direct SOSL Search (`POST /api/data/search`)

* **Method**: `POST`
* **Path**: `/api/data/search`
* **Request Body**:
  ```json
  {
    "searchTerm": "Generator"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "searchRecords": [ ... ]
  }
  ```

---

## 4. digiField360 Domain Operations APIs

### 4.1 Morning Pre-Load Sync (`GET /api/sync/morning-payload`)
Downloads today's entire operational context for offline caching in local SQLite.

* **Path**: `GET /api/sync/morning-payload?technicianId=a02g500000Bvf9mAAB`
* **Response (200 OK)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "syncTimestamp": "2026-08-27T08:00:00.000Z",
    "technician": { "Id": "a02...", "Name": "Piyush Channe" },
    "workOrders": [ ... ],
    "equipmentHistory": [ ... ],
    "knowledgeArticles": [ ... ]
  }
  ```

### 4.2 Complete Work Order & Generate AI Report (`POST /api/work-orders/:id/complete`)
Marks a work order completed, uploads customer signatures and on-site photos as `ContentVersion` attachments, creates `Job_History__c` audit logs, and formats an AI service completion report.

* **Path**: `POST /api/work-orders/:id/complete`
* **Request Body**:
  ```json
  {
    "technicianNotes": "Replaced faulty 45MFD capacitor and calibrated generator speed.",
    "partsUsed": "Capacitor 45MFD (1x), Coolant 5L",
    "timeLoggedMinutes": 90,
    "signerName": "Rajesh Nair",
    "sendToCustomer": true,
    "customerSignature": {
      "signerName": "Rajesh Nair",
      "base64": "iVBORw0KGgoAAAANSUhEUgAA..."
    },
    "photos": [
      {
        "fileName": "repaired_motor.jpg",
        "base64": "/9j/4AAQSkZJRgABAQEASABIAAD..."
      }
    ]
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "workOrderId": "a03g500000WO101",
    "status": "Completed",
    "completedAt": "2026-08-27T11:45:00.000Z",
    "serviceReport": "FIELD360 SERVICE COMPLETION REPORT\nWork Order: WO-001001...",
    "signatureSaved": true,
    "signatureContentVersionId": "068g500000SIG123",
    "photosUploadedCount": 1,
    "photosContentVersionIds": ["068g500000PHT456"],
    "salesforceContentVersionCreated": true,
    "jobHistoryCreated": true
  }
  ```

### 4.3 Replay Offline Queue (`POST /api/sync/offline-queue`)
Replays an array of mutations collected during offline operation atomically.

* **Path**: `POST /api/sync/offline-queue`
* **Request Body**:
  ```json
  {
    "technicianId": "a02g500000Bvf9mAAB",
    "mutations": [
      {
        "queueId": "UUID-5501",
        "action": "update_status",
        "sobjectName": "Work_Order__c",
        "recordId": "a03g500000WO101",
        "fields": { "Status__c": "In Progress" },
        "queuedAt": "2026-08-27T08:30:00Z"
      },
      {
        "queueId": "UUID-5502",
        "action": "log_time",
        "sobjectName": "Work_Order__c",
        "recordId": "a03g500000WO101",
        "fields": { "Time_Logged_Minutes__c": 90 },
        "queuedAt": "2026-08-27T10:00:00Z"
      }
    ]
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "totalProcessed": 2,
    "syncedCount": 2,
    "failedCount": 0,
    "results": [
      { "queueId": "UUID-5501", "status": "synced", "syncedAt": "2026-08-27T10:38:00.000Z" },
      { "queueId": "UUID-5502", "status": "synced", "syncedAt": "2026-08-27T10:38:01.000Z" }
    ]
  }
  ```

---

## 5. Agentforce AI & Diagnostic Tools

### 5.1 On-Site AI Troubleshooting Assistant (`POST /api/ai/troubleshoot`)
* **Request Body**:
  ```json
  {
    "problemDescription": "Generator starts but stalls after 30 seconds with thermal alarm E-402",
    "equipmentType": "Generator",
    "equipmentId": "EQ-GEN-9920",
    "languageCode": "en"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "mode": "live_salesforce",
    "equipmentType": "Generator",
    "escalateToSenior": false,
    "diagnosisSteps": [
      "Step 1: Isolate main power to Generator (EQ-GEN-9920) and verify electrical isolation with multimeter.",
      "Step 2: Inspect primary cooling fan / radiator fins for blockage.",
      "Step 3: Test sensor resistance and check telemetry log for code anomalies related to thermal alarms.",
      "Step 4: Replace faulty components, clear error codes, and execute a 15-minute load test."
    ],
    "recommendedParts": ["Coolant Flush Kit", "Temp Sensor TS-40"]
  }
  ```

---

## 6. Model Context Protocol (MCP) JSON-RPC 2.0 Specification

Clients and Agentforce AI assistants can execute tools via `POST /mcp` using the standard JSON-RPC 2.0 protocol.

### 6.1 Discover Available Tools (`tools/list`)
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list"
}
```

### 6.2 Tool Call: `sobject_query`
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "sobject_query",
    "arguments": {
      "soql": "SELECT Id, Name, Status__c, Priority__c FROM Work_Order__c LIMIT 5"
    }
  }
}
```

### 6.3 Tool Call: `sobject_create`
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "sobject_create",
    "arguments": {
      "sobjectName": "Account",
      "fields": {
        "Name": "Solaris Renewable Energy Grid",
        "Industry": "Energy",
        "BillingCity": "Bengaluru"
      }
    }
  }
}
```

### 6.4 Tool Call: `sobject_delete`
```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "tools/call",
  "params": {
    "name": "sobject_delete",
    "arguments": {
      "sobjectName": "Account",
      "recordId": "001g500000987XYZ"
    }
  }
}
```

---

## 7. Real-Time Data Freshness & Event-Driven Push Strategy

### 7.1 Pull-Based Data Freshness (Default)
By default, every API call directly queries the connected Salesforce instance in real-time, guaranteeing that the mobile app always receives the latest record state.

### 7.2 Push-Based Real-Time Streaming Architecture (Future Extensibility)
When instant push notifications or bidirectional synchronization without polling are required:

```
┌─────────────────────────┐         Change Data Capture (CDC)         ┌─────────────────────────┐
│     Salesforce Org      │ ─────────────────────────────────────────► │  digiField360 Gateway   │
│  (Record Created/Edit)  │       /data/Work_Order__ChangeEvent       │   (WebSocket / SSE)     │
└─────────────────────────┘                                            └────────────┬────────────┘
                                                                                    │ Push Update
                                                                                    ▼
                                                                       ┌─────────────────────────┐
                                                                       │       Mobile App        │
                                                                       │ (Instant Cache Refresh) │
                                                                       └─────────────────────────┘
```

1. **Change Data Capture (CDC)**: Subscribe to `/data/Work_Order__ChangeEvent` via Salesforce Pub/Sub API or CometD.
2. **WebSocket / SSE Gateway**: When Salesforce publishes a change event, the MCP Gateway broadcasts the mutation payload over WebSockets to connected mobile clients.
3. **Delta Sync**: Mobile client updates only the affected record in its local SQLite database.

---

## 8. Comprehensive Error Handling & Salesforce Status Codes

The gateway automatically standardizes Salesforce REST errors into clean, actionable JSON payloads:

| HTTP Status | Error Code (`errorCode`) | Trigger Condition | Recommended Mobile App Action |
| :--- | :--- | :--- | :--- |
| **400 Bad Request** | `REQUIRED_FIELD_MISSING` | Mandatory field not supplied in request body. | Highlight missing form input fields for the user. |
| **400 Bad Request** | `INVALID_FIELD` | Field API name does not exist on SObject. | Check SObject schema via `/api/schema/:sobject`. |
| **400 Bad Request** | `FIELD_CUSTOM_VALIDATION_EXCEPTION` | Salesforce Validation Rule triggered. | Display the validation message banner to technician. |
| **401 Unauthorized** | `INVALID_CREDENTIALS` / `INVALID_TOKEN` | Bad password or expired JWT Bearer token. | Prompt user to log in or trigger `/api/auth/refresh`. |
| **403 Forbidden** | `INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY` | User profile lacks permission on target record. | Show "Access Restricted by Admin" notice. |
| **404 Not Found** | `NOT_FOUND` | Record ID does not exist in Salesforce. | Remove stale record from local SQLite cache. |
| **409 Conflict** | `DUPLICATE_VALUE` / `DUPLICATES_DETECTED` | Salesforce Duplicate Rule detected match. | Ask user to link to existing duplicate record. |
| **429 Too Many Req**| `REQUEST_LIMIT_EXCEEDED` | Salesforce daily API limit threshold reached. | Queue mutations locally in SQLite for retry. |
| **500 Server Error**| `SALESFORCE_ERROR` | Apex exception or network failure. | Log error telemetry; fallback to offline cache. |

---

## 9. Project Directory & File Structure

```
digiFields_360/
├── scripts/
│   ├── mcp-server.js              # Core Node.js HTTP & JSON-RPC 2.0 MCP Server Gateway
│   ├── test-mobile-apis.js        # 36-test automated verification suite
│   ├── deploy.ps1                 # Salesforce CLI deployment automation script
│   └── mcp-stdio.js               # CLI stdio connector for desktop AI assistants
├── mobile-developer-package/
│   ├── digiField360_Salesforce_Live_APIs.postman_collection.json # Ready-to-import collection
│   ├── digiField360_Salesforce_Live.postman_environment.json   # Live environment config
│   ├── OfflineMCPGateway.js       # Client-side SQLite & mutation replay helper
│   ├── SALESFORCE_MCP_API_INTEGRATION_GUIDE.md # This guide
│   └── README.md                  # Mobile developer handover quickstart
├── docs/
│   ├── DIGIFIELD360_MASTER_PLAN_AND_MCP_SPECIFICATION.md # Master requirements specification
│   ├── digiField360_Salesforce_Live_APIs.postman_collection.json
│   └── digiField360_Salesforce_Live.postman_environment.json
├── force-app/main/default/        # Salesforce Metadata (Objects, Apex, Prompt Templates, LWC)
│   ├── classes/                   # Invocable Actions (SmartAssignment, Troubleshooting, etc.)
│   ├── objects/                   # Custom Objects (Work_Order__c, Technician__c, etc.)
│   └── genAiPromptTemplates/      # Einstein LLM Generative AI Prompt Templates
├── package.json
└── render.yaml                    # 1-click cloud deployment config for Render.com
```

---

## 10. Mobile Developer Quick-Start & Handoff Checklist

### Step 1: Start the Backend Server Locally
```powershell
node scripts/mcp-server.js
```

### Step 2: Run Automated API Verification
```powershell
node scripts/test-mobile-apis.js
```
*Expected Result: 36 Passed, 0 Failed.*

### Step 3: Import into Postman
1. Open **Postman**.
2. Click **Import** (top left).
3. Select `mobile-developer-package/digiField360_Salesforce_Live_APIs.postman_collection.json`.
4. Select `mobile-developer-package/digiField360_Salesforce_Live.postman_environment.json`.
5. Select active environment: **"digiField360 Live Environment"**.

### Step 4: Verify Live Salesforce Sync Sequence
1. Run **1. Authentication > 1.2 Login** (Stores `{{authToken}}` automatically).
2. Run **2. Generic Salesforce Live CRUD > 2.2 Create New Record** (Creates Account and stores `{{recordId}}`).
3. Open Salesforce Setup in browser and verify the record is live in Salesforce.
4. Run **2. Generic Salesforce Live CRUD > 2.4 Update Record** (Updates Phone & Revenue).
5. Verify update is reflected immediately in Salesforce.
6. Run **2. Generic Salesforce Live CRUD > 2.9 Delete Record** (Deletes record permanently).
7. Verify deletion in Salesforce Recycle Bin.
