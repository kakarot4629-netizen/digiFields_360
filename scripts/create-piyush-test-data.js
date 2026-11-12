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

  // 1. Get Piyush User
  const uData = await sfRequest(auth, "/services/data/v60.0/query?q=" + encodeURIComponent("SELECT Id, Name FROM User WHERE Name LIKE '%Piyush%' LIMIT 1"));
  if (!uData.records || uData.records.length === 0) throw new Error("User Piyush not found");
  const piyushUserId = uData.records[0].Id;
  console.log(`Found User: ${uData.records[0].Name} (${piyushUserId})`);

  // 2. Get Piyush Technician
  const techData = await sfRequest(auth, "/services/data/v60.0/query?q=" + encodeURIComponent(`SELECT Id, Name FROM Technician__c WHERE User__c = '${piyushUserId}' LIMIT 1`));
  let piyushTechId = techData.records && techData.records.length > 0 ? techData.records[0].Id : null;
  console.log(`Found Technician: ${piyushTechId}`);

  // 3. Get Account
  const accData = await sfRequest(auth, "/services/data/v60.0/query?q=" + encodeURIComponent("SELECT Id, Name FROM Account LIMIT 2"));
  const acc1 = accData.records && accData.records.length > 0 ? accData.records[0].Id : null;
  const acc2 = accData.records && accData.records.length > 1 ? accData.records[1].Id : acc1;

  // 4. Create Work Order 1
  console.log("\n📦 Creating Work Order 1 for Piyush...");
  const wo1Res = await sfRequest(auth, "/services/data/v60.0/sobjects/Work_Order__c", "POST", {
    Subject__c: "Emergency Diagnostic & Calibration - Industrial Chiller Unit #4",
    Equipment_ID__c: "HVAC-CHILL-400",
    Equipment_Type__c: "Industrial HVAC",
    Priority__c: "High",
    Status__c: "In Progress",
    Scheduled_Date__c: new Date(Date.now() - 2 * 3600 * 1000).toISOString(),
    Account__c: acc1,
    Assigned_Technician__c: piyushUserId,
    Site_Address__c: "Building B, Cyber City, Sector 29, Gurgaon, HR 122002",
    Description__c: "Secondary chilled water loop temperature anomaly detected. Field diagnostic required.",
    Technician_Notes__c: "Diagnostic in progress with Fluke thermal sensors."
  });
  console.log(`✅ Work Order 1 created: ID ${wo1Res.id}`);

  // 5. Create Work Order 2
  console.log("\n📦 Creating Work Order 2 for Piyush...");
  const wo2Res = await sfRequest(auth, "/services/data/v60.0/sobjects/Work_Order__c", "POST", {
    Subject__c: "Preventive Overhaul & Bushing Inspection - Substation Transformer",
    Equipment_ID__c: "TX-33KV-SUB02",
    Equipment_Type__c: "High Voltage Transformer",
    Priority__c: "Medium",
    Status__c: "Assigned",
    Scheduled_Date__c: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
    Account__c: acc2,
    Assigned_Technician__c: piyushUserId,
    Site_Address__c: "Plot 45, MIDC Phase 2, Andheri East, Mumbai, MH 400093",
    Description__c: "Comprehensive scheduled quarterly inspection and dielectric oil testing.",
    Technician_Notes__c: "Pre-service checklists and safety lockout instructions loaded."
  });
  console.log(`✅ Work Order 2 created: ID ${wo2Res.id}`);

  // 6. Create Service Appointments for WO 1 with unique statuses
  console.log("\n📅 Creating 3 Service Appointments for Work Order 1...");
  
  const sa1Res = await sfRequest(auth, "/services/data/v60.0/sobjects/Service_Job__c", "POST", {
    Work_Order__c: wo1Res.id,
    Technician__c: piyushTechId,
    Account__c: acc1,
    Status__c: "In Progress",
    Job_Type__c: "Diagnostic",
    Priority__c: "High",
    SLA_Deadline__c: new Date(Date.now() + 4 * 3600 * 1000).toISOString(),
    Notes__c: "Diagnostic on refrigerant suction pressure and thermostatic expansion valve."
  });
  console.log(`-> SA 1 created: ${sa1Res.id} | Status: In Progress`);

  const sa2Res = await sfRequest(auth, "/services/data/v60.0/sobjects/Service_Job__c", "POST", {
    Work_Order__c: wo1Res.id,
    Technician__c: piyushTechId,
    Account__c: acc1,
    Status__c: "On Site",
    Job_Type__c: "Repair",
    Priority__c: "High",
    SLA_Deadline__c: new Date(Date.now() + 8 * 3600 * 1000).toISOString(),
    Notes__c: "Technician arrived on site, commencing compressor motor coil testing."
  });
  console.log(`-> SA 2 created: ${sa2Res.id} | Status: On Site`);

  const sa3Res = await sfRequest(auth, "/services/data/v60.0/sobjects/Service_Job__c", "POST", {
    Work_Order__c: wo1Res.id,
    Technician__c: piyushTechId,
    Account__c: acc1,
    Status__c: "Parts Awaited",
    Job_Type__c: "Repair",
    Priority__c: "Medium",
    SLA_Deadline__c: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
    Notes__c: "Awaiting replacement electronic expansion valve motor assembly from central depot."
  });
  console.log(`-> SA 3 created: ${sa3Res.id} | Status: Parts Awaited`);

  // 7. Create Service Appointments for WO 2 with unique statuses
  console.log("\n📅 Creating 2 Service Appointments for Work Order 2...");

  const sa4Res = await sfRequest(auth, "/services/data/v60.0/sobjects/Service_Job__c", "POST", {
    Work_Order__c: wo2Res.id,
    Technician__c: piyushTechId,
    Account__c: acc2,
    Status__c: "Assigned",
    Job_Type__c: "Preventive Maintenance",
    Priority__c: "Medium",
    SLA_Deadline__c: new Date(Date.now() + 36 * 3600 * 1000).toISOString(),
    Notes__c: "Assigned for pre-service safety briefing and lockout/tagout preparation."
  });
  console.log(`-> SA 4 created: ${sa4Res.id} | Status: Assigned`);

  const sa5Res = await sfRequest(auth, "/services/data/v60.0/sobjects/Service_Job__c", "POST", {
    Work_Order__c: wo2Res.id,
    Technician__c: piyushTechId,
    Account__c: acc2,
    Status__c: "En Route",
    Job_Type__c: "Inspection",
    Priority__c: "Low",
    SLA_Deadline__c: new Date(Date.now() + 48 * 3600 * 1000).toISOString(),
    Notes__c: "Technician dispatched and en route to substation facility."
  });
  console.log(`-> SA 5 created: ${sa5Res.id} | Status: En Route`);

  console.log("\n🎉 ALL RECORDS CREATED SUCCESSFULLY!");
  return {
    wo1: wo1Res.id,
    wo2: wo2Res.id,
    saList: [
      { id: sa1Res.id, status: "In Progress" },
      { id: sa2Res.id, status: "On Site" },
      { id: sa3Res.id, status: "Parts Awaited" },
      { id: sa4Res.id, status: "Assigned" },
      { id: sa5Res.id, status: "En Route" }
    ]
  };
}

main().catch(console.error);
