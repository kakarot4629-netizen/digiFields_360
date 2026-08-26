# digiField360 Mobile Application Developer API Reference

Welcome to the **digiField360 Mobile Application Backend API Documentation**. This document is prepared specifically for mobile app developers (React Native / Flutter / Swift / Kotlin) integrating with the digiField360 backend gateway.

---

## 1. Environment & Base URL Configuration

| Environment               | Base URL                                                                 | Notes                            |
| ------------------------- | ------------------------------------------------------------------------ | -------------------------------- |
| **Local Development**     | `http://localhost:3000` (or `http://10.0.2.2:3000` for Android Emulator) | Zero-dependency Node server      |
| **Sandbox / Staging**     | `https://[your-sandbox-gateway].com`                                     | Connected to Salesforce Org      |
| **Salesforce Hosted MCP** | `https://[your-org].my.salesforce.com/services/mcp/v1`                   | Direct Salesforce cloud endpoint |

### Mobile `.env` Setup

```env
API_BASE_URL=http://10.0.2.2:3000
SF_MCP_SERVER_URL=http://10.0.2.2:3000/mcp
SF_OAUTH_CLIENT_ID=digiField360_Mobile
```

### Common Headers

```http
Content-Type: application/json
Authorization: Bearer <ACCESS_TOKEN>
x-instance-url: https://[yourorg].my.salesforce.com
x-mock-mode: true  (Optional: returns rich mock data for offline UI testing)
```

---

## 2. Authentication & Profile APIs

### 2.1 Login / Token Exchange

- **Method & Path**: `POST /api/auth/login`
- **Description**: Authenticate technician credentials or exchange OAuth PKCE authorization code.

#### Available Mock Accounts for Testing (Password: `Password123`):
| Email / Username | Technician Name | Skills |
| :--- | :--- | :--- |
| `vikram.sharma@digifield360.com` | Vikram Sharma | Generator, HVAC, Compressor, Electrical |
| `piyush.channe@digifield360.com` | Piyush Channe | Generator, HVAC, Compressor, Electrical |
| `ananya.roy@digifield360.com` | Ananya Roy | HVAC, Solar Inverter, Substation, PLCs |
| `rajesh.patel@digifield360.com` | Rajesh Patel | Turbine, Electrical, Hydraulics, Generator |
| `sarah.jenkins@digifield360.com` | Sarah Jenkins | Telematics, Robotics, HVAC, Compressor |

- **Request Body (JSON)**:
  ```json
  {
    "username": "vikram.sharma@digifield360.com",
    "password": "Password123"
  }
  ```

- **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "tokenType": "Bearer",
    "expiresIn": 7200,
    "instanceUrl": "https://orgfarm-4036b01401-dev-ed.develop.my.salesforce.com",
    "technician": {
      "id": "TECH-001",
      "name": "Vikram Sharma",
      "email": "vikram.sharma@digifield360.com",
      "skills": ["Generator", "HVAC", "Compressor", "Electrical"],
      "firstTimeFixRate": 92.5,
      "isActive": true,
      "preferredLanguage": "en"
    }
  }
  ```

- **Error Response (401 Unauthorized - Wrong Password or Invalid User)**:
  ```json
  {
    "success": false,
    "error": "Invalid username or password",
    "code": "INVALID_CREDENTIALS"
  }
  ```

### 2.2 Refresh Token

- **Method & Path**: `POST /api/auth/refresh`
- **Request Body**: `{ "refreshToken": "d8f93j20fj3..." }`
- **Response (200 OK)**: `{ "success": true, "accessToken": "new_token...", "expiresIn": 7200 }`

### 2.3 Get Technician Profile

- **Method & Path**: `GET /api/technician/profile`
- **Response (200 OK)**: Returns full technician profile, skill list, and fix rates.

### 2.4 Get Top Customer Accounts (e.g. Top 10 Accounts)

- **Method & Path**: `GET /api/accounts`
- **Query Params**: `?limit=10&industry=Technology` (Optional)
- **Description**: Fetch top customer accounts dynamically by size/revenue with optional industry filter.
- **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "count": 10,
    "accounts": [
      {
        "Id": "0010000001",
        "Name": "Serum BioTech Campus",
        "Industry": "Biotechnology",
        "Type": "Customer - Direct",
        "BillingCity": "Pune",
        "Phone": "+91 20 2690 0000",
        "AnnualRevenue": 85000000
      }
    ]
  }
  ```

### 2.5 Get Full Authenticated User Details & Work Orders

- **Method & Path**: `GET /api/user/details`
- **Headers**: `Authorization: Bearer <ACCESS_TOKEN>`
- **Description**: Automatically decodes user identity directly from the Bearer JWT Auth Token and returns full aggregated profile details, assigned work orders, equipment history, and top customer accounts in a single payload.
- **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "user": {
      "id": "TECH-001",
      "name": "Vikram Sharma",
      "email": "vikram.sharma@digifield360.com",
      "skills": ["Generator", "HVAC", "Compressor", "Electrical"],
      "firstTimeFixRate": 92.5
    },
    "workOrdersCount": 3,
    "workOrders": [ ... ],
    "equipmentHistory": [ ... ],
    "accounts": [ ... ],
    "aiPreJobBriefing": "ALERT for Vikram Sharma: Asset EQ-GEN-001 overheated..."
  }
  ```

### 2.6 Strict Authentication Error Handling (User Not Found)

- **Status Code**: `404 Not Found` (or `401 Unauthorized`)
- **Condition**: Sent when an invalid, missing, or unrecognized JWT Auth Token is supplied. The server strictly rejects unidentified requests without fallback to mock defaults.
- **Error Response**:
  ```json
  {
    "success": false,
    "error": "User not found for provided JWT auth token",
    "code": "USER_NOT_FOUND"
  }
  ```

---

## 3. Shift Sync & Work Order Lifecycle APIs

### 3.1 Morning Pre-Load Sync (Shift Start)

- **Method & Path**: `GET /api/sync/morning-payload`
- **Query Params**: `?technicianId=TECH-001`
- **Description**: Call this when the technician begins their shift or connects to WiFi. It downloads today's assigned jobs, equipment history, AI briefings, and knowledge articles to the mobile local SQLite store for offline use.
- **Response (200 OK)**:
  ```json
  {
    "success": true,
    "syncTimestamp": "2026-08-21T08:00:00.000Z",
    "technician": { "id": "TECH-001", "name": "Vikram Sharma" },
    "workOrders": [
      {
        "Id": "WO-001001",
        "Name": "WO-001001",
        "Subject__c": "Emergency Generator Overheating",
        "Description__c": "Backup generator overheating within 15 minutes.",
        "Status__c": "Assigned",
        "Priority__c": "Critical",
        "Equipment_Type__c": "Generator",
        "Equipment_ID__c": "EQ-GEN-9920",
        "Site_Address__c": "TechPark Sector 4, Hinjawadi Phase 2, Pune",
        "Scheduled_Date__c": "2026-08-21T10:00:00.000Z",
        "AccountName": "Serum BioTech Campus",
        "AI_Pre_Job_Briefing__c": "ALERT: Generator EQ-GEN-9920 overheated 3 weeks ago due to low coolant pressure. Required parts: Coolant Flush Kit, Temp Sensor TS-40."
      }
    ],
    "equipmentHistory": [
      {
        "Id": "JH-0091",
        "Equipment_ID__c": "EQ-GEN-9920",
        "Service_Date__c": "2026-07-28",
        "Technician_Name__c": "Vikram Sharma",
        "Resolution_Notes__c": "Cleaned radiator fins, topped up coolant reservoir.",
        "Parts_Replaced__c": "Coolant 5L"
      }
    ],
    "knowledgeArticles": [
      {
        "Id": "ka000000001",
        "Title": "Diesel Generator Overheating Diagnostics (E-402)",
        "Summary": "Step-by-step diagnostic guide for high temperature alarms.",
        "Steps": [
          "1. Check coolant reservoir level.",
          "2. Verify water pump belt tension.",
          "3. Test thermostat opening temperature."
        ]
      }
    ]
  }
  ```

### 3.2 List Work Orders

- **Method & Path**: `GET /api/work-orders`
- **Query Params**: `?status=Assigned` (Optional filter: `Assigned`, `In Progress`, `Completed`)
- **Response (200 OK)**: `{ "success": true, "count": 2, "workOrders": [...] }`

### 3.3 Get Work Order Details

- **Method & Path**: `GET /api/work-orders/:id`
- **Response (200 OK)**: Returns detailed work order object with recent equipment job history.

### 3.4 Update Work Order Status

- **Method & Path**: `PATCH /api/work-orders/:id/status`
- **Request Body**: `{ "status": "In Progress" }` (or `"On Site"`, `"Completed"`)
- **Response (200 OK)**:
  ```json
  {
    "success": true,
    "workOrderId": "WO-001001",
    "newStatus": "In Progress",
    "updatedAt": "2026-08-21T09:15:00.000Z"
  }
  ```

### 3.5 Log Time Worked

- **Method & Path**: `POST /api/work-orders/:id/time-log`
- **Request Body**:
  ```json
  {
    "hoursWorked": 1.5,
    "notes": "Diagnostic inspection and part replacement"
  }
  ```
- **Response (200 OK)**: `{ "success": true, "timeLoggedMinutes": 90 }`

### 3.6 Complete Work Order (With Notes, Parts, Customer Signature & Base64 Photos)

- **Method & Path**: `POST /api/work-orders/:id/complete`
- **Headers**: `Authorization: Bearer <ACCESS_TOKEN>`
- **Request Body**:
  ```json
  {
    "technicianNotes": "Replaced faulty temp sensor TS-40 and flushed coolant line. Ran load test at 90% capacity; temperature remained steady at 81C.",
    "partsUsed": "Temp Sensor TS-40 (1x), Coolant 5L",
    "timeLoggedMinutes": 90,
    "customerSignature": {
      "signerName": "Rajesh Kumar (Facility Manager)",
      "base64": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ..."
    },
    "photos": [
      {
        "fileName": "Pre_Service_Inspection.jpg",
        "base64": "data:image/jpeg;base64,/9j/4AAQSkZJRg...",
        "category": "Pre-Service Inspection"
      }
    ],
    "sendToCustomer": true
  }
  ```
- **Response (200 OK)**:
  ```json
  {
    "success": true,
    "workOrderId": "WO-001001",
    "status": "Completed",
    "serviceReport": "========================================\nFIELD360 SERVICE COMPLETION REPORT\n...",
    "signatureSaved": true,
    "signatureContentVersionId": "0680000000084920",
    "signatureContentDocumentId": "0690000000084920",
    "photosUploadedCount": 1,
    "photosContentVersionIds": ["0680000000572091"],
    "photosContentDocumentIds": ["0690000000572091"],
    "salesforceContentVersionCreated": true,
    "jobHistoryCreated": true
  }
  ```

### 3.7 Upload Digital Signature & Photo Attachment to Salesforce

- **Method & Path**: `POST /api/attachments/upload`
- **Headers**: `Authorization: Bearer <ACCESS_TOKEN>`
- **Description**: Dedicated endpoint for uploading customer digital signatures or site photos directly into Salesforce `ContentVersion` & `ContentDocumentLink` attached to a Work Order.
- **Request Body**:
  ```json
  {
    "workOrderId": "WO-001001",
    "attachmentType": "Signature",
    "fileName": "Customer_Signature_WO.png",
    "signerName": "Rajesh Kumar (Facility Manager)",
    "category": "Customer Approval",
    "base64Data": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB..."
  }
  ```
- **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "workOrderId": "WO-001001",
    "attachmentType": "Signature",
    "signerName": "Rajesh Kumar (Facility Manager)",
    "contentVersionId": "0680000000192840",
    "contentDocumentId": "0690000000192840",
    "fileName": "Customer_Signature_WO.png",
    "fileUrl": "https://[your-instance].salesforce.com/sfc/servlet.shepherd/version/download/0680000000192840",
    "uploadedAt": "2026-08-26T12:35:00.000Z"
  }
  ```

---

## 4. AI Services & Dynamic Query APIs

### 4.1 Dynamic Natural Language Query (NL2SOQL - Zero Hardcoding)

- **Method & Path**: `POST /api/ai/query`
- **Description**: The mobile application sends any natural language user question or voice transcript. The backend dynamically resolves the target Salesforce Object (`Account`, `Work_Order__c`, `Technician__c`, `Maintenance_Alert__c`, `Job_History__c`, `Contact`), constructs the SOQL query, executes it, and returns both structured data (for tables/cards) and an AI conversational summary (for chat bubbles).
- **Request Body**:
  ```json
  {
    "prompt": "Show me top 10 accounts by revenue in Pune",
    "maxRecords": 10
  }
  ```
- **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "prompt": "Show me top 10 accounts by revenue in Pune",
    "targetObject": "Account",
    "soqlGenerated": "SELECT Id, Name, Type, Industry, BillingCity, Phone, AnnualRevenue FROM Account WHERE BillingCity = 'Pune' ORDER BY AnnualRevenue DESC NULLS LAST LIMIT 10",
    "count": 3,
    "records": [
      {
        "Id": "0010000003",
        "Name": "Tata Motors Manufacturing Unit",
        "Industry": "Automotive",
        "BillingCity": "Pune",
        "AnnualRevenue": 450000000
      },
      {
        "Id": "0010000004",
        "Name": "Infosys Hinjawadi Campus",
        "Industry": "Technology",
        "BillingCity": "Pune",
        "AnnualRevenue": 300000000
      },
      {
        "Id": "0010000001",
        "Name": "Serum BioTech Campus",
        "Industry": "Biotechnology",
        "BillingCity": "Pune",
        "AnnualRevenue": 85000000
      }
    ],
    "aiSummary": "Found 3 accounts matching your request. Top results: Tata Motors Manufacturing Unit, Infosys Hinjawadi Campus, Serum BioTech Campus."
  }
  ```

### 4.2 Direct Dynamic SOQL Query Execution

- **Method & Path**: `POST /api/query/soql`
- **Description**: Allows the mobile app to execute any valid raw SOQL query dynamically.
- **Request Body**:
  ```json
  {
    "soql": "SELECT Id, Name, Subject__c, Priority__c FROM Work_Order__c WHERE Priority__c = 'Critical' LIMIT 5"
  }
  ```
- **Response (200 OK)**: `{ "success": true, "totalSize": 2, "done": true, "records": [...] }`

### 4.3 On-Site AI Troubleshooting Assistant

- **Method & Path**: `POST /api/ai/troubleshoot`
- **Description**: Searches knowledge articles and provides structured diagnostics with senior escalation flags.
- **Request Body**:
  ```json
  {
    "problemDescription": "generator temperature rising above 95C and smoking near exhaust manifold",
    "equipmentType": "Generator",
    "languageCode": "en"
  }
  ```
- **Response (200 OK)**:
  ```json
  {
    "success": true,
    "escalateToSenior": true,
    "escalationReason": "Safety hazard / critical component failure detected.",
    "diagnosisSteps": [
      "Step 1: Perform visual inspection of primary drive belt.",
      "Step 2: Measure thermal sensor resistance using multimeter.",
      "Step 3: Inspect coolant fluid level."
    ],
    "knowledgeArticles": [...]
  }
  ```

### 4.2 Generate Pre-Job Briefing

- **Method & Path**: `POST /api/ai/pre-job-briefing`
- **Request Body**: `{ "workOrderId": "WO-001001", "languageCode": "hi" }`
- **Response (200 OK)**: `{ "success": true, "briefing": "..." }`

---

## 5. Offline Queue Replay & GPS Telemetry

### 5.1 Replay Offline Mutations (Batch Sync)

- **Method & Path**: `POST /api/sync/offline-queue`
- **Description**: Replay an array of actions queued locally on mobile device while in low/no connectivity areas.
- **Request Body**:
  ```json
  {
    "technicianId": "TECH-001",
    "mutations": [
      {
        "queueId": "UUID-101",
        "action": "status_update",
        "sobjectName": "Work_Order__c",
        "recordId": "WO-001001",
        "fields": { "Status__c": "In Progress" },
        "queuedAt": "2026-08-21T08:30:00Z"
      },
      {
        "queueId": "UUID-102",
        "action": "complete",
        "sobjectName": "Work_Order__c",
        "recordId": "WO-001001",
        "fields": {
          "Status__c": "Completed",
          "Technician_Notes__c": "Fixed",
          "Time_Logged_Minutes__c": 60
        },
        "queuedAt": "2026-08-21T09:45:00Z"
      }
    ]
  }
  ```
- **Response (200 OK)**:
  ```json
  {
    "success": true,
    "totalProcessed": 2,
    "syncedCount": 2,
    "failedCount": 0,
    "results": [
      { "queueId": "UUID-101", "status": "synced", "error": null },
      { "queueId": "UUID-102", "status": "synced", "error": null }
    ]
  }
  ```

### 5.2 Technician GPS Location Update

- **Method & Path**: `POST /api/technician/location`
- **Request Body**:
  ```json
  {
    "technicianId": "TECH-001",
    "latitude": 18.52043,
    "longitude": 73.856743,
    "timestamp": "2026-08-21T10:15:00Z"
  }
  ```
- **Response (200 OK)**: `{ "success": true, "message": "GPS coordinates recorded." }`

---

## 6. MCP JSON-RPC 2.0 Protocol Endpoint

For clients communicating over standard MCP protocol, send JSON-RPC 2.0 requests to `POST /mcp`:

### Available MCP Tools:

1. `sobject_query`: `{ "soql": "SELECT Id, Subject__c FROM Work_Order__c" }`
2. `sobject_search`: `{ "searchTerm": "overheating" }`
3. `sobject_update`: `{ "sobjectName": "Work_Order__c", "recordId": "WO-001001", "fields": { "Status__c": "Completed" } }`
4. `sobject_create`: `{ "sobjectName": "Job_History__c", "fields": { ... } }`
5. `sobject_describe`: `{ "sobjectName": "Work_Order__c" }`
