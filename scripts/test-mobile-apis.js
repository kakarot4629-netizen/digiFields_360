/**
 * Automated Verification Suite for digiField360 Mobile Backend REST & MCP APIs
 */
const { spawn } = require("child_process");

const PORT = 3001; // Use test port 3001 to avoid conflicting with running instances
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
        password: "ImIronMan@3000"
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
    if (!data.success || data.workOrder.Id !== "WO-001001") {
      throw new Error(`Invalid WO details: ${JSON.stringify(data)}`);
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
