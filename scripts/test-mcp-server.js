/**
 * Automated Integration Test Suite for digiField360 Mobile MCP Server
 */
const http = require("http");
const { spawn } = require("child_process");

const PORT = 3000;
const MCP_URL = `http://localhost:${PORT}/mcp`;

async function runTests() {
  console.log("🧪 Starting Mobile MCP Server Verification Tests...\n");

  // Start MCP server in background
  const serverProcess = spawn("node", ["scripts/mcp-server.js"], {
    stdio: "inherit"
  });

  // Give server 1.5 seconds to bind port
  await new Promise((r) => setTimeout(r, 1500));

  let passed = 0;
  let failed = 0;

  async function testCall(testName, body, expectedCheck) {
    try {
      const res = await fetch(MCP_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-mock-mode": "true"
        },
        body: JSON.stringify(body)
      });

      const data = await res.json();
      if (res.ok && expectedCheck(data)) {
        console.log(`✅ [PASS] ${testName}`);
        passed++;
      } else {
        console.error(`❌ [FAIL] ${testName}`, JSON.stringify(data));
        failed++;
      }
    } catch (err) {
      console.error(`❌ [ERROR] ${testName}:`, err.message);
      failed++;
    }
  }

  // 1. Test tools/list
  await testCall(
    "tools/list endpoint returns all 5 mobile tools",
    { jsonrpc: "2.0", id: 1, method: "tools/list" },
    (res) => {
      const toolNames = res.result?.tools?.map((t) => t.name) || [];
      return [
        "sobject_query",
        "sobject_search",
        "sobject_update",
        "sobject_create",
        "sobject_describe"
      ].every((t) => toolNames.includes(t));
    }
  );

  // 2. Test sobject_query
  await testCall(
    "tools/call sobject_query returns work order records",
    {
      jsonrpc: "2.0",
      id: 2,
      method: "tools/call",
      params: {
        name: "sobject_query",
        arguments: { soql: "SELECT Id, Subject__c FROM Work_Order__c" }
      }
    },
    (res) => {
      const text = res.result?.content?.[0]?.text || "";
      return (
        text.includes("WO-001001") &&
        text.includes("Generator Overheating Check")
      );
    }
  );

  // 3. Test sobject_search
  await testCall(
    "tools/call sobject_search returns troubleshooting guides",
    {
      jsonrpc: "2.0",
      id: 3,
      method: "tools/call",
      params: {
        name: "sobject_search",
        arguments: { searchTerm: "compressor", sobjectName: "Knowledge__kav" }
      }
    },
    (res) => {
      const text = res.result?.content?.[0]?.text || "";
      return text.includes("Generator Compressor Troubleshooting Guide");
    }
  );

  // 4. Test sobject_update
  await testCall(
    "tools/call sobject_update updates record status",
    {
      jsonrpc: "2.0",
      id: 4,
      method: "tools/call",
      params: {
        name: "sobject_update",
        arguments: {
          sobjectName: "Work_Order__c",
          recordId: "WO-001001",
          fields: { Status__c: "Completed", Technician_Notes__c: "Fixed" }
        }
      }
    },
    (res) => {
      const text = res.result?.content?.[0]?.text || "";
      return text.includes('"success": true') && text.includes("WO-001001");
    }
  );

  // 5. Test sobject_create
  await testCall(
    "tools/call sobject_create creates new record",
    {
      jsonrpc: "2.0",
      id: 5,
      method: "tools/call",
      params: {
        name: "sobject_create",
        arguments: {
          sobjectName: "Job_History__c",
          fields: { Work_Order__c: "WO-001001", Equipment_ID__c: "EQ-100" }
        }
      }
    },
    (res) => {
      const text = res.result?.content?.[0]?.text || "";
      return text.includes('"success": true');
    }
  );

  // 6. Test sobject_describe
  await testCall(
    "tools/call sobject_describe returns schema metadata",
    {
      jsonrpc: "2.0",
      id: 6,
      method: "tools/call",
      params: {
        name: "sobject_describe",
        arguments: { sobjectName: "Work_Order__c" }
      }
    },
    (res) => {
      const text = res.result?.content?.[0]?.text || "";
      return text.includes("Work Order") && text.includes("fieldsCount");
    }
  );

  // Cleanup server process
  serverProcess.kill("SIGTERM");

  console.log(`\n📊 Verification Summary: ${passed} Passed, ${failed} Failed`);
  if (failed > 0) {
    process.exit(1);
  } else {
    console.log(
      "✨ All Mobile MCP Server verification tests passed successfully!"
    );
    process.exit(0);
  }
}

runTests();
