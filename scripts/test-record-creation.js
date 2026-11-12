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
  return {
    accessToken: data.access_token,
    instanceUrl: data.instance_url || INSTANCE_URL
  };
}

async function testCreate() {
  const auth = await getAccessToken();
  console.log("Testing record creation in:", auth.instanceUrl);

  const testPayload = {
    Subject__c: "Storage Test Work Order - Verified",
    Status__c: "New",
    Priority__c: "Medium",
    Equipment_Type__c: "Generator"
  };

  const url = `${auth.instanceUrl}/services/data/v60.0/sobjects/Work_Order__c`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${auth.accessToken}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(testPayload)
  });

  const result = await res.json();
  console.log("Create status:", res.status);
  console.log("Result:", result);

  if (res.ok && result.id) {
    console.log("🎉 SUCCESS! Record created with ID:", result.id);
    // Cleanup the test record
    await fetch(`${auth.instanceUrl}/services/data/v60.0/sobjects/Work_Order__c/${result.id}`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${auth.accessToken}` }
    });
    console.log("Cleaned up test record.");
  } else {
    console.error("❌ FAILED:", result);
  }
}

testCreate().catch(console.error);
