const fs = require("fs");
const path = require("path");

function loadEnvFile() {
  try {
    const envPath = path.resolve(__dirname, "../.env");
    if (fs.existsSync(envPath)) {
      const content = fs.readFileSync(envPath, "utf8");
      content.split("\n").forEach((line) => {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith("#")) {
          const idx = trimmed.indexOf("=");
          if (idx > 0) {
            const key = trimmed.substring(0, idx).trim();
            const val = trimmed.substring(idx + 1).trim();
            if (!process.env[key]) {
              process.env[key] = val;
            }
          }
        }
      });
    }
  } catch (e) {}
}
loadEnvFile();

const INSTANCE_URL = process.env.SF_INSTANCE_URL || "https://orgfarm-4036b01401-dev-ed.develop.my.salesforce.com";
const REFRESH_TOKEN = process.env.SF_REFRESH_TOKEN || "";
const CLIENT_ID = process.env.SF_CLIENT_ID || "PlatformCLI";

async function getAccessToken() {
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
  if (!res.ok) {
    throw new Error("Token refresh error: " + JSON.stringify(data));
  }
  return {
    accessToken: data.access_token,
    instanceUrl: data.instance_url || INSTANCE_URL
  };
}

async function testApi() {
  console.log("🔐 Authenticating with Salesforce...");
  const auth = await getAccessToken();
  console.log("Connected to instance:", auth.instanceUrl);

  // 1. Find a Work Order in the org
  const soql = encodeURIComponent("SELECT Id, Name, Subject__c FROM Work_Order__c ORDER BY CreatedDate DESC LIMIT 1");
  const queryRes = await fetch(`${auth.instanceUrl}/services/data/v60.0/query?q=${soql}`, {
    headers: { Authorization: `Bearer ${auth.accessToken}` }
  });
  const queryData = await queryRes.json();

  if (!queryData.records || queryData.records.length === 0) {
    console.log("No Work Orders found in org. Creating a test Work Order...");
    return;
  }

  const sampleWo = queryData.records[0];
  console.log(`\n📋 Testing with Work Order: ${sampleWo.Name} (${sampleWo.Id}) - "${sampleWo.Subject__c}"`);

  // 2. Call our newly deployed Apex REST API by Record ID
  const endpoint1 = `${auth.instanceUrl}/services/apexrest/df360/v1/work-orders/${sampleWo.Id}/service-appointments`;
  console.log(`\n▶ GET ${endpoint1}`);
  const res1 = await fetch(endpoint1, {
    headers: {
      Authorization: `Bearer ${auth.accessToken}`,
      "Content-Type": "application/json"
    }
  });

  console.log(`Status: ${res1.status} ${res1.statusText}`);
  const json1 = await res1.json();
  console.log("\n📦 API Response Payload (by ID):");
  console.log(JSON.stringify(json1, null, 2));

  // 3. Call by Work Order Name (e.g. WO-000001)
  const endpoint2 = `${auth.instanceUrl}/services/apexrest/df360/v1/work-orders/${sampleWo.Name}/service-appointments`;
  console.log(`\n▶ GET ${endpoint2}`);
  const res2 = await fetch(endpoint2, {
    headers: {
      Authorization: `Bearer ${auth.accessToken}`,
      "Content-Type": "application/json"
    }
  });

  console.log(`Status: ${res2.status} ${res2.statusText}`);
  const json2 = await res2.json();
  console.log("\n📦 API Response Payload (by Name):");
  console.log(JSON.stringify(json2, null, 2));
}

testApi().catch(console.error);
