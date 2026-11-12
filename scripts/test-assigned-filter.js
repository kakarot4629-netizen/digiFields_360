const fs = require("fs");
const path = require("path");

function loadEnv() {
  const envPath = path.resolve(__dirname, "../.env");
  if (fs.existsSync(envPath)) {
    const lines = fs.readFileSync(envPath, "utf8").split("\n");
    lines.forEach((l) => {
      const idx = l.indexOf("=");
      if (idx > 0) {
        const k = l.substring(0, idx).trim();
        const v = l.substring(idx + 1).trim();
        if (!process.env[k]) process.env[k] = v;
      }
    });
  }
}
loadEnv();

const INSTANCE_URL = process.env.SF_INSTANCE_URL || "https://orgfarm-4036b01401-dev-ed.develop.my.salesforce.com";
const REFRESH_TOKEN = process.env.SF_REFRESH_TOKEN || "";
const CLIENT_ID = process.env.SF_CLIENT_ID || "PlatformCLI";

async function getAuth() {
  const params = new URLSearchParams({
    grant_type: "refresh_token",
    client_id: CLIENT_ID,
    refresh_token: REFRESH_TOKEN
  });
  const res = await fetch(`${INSTANCE_URL}/services/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params.toString()
  });
  const data = await res.json();
  return data.access_token;
}

async function testApi() {
  const token = await getAuth();

  console.log("=== TEST 1: GET /services/apexrest/df360/v1/work-orders/my?status=Assigned ===");
  const res1 = await fetch(`${INSTANCE_URL}/services/apexrest/df360/v1/work-orders/my?status=Assigned`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const data1 = await res1.json();
  console.log(`HTTP ${res1.status} | Total Work Orders (status=Assigned):`, data1.totalWorkOrders);
  data1.workOrders.forEach((w) => {
    console.log(`\n📋 [WO] ${w.name} | Subject: "${w.subject}" | Status: ${w.status} | Tech: ${w.workOrder.assignedTechnician ? w.workOrder.assignedTechnician.name : 'N/A'}`);
    console.log(`   Assigned Appointments Count: ${w.serviceAppointmentsCount}`);
    w.serviceAppointments.forEach((sa) => {
      console.log(`     * [SA] ${sa.name} | Status: "${sa.status}" | Type: ${sa.jobType} | Tech: ${sa.technician ? sa.technician.name : 'N/A'}`);
    });
  });

  console.log("\n=== TEST 2: GET /services/apexrest/df360/v1/work-orders/assigned (Shortcut route) ===");
  const res2 = await fetch(`${INSTANCE_URL}/services/apexrest/df360/v1/work-orders/assigned`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const data2 = await res2.json();
  console.log(`HTTP ${res2.status} | Total Work Orders:`, data2.totalWorkOrders);

  console.log("\n=== TEST 3: GET /services/apexrest/df360/v1/work-orders/my (All jobs assigned to Piyush) ===");
  const res3 = await fetch(`${INSTANCE_URL}/services/apexrest/df360/v1/work-orders/my`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const data3 = await res3.json();
  console.log(`HTTP ${res3.status} | Total Work Orders:`, data3.totalWorkOrders);
}

testApi().catch(console.error);
