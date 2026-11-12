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
  if (!res.ok || !data.access_token) {
    throw new Error("OAuth token refresh failed: " + JSON.stringify(data));
  }
  return {
    accessToken: data.access_token,
    instanceUrl: data.instance_url || INSTANCE_URL
  };
}

async function query(token, instanceUrl, soql) {
  const url = `${instanceUrl}/services/data/v60.0/queryAll?q=${encodeURIComponent(soql)}`;
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    }
  });
  return res.json();
}

async function checkStorageLimits(token, instanceUrl) {
  const url = `${instanceUrl}/services/data/v60.0/limits`;
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    }
  });
  return res.json();
}

async function main() {
  const auth = await getAccessToken();
  console.log("Connected to:", auth.instanceUrl);

  const limits = await checkStorageLimits(auth.accessToken, auth.instanceUrl);
  console.log("\n--- ORG LIMITS ---");
  console.log("DataStorageMB:", limits.DataStorageMB);
  console.log("FileStorageMB:", limits.FileStorageMB);

  const objectsToCheck = [
    "Work_Order__c",
    "Service_Job__c",
    "Job_Activity__c",
    "Job_History__c",
    "GPS_Log__c",
    "Attendance__c",
    "CSAT__c",
    "WhatsApp_Message__c",
    "Case",
    "Task",
    "FeedItem",
    "ContentVersion",
    "Maintenance_Alert__c",
    "SLA_Event__c",
    "Parts_Request__c"
  ];

  console.log("\n--- RECORD COUNTS (INCLUDING DELETED / RECYCLE BIN) ---");
  for (const obj of objectsToCheck) {
    try {
      const q = await query(auth.accessToken, auth.instanceUrl, `SELECT COUNT(Id) cnt FROM ${obj}`);
      const qDel = await query(auth.accessToken, auth.instanceUrl, `SELECT COUNT(Id) cnt FROM ${obj} WHERE isDeleted = true`);
      console.log(`${obj.padEnd(25)}: Active = ${q.records?.[0]?.cnt || 0}, In Recycle Bin = ${qDel.records?.[0]?.cnt || 0}`);
    } catch (e) {
      console.log(`${obj.padEnd(25)}: Error/Not found (${e.message})`);
    }
  }
}

main().catch(console.error);
