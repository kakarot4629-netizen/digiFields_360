/**
 * Automated Verification Suite for digiField360 Mobile Backend REST & MCP APIs
 */
const { spawn } = require("child_process");

const PORT = 3888; // Use test port 3888 to avoid conflicting with running instances
const BASE_URL = `http://localhost:${PORT}`;

async function runApiTests() {
  console.log("🚀 Starting digiField360 Mobile API Test Suite...\n");

  // Spawn server on test port 3001
  const serverProcess = spawn("node", ["scripts/mcp-server.js"], {
    env: { ...process.env, PORT: PORT },
    stdio: "inherit"
  });

  // Give server 1.5s to start
  await new Promise((r) => setTimeout(r, 1500));

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`✅ [PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`❌ [FAIL] ${name}:`, err.message);
      failed++;
    }
  }

  // 1. Health & Discovery
  await test("GET /health returns online status and endpoint list", async () => {
    const res = await fetch(`${BASE_URL}/health`);
    const data = await res.json();
    if (!res.ok || data.status !== "online" || !data.endpoints) {
      throw new Error(`Expected online status, got: ${JSON.stringify(data)}`);
    }
  });

  // 2. Auth Login - Positive & Negative
  await test("POST /api/auth/login with valid credentials returns 200 OK + token", async () => {
    const res = await fetch(`${BASE_URL}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        username: "piyush.channe.3868c7575da5@agentforce.com",
        password: "YOUR_PASSWORD_HERE"
      })
    });
    const data = await res.json();
    if (res.status !== 200 || !data.success || !data.token || !data.technician?.skills) {
      throw new Error(`Invalid login response: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/auth/login with wrong password returns 401 Unauthorized", async () => {
    const res = await fetch(`${BASE_URL}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        username: "piyush.channe@digifield360.com",
        password: "WRONG_PASSWORD_999"
      })
    });
    const data = await res.json();
    if (res.status !== 401 || data.success !== false || data.code !== "INVALID_CREDENTIALS") {
      throw new Error(`Expected 401 INVALID_CREDENTIALS, got: status=${res.status} body=${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/auth/login with unknown username returns 401 Unauthorized", async () => {
    const res = await fetch(`${BASE_URL}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        username: "fake_user_not_exist@example.com",
        password: "Password123"
      })
    });
    const data = await res.json();
    if (res.status !== 401 || data.success !== false || data.code !== "INVALID_CREDENTIALS") {
      throw new Error(`Expected 401 INVALID_CREDENTIALS, got: status=${res.status} body=${JSON.stringify(data)}`);
    }
  });

  // 3. Technician Profile
  await test("GET /api/technician/profile returns profile data", async () => {
    const res = await fetch(`${BASE_URL}/api/technician/profile`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!data.success || data.technician.id !== "TECH-001") {
      throw new Error(`Invalid profile: ${JSON.stringify(data)}`);
    }
  });

  // 3.1 Top Customer Accounts (Top 10)
  await test("GET /api/accounts?limit=10 returns top 10 accounts", async () => {
    const res = await fetch(`${BASE_URL}/api/accounts?limit=10`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!data.success || data.count !== 10 || data.accounts.length !== 10) {
      throw new Error(`Expected 10 accounts, got: ${JSON.stringify(data)}`);
    }
  });

  // 4. Morning Pre-load Sync
  await test("GET /api/sync/morning-payload returns complete offline dataset", async () => {
    const res = await fetch(
      `${BASE_URL}/api/sync/morning-payload?technicianId=TECH-001`,
      {
        headers: { "x-mock-mode": "true" }
      }
    );
    const data = await res.json();
    if (
      !data.success ||
      !Array.isArray(data.workOrders) ||
      !Array.isArray(data.equipmentHistory) ||
      !Array.isArray(data.knowledgeArticles)
    ) {
      throw new Error(`Incomplete morning payload: ${JSON.stringify(data)}`);
    }
  });

  // 5. Work Orders List
  await test("GET /api/work-orders returns work orders list", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!data.success || data.count < 1) {
      throw new Error(`No work orders returned`);
    }
  });

  // 6. Work Order Details
  await test("GET /api/work-orders/:id returns work order and equipment history", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (
      !data.success ||
      data.workOrder.Id !== "WO-001001" ||
      !data.workOrder.caseNumber ||
      !Array.isArray(data.workOrder.workOrderLineItems)
    ) {
      throw new Error(`Invalid WO details: ${JSON.stringify(data)}`);
    }
  });

  // 6.1 Multi-Asset Work Order Line Items (WOLIs)
  await test("GET /api/work-orders/:id/line-items returns multi-asset line items", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/line-items`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!data.success || !Array.isArray(data.lineItems) || data.count < 1) {
      throw new Error(`Expected line items array, got: ${JSON.stringify(data)}`);
    }
  });

  // 6.2 Update Line Item Status
  await test("PATCH /api/line-items/:id updates equipment task status and resolution", async () => {
    const res = await fetch(`${BASE_URL}/api/line-items/WOLI-00101`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        status: "Completed",
        isFirstTimeFix: true,
        resolutionNotes: "Diagnostic inspection verified pass."
      })
    });
    const data = await res.json();
    if (!data.success || data.lineItemId !== "WOLI-00101") {
      throw new Error(`Failed to update line item: ${JSON.stringify(data)}`);
    }
  });

  // 6.3 Work Order Service Appointments
  await test("GET /api/work-orders/:id/service-appointments returns child service appointments", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/service-appointments`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!data.success || !Array.isArray(data.serviceAppointments) || data.count < 1) {
      throw new Error(`Expected service appointments array, got: ${JSON.stringify(data)}`);
    }
  });

  // 6.4 Service Appointments List & Filter
  await test("GET /api/service-appointments returns appointment list with filters", async () => {
    const res = await fetch(`${BASE_URL}/api/service-appointments?workOrderId=WO-001001`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!data.success || !Array.isArray(data.serviceAppointments) || data.count < 1) {
      throw new Error(`Expected filtered service appointments, got: ${JSON.stringify(data)}`);
    }
  });

  // 6.5 Service Appointment Detail
  await test("GET /api/service-appointments/:id returns appointment detail", async () => {
    const res = await fetch(`${BASE_URL}/api/service-appointments/SA-001001`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!data.success || !data.serviceAppointment || !data.serviceAppointment.workOrderId) {
      throw new Error(`Expected appointment details, got: ${JSON.stringify(data)}`);
    }
  });

  // 6.6 Create Service Appointment
  await test("POST /api/service-appointments creates new appointment record", async () => {
    const res = await fetch(`${BASE_URL}/api/service-appointments`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        workOrderId: "WO-001001",
        jobType: "Preventive Maintenance",
        priority: "High",
        notes: "Scheduled field maintenance visit"
      })
    });
    const data = await res.json();
    if (res.status !== 201 || !data.success || !data.serviceAppointmentId) {
      throw new Error(`Failed to create service appointment: ${JSON.stringify(data)}`);
    }
  });

  // 6.7 Update Service Appointment Status
  await test("PATCH /api/service-appointments/:id updates appointment status", async () => {
    const res = await fetch(`${BASE_URL}/api/service-appointments/SA-001001`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        status: "In Progress",
        notes: "Technician arrived on site"
      })
    });
    const data = await res.json();
    if (!data.success || data.serviceAppointmentId !== "SA-001001") {
      throw new Error(`Failed to update service appointment: ${JSON.stringify(data)}`);
    }
  });

  // 6.8 Service Appointment GPS Check-in
  await test("POST /api/service-appointments/:id/check-in validates GPS geofence", async () => {
    const res = await fetch(`${BASE_URL}/api/service-appointments/SA-001001/check-in`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({ latitude: 18.52043, longitude: 73.856743, accuracy: 5.0 })
    });
    const data = await res.json();
    if (!res.ok || !data.success || !data.checkedIn || data.withinGeofence !== true) {
      throw new Error(`Service appointment GPS check-in failed: ${JSON.stringify(data)}`);
    }
  });

  // 6.9 Service Appointment Complete
  await test("POST /api/service-appointments/:id/complete closes appointment with report", async () => {
    const res = await fetch(`${BASE_URL}/api/service-appointments/SA-001001/complete`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        technicianNotes: "All tasks completed and tested.",
        resolutionTimeMin: 45
      })
    });
    const data = await res.json();
    if (!res.ok || !data.success || data.status !== "COMPLETED") {
      throw new Error(`Service appointment completion failed: ${JSON.stringify(data)}`);
    }
  });

  // 7. Update Status
  await test("PATCH /api/work-orders/:id/status updates status", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/status`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({ status: "In Progress" })
    });
    const data = await res.json();
    if (!data.success || data.newStatus !== "In Progress") {
      throw new Error(`Failed to update status`);
    }
  });

  // 8. Log Time
  await test("POST /api/work-orders/:id/time-log logs minutes worked", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/time-log`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({ hoursWorked: 2, notes: "Capacitor replacement" })
    });
    const data = await res.json();
    if (!data.success || data.timeLoggedMinutes !== 120) {
      throw new Error(`Failed to log time: ${JSON.stringify(data)}`);
    }
  });

  // 9. Complete Work Order with Base64 Signature & Photos
  await test("POST /api/work-orders/:id/complete generates service report and uploads signature & photos", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/complete`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        technicianNotes: "Replaced condenser capacitor and tested system.",
        partsUsed: "Capacitor 45MFD (1x)",
        timeLoggedMinutes: 90,
        customerSignature: {
          signerName: "Rajesh Kumar",
          base64:
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        },
        photos: [
          {
            fileName: "photo1.jpg",
            base64: "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD..."
          }
        ],
        sendToCustomer: true
      })
    });
    const data = await res.json();
    if (
      !data.success ||
      !data.signatureSaved ||
      data.photosUploadedCount !== 1
    ) {
      throw new Error(`Failed to complete work order: ${JSON.stringify(data)}`);
    }
  });

  // 9.1 Upload Attachment / Digital Signature Endpoint Test
  await test("POST /api/attachments/upload stores signature in ContentVersion & ContentDocumentLink", async () => {
    const res = await fetch(`${BASE_URL}/api/attachments/upload`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        workOrderId: "WO-001001",
        attachmentType: "Signature",
        fileName: "Customer_Signature.png",
        signerName: "Rajesh Kumar",
        base64Data:
          "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
      })
    });
    const data = await res.json();
    if (!data.success || !data.contentVersionId || !data.contentDocumentId) {
      throw new Error(`Failed to upload attachment: ${JSON.stringify(data)}`);
    }
  });

  // 9.1 Dynamic Natural Language to Salesforce Query (NL2SOQL) - Accounts
  await test("POST /api/ai/query resolves Accounts query dynamically", async () => {
    const res = await fetch(`${BASE_URL}/api/ai/query`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        prompt: "Show me top 10 accounts with revenue in Pune",
        maxRecords: 10
      })
    });
    const data = await res.json();
    if (
      !data.success ||
      data.targetObject !== "Account" ||
      !data.soqlGenerated.includes("Account") ||
      !data.aiSummary ||
      !data.records?.length
    ) {
      throw new Error(`NL2SOQL Account query failed: ${JSON.stringify(data)}`);
    }
  });

  // 9.2 Dynamic Natural Language Query - Technicians
  await test("POST /api/ai/query resolves Technicians query dynamically", async () => {
    const res = await fetch(`${BASE_URL}/api/ai/query`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        prompt: "Find active technicians with generator skills in Pune",
        maxRecords: 5
      })
    });
    const data = await res.json();
    if (
      !data.success ||
      data.targetObject !== "Technician__c" ||
      !data.soqlGenerated.includes("Technician__c") ||
      !data.records?.length
    ) {
      throw new Error(
        `NL2SOQL Technician query failed: ${JSON.stringify(data)}`
      );
    }
  });

  // 9.3 Dynamic Natural Language Query - Maintenance Alerts
  await test("POST /api/ai/query resolves Maintenance Alerts dynamically", async () => {
    const res = await fetch(`${BASE_URL}/api/ai/query`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        prompt: "Show all critical open alerts on generators",
        maxRecords: 5
      })
    });
    const data = await res.json();
    if (
      !data.success ||
      data.targetObject !== "Maintenance_Alert__c" ||
      !data.records?.length
    ) {
      throw new Error(`NL2SOQL Alert query failed: ${JSON.stringify(data)}`);
    }
  });

  // 9.4 Direct Dynamic SOQL Query Execution
  await test("POST /api/query/soql executes raw SOQL query", async () => {
    const res = await fetch(`${BASE_URL}/api/query/soql`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        soql: "SELECT Id, Name, Status__c FROM Work_Order__c LIMIT 3"
      })
    });
    const data = await res.json();
    if (!data.success || !Array.isArray(data.records)) {
      throw new Error(`Direct SOQL execution failed: ${JSON.stringify(data)}`);
    }
  });

  // 10. AI Troubleshoot
  await test("POST /api/ai/troubleshoot provides diagnostic steps and flags safety hazards", async () => {
    const res = await fetch(`${BASE_URL}/api/ai/troubleshoot`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        problemDescription:
          "high voltage arcing and smoke coming from transformer",
        equipmentType: "Generator"
      })
    });
    const data = await res.json();
    if (
      !data.success ||
      !data.escalateToSenior ||
      !data.diagnosisSteps?.length
    ) {
      throw new Error(`Troubleshooting failed: ${JSON.stringify(data)}`);
    }
  });

  // 11. AI Pre-Job Briefing
  await test("POST /api/ai/pre-job-briefing returns generated briefing", async () => {
    const res = await fetch(`${BASE_URL}/api/ai/pre-job-briefing`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({ workOrderId: "WO-001001", languageCode: "en" })
    });
    const data = await res.json();
    if (!data.success || !data.briefing) {
      throw new Error(`Briefing failed: ${JSON.stringify(data)}`);
    }
  });

  // 12. Offline Queue Batch Replay
  await test("POST /api/sync/offline-queue replays queued mutations", async () => {
    const res = await fetch(`${BASE_URL}/api/sync/offline-queue`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        technicianId: "TECH-001",
        mutations: [
          {
            queueId: "Q-01",
            action: "status_update",
            recordId: "WO-001001",
            fields: { Status__c: "In Progress" }
          },
          {
            queueId: "Q-02",
            action: "time_log",
            recordId: "WO-001001",
            fields: { Time_Logged_Minutes__c: 60 }
          }
        ]
      })
    });
    const data = await res.json();
    if (!data.success || data.totalProcessed !== 2 || data.syncedCount !== 2) {
      throw new Error(`Offline queue replay failed: ${JSON.stringify(data)}`);
    }
  });

  // 13. GPS Telemetry
  await test("POST /api/technician/location records GPS coordinates", async () => {
    const res = await fetch(`${BASE_URL}/api/technician/location`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        technicianId: "TECH-001",
        latitude: 18.5204,
        longitude: 73.8567
      })
    });
    const data = await res.json();
    if (!data.success || data.latitude !== 18.5204) {
      throw new Error(`Location telemetry failed: ${JSON.stringify(data)}`);
    }
  });

  // 14. MCP Protocol tools/list
  await test("POST /mcp tools/list returns MCP tool array", async () => {
    const res = await fetch(`${BASE_URL}/mcp`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 100, method: "tools/list" })
    });
    const data = await res.json();
    if (!data.result?.tools?.length || data.result.tools.length < 5) {
      throw new Error(`MCP tools/list failed: ${JSON.stringify(data)}`);
    }
  });

  // 15. MCP Protocol tools/call sobject_query
  await test("POST /mcp tools/call sobject_query executes query", async () => {
    const res = await fetch(`${BASE_URL}/mcp`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 101,
        method: "tools/call",
        params: {
          name: "sobject_query",
          arguments: { soql: "SELECT Id, Subject__c FROM Work_Order__c" }
        }
      })
    });
    const data = await res.json();
    const content = data.result?.content?.[0]?.text || "";
    if (!content.includes("WO-001001")) {
      throw new Error(`MCP query failed: ${JSON.stringify(data)}`);
    }
  });

  // 16. MCP Protocol tools/call get_account_summary (Top 10 Accounts)
  await test("POST /mcp tools/call get_account_summary returns top 10 accounts", async () => {
    const res = await fetch(`${BASE_URL}/mcp`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 102,
        method: "tools/call",
        params: {
          name: "get_account_summary",
          arguments: { limit: 10 }
        }
      })
    });
    const data = await res.json();
    const content = data.result?.content?.[0]?.text || "";
    if (
      !content.includes("Serum BioTech Campus") ||
      !content.includes("DLF CyberCity")
    ) {
      throw new Error(
        `MCP get_account_summary failed: ${JSON.stringify(data)}`
      );
    }
  });

  // 17. MCP Protocol tools/call execute_natural_language_query
  await test("POST /mcp tools/call execute_natural_language_query resolves prompt", async () => {
    const res = await fetch(`${BASE_URL}/mcp`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 103,
        method: "tools/call",
        params: {
          name: "execute_natural_language_query",
          arguments: { prompt: "Show me top 5 accounts in Pune", maxRecords: 5 }
        }
      })
    });
    const data = await res.json();
    const content = data.result?.content?.[0]?.text || "";
    if (!content.includes("soqlGenerated") || !content.includes("aiSummary")) {
      throw new Error(
        `MCP execute_natural_language_query failed: ${JSON.stringify(data)}`
      );
    }
  });

  // 18. Generic Salesforce Live CRUD Endpoints
  await test("GET /api/data/Account returns records list with totalSize", async () => {
    const res = await fetch(`${BASE_URL}/api/data/Account?limit=5`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!res.ok || !data.success || !Array.isArray(data.records) || data.records.length === 0) {
      throw new Error(`GET /api/data/Account failed: ${JSON.stringify(data)}`);
    }
  });

  await test("GET /api/data/Account/:id returns single record by ID", async () => {
    const res = await fetch(`${BASE_URL}/api/data/Account/0010000001`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!res.ok || !data.success || !data.record) {
      throw new Error(`GET /api/data/Account/:id failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/data/Account creates new record and returns 201 Created", async () => {
    const res = await fetch(`${BASE_URL}/api/data/Account`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        Name: "New Mobile Test Account",
        Industry: "Technology",
        BillingCity: "Pune"
      })
    });
    const data = await res.json();
    if (res.status !== 201 || !data.success || !data.id) {
      throw new Error(`POST /api/data/Account failed: ${JSON.stringify(data)}`);
    }
  });

  await test("PATCH /api/data/Account/:id updates record fields and returns 200 OK", async () => {
    const res = await fetch(`${BASE_URL}/api/data/Account/0010000001`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        Phone: "+91 99999 88888",
        AnnualRevenue: 95000000
      })
    });
    const data = await res.json();
    if (!res.ok || !data.success || !data.updatedFields?.includes("Phone")) {
      throw new Error(`PATCH /api/data/Account/:id failed: ${JSON.stringify(data)}`);
    }
  });

  await test("DELETE /api/data/Account/:id deletes record and returns 200 OK", async () => {
    const res = await fetch(`${BASE_URL}/api/data/Account/0010000001`, {
      method: "DELETE",
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!res.ok || !data.success) {
      throw new Error(`DELETE /api/data/Account/:id failed: ${JSON.stringify(data)}`);
    }
  });

  await test("GET /api/data/Account/:id/Contacts returns child related records", async () => {
    const res = await fetch(`${BASE_URL}/api/data/Account/0010000001/Contacts`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!res.ok || !data.success || !Array.isArray(data.records)) {
      throw new Error(`GET child relationship failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/data/query executes direct SOQL query", async () => {
    const res = await fetch(`${BASE_URL}/api/data/query`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({ soql: "SELECT Id, Name FROM Account LIMIT 5" })
    });
    const data = await res.json();
    if (!res.ok || !data.success || !Array.isArray(data.records)) {
      throw new Error(`POST /api/data/query failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/data/search executes SOSL search query", async () => {
    const res = await fetch(`${BASE_URL}/api/data/search`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({ searchTerm: "Generator" })
    });
    const data = await res.json();
    if (!res.ok || !data.success || !data.searchRecords) {
      throw new Error(`POST /api/data/search failed: ${JSON.stringify(data)}`);
    }
  });

  // 19. Additional MCP Tool Calls (sobject_get, sobject_delete, get_related_records)
  await test("POST /mcp tools/call sobject_get retrieves single record", async () => {
    const res = await fetch(`${BASE_URL}/mcp`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 104,
        method: "tools/call",
        params: {
          name: "sobject_get",
          arguments: { sobjectName: "Account", recordId: "0010000001" }
        }
      })
    });
    const data = await res.json();
    const content = data.result?.content?.[0]?.text || "";
    if (!content.includes("0010000001")) {
      throw new Error(`MCP sobject_get failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /mcp tools/call sobject_delete deletes record", async () => {
    const res = await fetch(`${BASE_URL}/mcp`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 105,
        method: "tools/call",
        params: {
          name: "sobject_delete",
          arguments: { sobjectName: "Account", recordId: "0010000001" }
        }
      })
    });
    const data = await res.json();
    const content = data.result?.content?.[0]?.text || "";
    if (!content.includes("deleted successfully")) {
      throw new Error(`MCP sobject_delete failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /mcp tools/call get_related_records fetches child records", async () => {
    const res = await fetch(`${BASE_URL}/mcp`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 106,
        method: "tools/call",
        params: {
          name: "get_related_records",
          arguments: { sobjectName: "Account", recordId: "0010000001", relationshipName: "Contacts" }
        }
      })
    });
    const data = await res.json();
    const content = data.result?.content?.[0]?.text || "";
    if (!content.includes("records")) {
      throw new Error(`MCP get_related_records failed: ${JSON.stringify(data)}`);
    }
  });

  // 16. Extended Mobile Domain Endpoints (24 Screens Coverage)
  await test("GET /api/dashboard returns shift metrics and SLA countdown", async () => {
    const res = await fetch(`${BASE_URL}/api/dashboard`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!res.ok || !data.success || !data.shift?.closestSlaMinutesRemaining) {
      throw new Error(`Dashboard API failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/jobs/:id/check-in validates GPS geofence distance", async () => {
    const res = await fetch(`${BASE_URL}/api/jobs/WO-001001/check-in`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({ latitude: 18.52043, longitude: 73.856743, accuracy: 5.0 })
    });
    const data = await res.json();
    if (!res.ok || !data.success || !data.checkedIn || data.withinGeofence !== true) {
      throw new Error(`GPS check-in failed: ${JSON.stringify(data)}`);
    }
  });

  await test("GET /api/parts returns parts catalogue", async () => {
    const res = await fetch(`${BASE_URL}/api/parts?query=sensor`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!res.ok || !data.success || data.parts.length === 0) {
      throw new Error(`Parts catalogue failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/jobs/:id/parts-requests submits parts request", async () => {
    const res = await fetch(`${BASE_URL}/api/jobs/WO-001001/parts-requests`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({ partId: "PRT-001", partCode: "TS-40", quantity: 1, isWarranty: true })
    });
    const data = await res.json();
    if (res.status !== 201 || !data.success || !data.partsRequestId) {
      throw new Error(`Parts request submission failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/jobs/:id/parts-return returns unused part to inventory", async () => {
    const res = await fetch(`${BASE_URL}/api/jobs/WO-001001/parts-return`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({ partsRequestId: "REQ-00101", partName: "Temperature Sensor TS-40", quantity: 1 })
    });
    const data = await res.json();
    if (!res.ok || !data.success || data.status !== "Returned") {
      throw new Error(`Parts return failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/ai/guru returns diagnostic recommendations and confidence", async () => {
    const res = await fetch(`${BASE_URL}/api/ai/guru`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({ jobId: "WO-001001", message: "AC is not cooling and making loud rattling noise" })
    });
    const data = await res.json();
    if (!res.ok || !data.success || !data.recommendedActions || data.confidence < 0.5) {
      throw new Error(`GuruAI diagnostic chat failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/attendance/check-in records morning punch-in", async () => {
    const res = await fetch(`${BASE_URL}/api/attendance/check-in`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ latitude: 18.52043, longitude: 73.856743 })
    });
    const data = await res.json();
    if (!res.ok || !data.success || data.status !== "ON_DUTY") {
      throw new Error(`Attendance punch-in failed: ${JSON.stringify(data)}`);
    }
  });

  await test("GET /api/notifications returns unread alerts", async () => {
    const res = await fetch(`${BASE_URL}/api/notifications`);
    const data = await res.json();
    if (!res.ok || !data.success || !Array.isArray(data.notifications)) {
      throw new Error(`Notifications API failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/gps/batch processes telemetry queue", async () => {
    const res = await fetch(`${BASE_URL}/api/gps/batch`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        deviceId: "DEV-TEST",
        positions: [{ latitude: 18.5204, longitude: 73.8567, timestamp: new Date().toISOString() }]
      })
    });
    const data = await res.json();
    if (!res.ok || !data.success || data.batchSize !== 1) {
      throw new Error(`Batch GPS failed: ${JSON.stringify(data)}`);
    }
  });

  // 20. Work Order Safety Check & Hazard Mitigation Tests
  await test("GET /api/work-orders/:id/safety-check returns equipment-specific hazard protocols & PPE", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/safety-check`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (
      !res.ok ||
      !data.success ||
      !Array.isArray(data.requiredPPE) ||
      !Array.isArray(data.hazardChecks) ||
      !data.safetyWarning
    ) {
      throw new Error(`Safety check fetch failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/work-orders/:id/safety-check submits technician safety clearance", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/safety-check`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        technicianId: "TECH-001",
        siteRiskLevel: "HIGH",
        ppeVerified: {
          safetyGoggles: true,
          dielectricGloves: true,
          steelToeBoots: true,
          hardHat: true
        },
        hazardChecks: [
          { hazardCode: "LOTO_APPLIED", verified: true },
          { hazardCode: "ZERO_ENERGY_STATE", verified: true }
        ],
        technicianDeclaration: "I confirm that all safety protocols have been executed and the work zone is secure.",
        latitude: 18.52043,
        longitude: 73.856743
      })
    });
    const data = await res.json();
    if (!res.ok || !data.success || !data.assessment?.safetyCheckId || data.assessment.status !== "CLEARED") {
      throw new Error(`Safety clearance submission failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/work-orders/:id/safety-escalation dispatches emergency hazard alert and halts job", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/safety-escalation`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        hazardType: "ELECTRICAL_ARCING",
        severity: "CRITICAL",
        hazardDetails: "Continuous high voltage arcing and active smoke near main busbar.",
        immediateActionTaken: "Main breaker tripped and area evacuated immediately.",
        evacuatedSite: true
      })
    });
    const data = await res.json();
    if (res.status !== 201 || !data.success || !data.escalation?.escalationId || !data.escalation.workHalted) {
      throw new Error(`Safety escalation failed: ${JSON.stringify(data)}`);
    }
  });

  await test("GET /api/work-orders/:id/safety-history returns safety audits and escalation records", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/safety-history`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!res.ok || !data.success || data.totalAssessmentsCount < 1 || data.totalEscalationsCount < 1) {
      throw new Error(`Safety history fetch failed: ${JSON.stringify(data)}`);
    }
  });

  // 21. Dynamic Work Order Checklist & Sensor Measurement Tests
  await test("GET /api/checklist/templates returns standardized templates by equipment category", async () => {
    const res = await fetch(`${BASE_URL}/api/checklist/templates`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!res.ok || !data.success || !data.templates.Generator || !data.templates.HVAC) {
      throw new Error(`Checklist templates fetch failed: ${JSON.stringify(data)}`);
    }
  });

  await test("GET /api/work-orders/:id/checklist returns dynamic multi-section checklist", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/checklist`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!res.ok || !data.success || !Array.isArray(data.sections) || data.totalItemsCount < 5) {
      throw new Error(`Dynamic checklist fetch failed: ${JSON.stringify(data)}`);
    }
  });

  await test("PATCH /api/work-orders/:id/checklist/:itemId updates telemetry measurement reading", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/checklist/chk_5`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        status: "PASSED",
        measuredValue: 416.5,
        comments: "L1-L2-L3 steady at 416.5V under balanced load."
      })
    });
    const data = await res.json();
    if (!res.ok || !data.success || data.updatedItem?.measuredValue !== 416.5 || data.updatedItem?.isCompleted !== true) {
      throw new Error(`Checklist item telemetry update failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /api/work-orders/:id/checklist/submit processes batch submission", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/checklist/submit`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        items: [
          { id: "chk_12", isCompleted: true, status: "PASSED" },
          { id: "chk_18", isCompleted: true, status: "PASSED" }
        ]
      })
    });
    const data = await res.json();
    if (!res.ok || !data.success || !data.status) {
      throw new Error(`Checklist submit failed: ${JSON.stringify(data)}`);
    }
  });

  // 22. MCP Safety & Checklist Protocol Tools
  await test("POST /mcp tools/call get_work_order_safety_checklist executes", async () => {
    const res = await fetch(`${BASE_URL}/mcp`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 201,
        method: "tools/call",
        params: {
          name: "get_work_order_safety_checklist",
          arguments: { workOrderId: "WO-001001", equipmentType: "Generator" }
        }
      })
    });
    const data = await res.json();
    const content = data.result?.content?.[0]?.text || "";
    if (!content.includes("requiredPPE") || !content.includes("hazardChecks")) {
      throw new Error(`MCP get_work_order_safety_checklist failed: ${JSON.stringify(data)}`);
    }
  });

  await test("POST /mcp tools/call get_work_order_checklist executes", async () => {
    const res = await fetch(`${BASE_URL}/mcp`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 202,
        method: "tools/call",
        params: {
          name: "get_work_order_checklist",
          arguments: { workOrderId: "WO-001001", equipmentType: "HVAC" }
        }
      })
    });
    const data = await res.json();
    const content = data.result?.content?.[0]?.text || "";
    if (!content.includes("sections")) {
      throw new Error(`MCP get_work_order_checklist failed: ${JSON.stringify(data)}`);
    }
  });

  // 21. Asset 360 Details & Full Service History
  await test("GET /api/assets/:id/details-and-history returns profile & historical jobs", async () => {
    const res = await fetch(`${BASE_URL}/api/assets/a001000000001/details-and-history`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!data.success || !data.asset?.serialNumber || !Array.isArray(data.serviceHistory)) {
      throw new Error(`Asset details and history failed: ${JSON.stringify(data)}`);
    }
  });

  // 22. Work Order Relevant Parts
  await test("GET /api/work-orders/:id/applicable-parts returns filtered parts", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/applicable-parts`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!data.success || !Array.isArray(data.parts) || data.count < 1) {
      throw new Error(`Applicable parts failed: ${JSON.stringify(data)}`);
    }
  });

  // 23. Temporarily Pause Work Order
  await test("POST /api/work-orders/:id/pause sets Temporarily Paused status and captures dependencies", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/pause`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        reason: "Waiting for Part",
        description: "Awaiting replacement coolant pump gasket from depot.",
        dependency: "PR-00091",
        responsibleTeam: "Procurement"
      })
    });
    const data = await res.json();
    if (!data.success || data.newStatus !== "Temporarily Paused" || !data.pauseLogId) {
      throw new Error(`Pause work order failed: ${JSON.stringify(data)}`);
    }
  });

  // 24. Resume Paused Work Order
  await test("POST /api/work-orders/:id/resume resumes job and logs comments", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/WO-001001/resume`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        resumeComments: "Part received on site. Resumed work order."
      })
    });
    const data = await res.json();
    if (!data.success || data.newStatus !== "In Progress" || !data.resumedAt) {
      throw new Error(`Resume work order failed: ${JSON.stringify(data)}`);
    }
  });

  // 25. Paused Work Orders Supervisor Dashboard
  await test("GET /api/work-orders/paused-dashboard returns aging and SLA breach metrics", async () => {
    const res = await fetch(`${BASE_URL}/api/work-orders/paused-dashboard`, {
      headers: { "x-mock-mode": "true" }
    });
    const data = await res.json();
    if (!data.success || typeof data.summary?.totalPaused !== "number" || !Array.isArray(data.records)) {
      throw new Error(`Paused dashboard failed: ${JSON.stringify(data)}`);
    }
  });

  // 26. Guru AI Dynamic Structured Response
  await test("POST /api/ai/guru returns structured SOP, safety precautions, and parts", async () => {
    const res = await fetch(`${BASE_URL}/api/ai/guru`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-mock-mode": "true" },
      body: JSON.stringify({
        jobId: "WO-001001",
        message: "How to replace coolant pump on Cummins generator?"
      })
    });
    const data = await res.json();
    const resp = data.structuredResponse;
    if (!data.success || !resp || !resp.actionableSteps?.length || !resp.recommendedParts?.length) {
      throw new Error(`Guru AI structured response failed: ${JSON.stringify(data)}`);
    }
  });

  // Kill server process
  serverProcess.kill("SIGTERM");

  console.log(`\n========================================`);
  console.log(`📊 Test Summary: ${passed} Passed, ${failed} Failed`);
  console.log(`========================================`);

  if (failed > 0) {
    process.exit(1);
  } else {
    console.log(
      "✨ All Mobile Backend REST & MCP API verification tests passed successfully!"
    );
    process.exit(0);
  }
}

runApiTests();
