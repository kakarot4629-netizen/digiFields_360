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

const INSTANCE_URL = process.env.SF_INSTANCE_URL;
const REFRESH_TOKEN = process.env.SF_REFRESH_TOKEN;
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
  if (!res.ok) throw new Error("Auth failed: " + JSON.stringify(data));
  return {
    accessToken: data.access_token,
    instanceUrl: data.instance_url || INSTANCE_URL
  };
}

async function sfRequest(auth, endpoint, method = "GET", body = null) {
  const opts = {
    method,
    headers: {
      Authorization: `Bearer ${auth.accessToken}`,
      "Content-Type": "application/json"
    }
  };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(`${auth.instanceUrl}${endpoint}`, opts);
  if (res.status === 204) return { success: true };
  const json = await res.json();
  if (!res.ok) throw new Error(`HTTP ${res.status}: ` + JSON.stringify(json));
  return json;
}

// Enterprise Work Order name mapping
const NAME_MAP = {
  "a03g500000jFzPTAA0": "WO-0001001",
  "a03g500000jG4VaAAK": "WO-0001002",
  "a03g500000jG5ppAAC": "WO-0001003",
  "a03g500000jG5rRAAS": "WO-0001004",
  "a03g500000lmJyBAAU": "WO-0001005",
  "a03g500000lmJyCAAU": "WO-0001006",
  "a03g500000lupw8AAA": "WO-0001007",
  "a03g500000lvXfJAAU": "WO-0001008",
  "a03g500000m95w5AAA": "WO-0009021", // Retained known enterprise ID
  "a03g500000mCIaEAAW": "WO-0001010",
  "a03g500000mJdwUAAS": "WO-0001011",
  "a03g500000mKECtAAO": "WO-0001012",
  "a03g500000mKkO1AAK": "WO-0001013",
  "a03g500000mKkPdAAK": "WO-0001014"
};

async function main() {
  console.log("🔐 Authenticating with Salesforce...");
  const auth = await getAuth();
  console.log("Connected to:", auth.instanceUrl);

  console.log("\n🔍 Querying all Work Orders...");
  const data = await sfRequest(auth, "/services/data/v60.0/query?q=" + encodeURIComponent("SELECT Id, Name, Subject__c, Equipment_ID__c, Status__c, Priority__c FROM Work_Order__c ORDER BY CreatedDate ASC"));
  const wos = data.records || [];
  console.log(`Found ${wos.length} Work Order records.\n`);

  const results = [];
  let counter = 1001;

  for (const wo of wos) {
    const newName = NAME_MAP[wo.Id] || `WO-${String(counter++).padStart(7, '0')}`;
    const oldName = wo.Name;

    if (oldName !== newName) {
      await sfRequest(auth, `/services/data/v60.0/sobjects/Work_Order__c/${wo.Id}`, "PATCH", {
        Name: newName
      });
      results.push({
        Id: wo.Id,
        Old_Name: oldName,
        New_Name: newName,
        Status: "✅ Renamed",
        Subject: wo.Subject__c ? wo.Subject__c.substring(0, 35) : "-"
      });
    } else {
      results.push({
        Id: wo.Id,
        Old_Name: oldName,
        New_Name: newName,
        Status: "ℹ️ Unchanged",
        Subject: wo.Subject__c ? wo.Subject__c.substring(0, 35) : "-"
      });
    }
  }

  console.log("🎉 All Work Orders successfully updated with enterprise standard names:\n");
  console.table(results);
}

main().catch(console.error);
