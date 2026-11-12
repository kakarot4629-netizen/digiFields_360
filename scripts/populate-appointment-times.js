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

async function main() {
  console.log("🔐 Authenticating with Salesforce...");
  const auth = await getAuth();
  console.log("Connected to:", auth.instanceUrl);

  console.log("\n🔍 Querying all Service Appointments (Service_Job__c)...");
  const query = "SELECT Id, Name, Status__c, Priority__c, Job_Type__c, SLA_Deadline__c, Check_In_Time__c, Completed_Time__c, Scheduled_Start_Time__c, Scheduled_End_Time__c, Resolution_Time_Min__c, Work_Order__c, Work_Order__r.Name FROM Service_Job__c ORDER BY CreatedDate DESC";
  const data = await sfRequest(auth, "/services/data/v60.0/query?q=" + encodeURIComponent(query));
  const jobs = data.records || [];
  console.log(`Found ${jobs.length} Service Appointment records.`);

  const now = Date.now();
  const summary = [];

  for (const job of jobs) {
    let schedStart, schedEnd, checkIn, completed, resMins;

    const status = job.Status__c || "Assigned";

    if (status === "Completed") {
      schedStart = new Date(now - 5 * 3600 * 1000).toISOString();
      schedEnd = new Date(now - 2 * 3600 * 1000).toISOString();
      checkIn = new Date(now - 4.5 * 3600 * 1000).toISOString();
      completed = new Date(now - 2.5 * 3600 * 1000).toISOString();
      resMins = 120;
    } else if (status === "In Progress") {
      schedStart = new Date(now - 2 * 3600 * 1000).toISOString();
      schedEnd = new Date(now + 1.5 * 3600 * 1000).toISOString();
      checkIn = new Date(now - 1.5 * 3600 * 1000).toISOString();
      completed = null;
      resMins = null;
    } else if (status === "On Site") {
      schedStart = new Date(now - 1 * 3600 * 1000).toISOString();
      schedEnd = new Date(now + 2 * 3600 * 1000).toISOString();
      checkIn = new Date(now - 0.5 * 3600 * 1000).toISOString();
      completed = null;
      resMins = null;
    } else if (status === "Parts Awaited") {
      schedStart = new Date(now - 3 * 3600 * 1000).toISOString();
      schedEnd = new Date(now + 1 * 3600 * 1000).toISOString();
      checkIn = new Date(now - 2.5 * 3600 * 1000).toISOString();
      completed = null;
      resMins = null;
    } else if (status === "En Route") {
      schedStart = new Date(now + 0.5 * 3600 * 1000).toISOString();
      schedEnd = new Date(now + 3.5 * 3600 * 1000).toISOString();
      checkIn = null;
      completed = null;
      resMins = null;
    } else if (status === "Assigned") {
      schedStart = new Date(now + 24 * 3600 * 1000).toISOString();
      schedEnd = new Date(now + 27 * 3600 * 1000).toISOString();
      checkIn = null;
      completed = null;
      resMins = null;
    } else { // New or other
      schedStart = new Date(now + 30 * 3600 * 1000).toISOString();
      schedEnd = new Date(now + 33 * 3600 * 1000).toISOString();
      checkIn = null;
      completed = null;
      resMins = null;
    }

    const payload = {
      Scheduled_Start_Time__c: schedStart,
      Scheduled_End_Time__c: schedEnd,
      Check_In_Time__c: checkIn,
      Completed_Time__c: completed,
      Resolution_Time_Min__c: resMins
    };

    await sfRequest(auth, `/services/data/v60.0/sobjects/Service_Job__c/${job.Id}`, "PATCH", payload);
    
    summary.push({
      ID: job.Id,
      Name: job.Name,
      Status: status,
      WO: job.Work_Order__r ? job.Work_Order__r.Name : "N/A",
      Scheduled_Start: schedStart ? schedStart.substring(11, 16) : "-",
      Scheduled_End: schedEnd ? schedEnd.substring(11, 16) : "-",
      Actual_Start: checkIn ? checkIn.substring(11, 16) : "-",
      Actual_End: completed ? completed.substring(11, 16) : "-"
    });
  }

  console.log("\n✅ All Service Appointments updated successfully with Start & End times:\n");
  console.table(summary);
}

main().catch(console.error);
