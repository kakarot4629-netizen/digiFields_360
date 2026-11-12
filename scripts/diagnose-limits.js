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

async function getAuth() {
  const params = new URLSearchParams({
    grant_type: "refresh_token",
    client_id: process.env.SF_CLIENT_ID || "PlatformCLI",
    refresh_token: process.env.SF_REFRESH_TOKEN
  });
  const res = await fetch(`${process.env.SF_INSTANCE_URL}/services/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params.toString()
  });
  return await res.json();
}

async function sfGet(auth, endpoint) {
  const res = await fetch(`${process.env.SF_INSTANCE_URL}${endpoint}`, {
    headers: { Authorization: `Bearer ${auth.access_token}` }
  });
  return await res.json();
}

async function main() {
  const auth = await getAuth();
  const limits = await sfGet(auth, "/services/data/v60.0/limits");
  console.log("DataStorageMB:", limits.DataStorageMB);
  console.log("FileStorageMB:", limits.FileStorageMB);

  // Check flows
  const flows = await sfGet(auth, "/services/data/v60.0/tooling/query?q=" + encodeURIComponent("SELECT Id, DeveloperName, ActiveVersionId FROM FlowDefinition WHERE DeveloperName LIKE '%Briefing%' OR DeveloperName LIKE '%Work_Order%'"));
  console.log("Flows:", JSON.stringify(flows, null, 2));

  // Check what objects are taking up storage
  // In Developer Edition, DataStorage is typically 5MB. Let's see what tables have records.
  const tables = ["Service_Job__c", "Work_Order__c", "Customer_Address__c", "Asset", "Account", "Contact", "Case", "FeedItem", "AsyncApexJob", "ApexLog"];
  for (const t of tables) {
    try {
      const q = await sfGet(auth, `/services/data/v60.0/query?q=SELECT+count()+FROM+${t}`);
      console.log(`Table ${t}: ${q.totalSize} records`);
    } catch (e) {
      console.log(`Table ${t}: error`);
    }
  }
}

main().catch(console.error);
