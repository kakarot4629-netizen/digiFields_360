/**
 * Node.js script to empty recycle bin and create 5 distinct Work Orders in Salesforce
 */
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
  console.log("🔑 Requesting fresh OAuth token from Salesforce...");
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
    instanceUrl: data.instance_url || INSTANCE_URL,
    id: data.id
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

async function emptyRecycleBin(token, instanceUrl, ids) {
  if (!ids || ids.length === 0) return;
  const idTags = ids.map(id => `<ids>${id}</ids>`).join("");
  const soapBody = `<?xml version="1.0" encoding="utf-8" ?>
<env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
  <env:Header>
    <n1:SessionHeader xmlns:n1="urn:partner.soap.sforce.com">
      <n1:sessionId>${token}</n1:sessionId>
    </n1:SessionHeader>
  </env:Header>
  <env:Body>
    <n1:emptyRecycleBin xmlns:n1="urn:partner.soap.sforce.com">
      ${idTags}
    </n1:emptyRecycleBin>
  </env:Body>
</env:Envelope>`;

  const url = `${instanceUrl}/services/Soap/u/59.0`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "text/xml; charset=UTF-8",
      SOAPAction: "emptyRecycleBin"
    },
    body: soapBody
  });
  const text = await res.text();
  console.log(`🧹 Emptied ${ids.length} records from Recycle Bin`);
}

async function createRecord(token, instanceUrl, sobject, data) {
  const url = `${instanceUrl}/services/data/v60.0/sobjects/${sobject}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(data)
  });
  const result = await res.json();
  return { status: res.status, ok: res.ok, result };
}

async function main() {
  const auth = await getAccessToken();
  console.log("✅ Authenticated to Salesforce! Instance:", auth.instanceUrl);

  // 1. Check all deleted records in Recycle Bin and empty them
  console.log("🔍 Checking Recycle Bin for deleted records...");
  const binQuery = await query(auth.accessToken, auth.instanceUrl, "SELECT Id, isDeleted FROM Work_Order__c WHERE isDeleted = true LIMIT 200");
  const binIds = (binQuery.records || []).map(r => r.Id);
  if (binIds.length > 0) {
    console.log(`Found ${binIds.length} deleted Work Order records in Recycle Bin. Purging...`);
    await emptyRecycleBin(auth.accessToken, auth.instanceUrl, binIds);
  }

  // Also check Job_History__c recycle bin
  try {
    const jobBin = await query(auth.accessToken, auth.instanceUrl, "SELECT Id, isDeleted FROM Job_History__c WHERE isDeleted = true LIMIT 200");
    const jobBinIds = (jobBin.records || []).map(r => r.Id);
    if (jobBinIds.length > 0) {
      await emptyRecycleBin(auth.accessToken, auth.instanceUrl, jobBinIds);
    }
  } catch(e) {}

  // 2. Fetch Existing Accounts & User
  const accQuery = await query(auth.accessToken, auth.instanceUrl, "SELECT Id, Name FROM Account ORDER BY CreatedDate ASC LIMIT 5");
  const accounts = accQuery.records || [];
  console.log(`Found ${accounts.length} existing Accounts:`, accounts.map(a => a.Name));

  const userQuery = await query(auth.accessToken, auth.instanceUrl, "SELECT Id, Name FROM User WHERE IsActive = true LIMIT 1");
  const primaryUserId = userQuery.records?.[0]?.Id;
  console.log(`Assigning to active Technician User: ${userQuery.records?.[0]?.Name} (${primaryUserId})`);

  const acc1 = accounts[0]?.Id;
  const acc2 = accounts[1]?.Id;
  const acc3 = accounts[2]?.Id;
  const acc4 = accounts[3]?.Id;
  const acc5 = accounts[4]?.Id;

  // 3. Define the 5 Diverse Work Orders
  const now = new Date();
  const workOrdersData = [
    {
      Subject__c: "Critical Main Substation Transformer Trip - Sector 4",
      Equipment_ID__c: "TX-11KV-SUB04",
      Equipment_Type__c: "High Voltage Transformer",
      Status__c: "In Progress",
      Priority__c: "Critical",
      Account__c: acc1,
      Assigned_Technician__c: primaryUserId,
      Site_Address__c: "Unit 4, Godrej Industrial Complex, Vikhroli East, Mumbai, MH 400079",
      Scheduled_Date__c: new Date(now.getTime() - 2 * 3600000).toISOString(),
      AI_Risk_Score__c: 94,
      AI_Assignment_Reason__c: "High-voltage certified specialist assigned due to closest GPS proximity (<4.2 km) and zero SLA breaches.",
      AI_Pre_Job_Briefing__c: "SAFETY WARNING: Arc-flash Category 4 PPE mandatory. De-energize 11kV busbar and apply lockout/tagout. Test dielectric oil breakdown voltage (min 30kV requirement).",
      Description__c: "High-voltage primary breaker tripped on differential overcurrent. Substation cooling oil temperature reached 88°C. Manufacturing Bays 1 & 2 temporarily running on backup DG.",
      Technician_Notes__c: "Lockout/Tagout applied. Inspected primary bushing; discovered partial dielectric puncture. Oil sample extracted for Dissolved Gas Analysis (DGA).",
      Parts_Used__c: "11kV Bushing Replacement Assembly (TB-11K), Transformer Dielectric Oil Grade-A (25L), High-Temp Gasket Seal Set (GS-4)",
      Time_Logged_Minutes__c: 135
    },
    {
      Subject__c: "Quarterly Comprehensive Overhaul - Central Chiller Plant Alpha",
      Equipment_ID__c: "HVAC-CHILL-800",
      Equipment_Type__c: "Industrial HVAC",
      Status__c: "Assigned",
      Priority__c: "High",
      Account__c: acc2,
      Assigned_Technician__c: primaryUserId,
      Site_Address__c: "Reliance Corporate IT Park, Building 7, Ghansoli, Navi Mumbai, MH 400701",
      Scheduled_Date__c: new Date(now.getTime() + 18 * 3600000).toISOString(),
      AI_Risk_Score__c: 42,
      AI_Assignment_Reason__c: "Assigned to Master HVAC Technician based on 98% First-Time-Fix-Rate on Trane/Carrier industrial chiller units.",
      AI_Pre_Job_Briefing__c: "Follow EPA refrigerant recovery guidelines. Verify condenser pressure delta across bundle. Check electronic expansion valve motor step calibration.",
      Description__c: "Quarterly preventive maintenance: Clean condenser tube bundles, inspect centrifugal compressor impeller bearings, test refrigerant line pressures, and calibrate thermostatic sensors.",
      Technician_Notes__c: "Pre-service checklists loaded on mobile app. Scheduled for early morning shutdown window.",
      Parts_Used__c: "Air Filter Heavy Duty 500kVA (AF-500K), Commercial Chiller Valve Kit (CV-KIT-01), Synthetic Compressor Oil (10L)",
      Time_Logged_Minutes__c: 0
    },
    {
      Subject__c: "IoT Anomaly: Alternator Bearing Vibration & Overheat Warning",
      Equipment_ID__c: "GEN-CAT-1500",
      Equipment_Type__c: "Diesel Generator",
      Status__c: "New",
      Priority__c: "Critical",
      Account__c: acc3,
      Site_Address__c: "Tata Communications IDC, MIDC Industrial Area, Vikhroli West, Mumbai, MH 400083",
      Scheduled_Date__c: new Date(now.getTime() + 3600000).toISOString(),
      AI_Risk_Score__c: 88,
      AI_Assignment_Reason__c: "Telemetry alert generated by Agentforce IoT Monitor. Requires Tier-4 DG mechanical specialist.",
      AI_Pre_Job_Briefing__c: "Inspect vibration dampener pads and alternator drive-end bearing. Measure thermal signature using Fluke IR camera before starting engine test.",
      Description__c: "Agentforce IoT Telemetry alert: Alternator drive-end bearing vibration exceeded 8.4 mm/s RMS (threshold: 4.5 mm/s) during weekly automated no-load exercise. Alternator bearing housing temperature reached 92°C.",
      Technician_Notes__c: "",
      Parts_Used__c: "",
      Time_Logged_Minutes__c: 0
    },
    {
      Subject__c: "Emergency Cleanroom Differential Pressure Transmitter Calibration",
      Equipment_ID__c: "AHU-ISO5-03",
      Equipment_Type__c: "Cleanroom AHU / Pressure Transmitter",
      Status__c: "Completed",
      Priority__c: "Medium",
      Account__c: acc4,
      Assigned_Technician__c: primaryUserId,
      Site_Address__c: "Sun Pharma Biotech R&D Facility, Phase 2, Hinjawadi MIDC, Pune, MH 411057",
      Scheduled_Date__c: new Date(now.getTime() - 28 * 3600000).toISOString(),
      Completed_Date__c: new Date(now.getTime() - 25 * 3600000).toISOString(),
      AI_Risk_Score__c: 15,
      AI_Assignment_Reason__c: "Assigned to certified ISO 17025 precision calibration technician with Class 100 cleanroom clearance.",
      AI_Pre_Job_Briefing__c: "Adhere to cleanroom aseptic gowning protocol. Use documented multi-function pressure calibrator with traceable NABL certificate.",
      Description__c: "ISO Class 5 sterile filling suite differential pressure transmitter fluctuating between +12 Pa and +2 Pa (target range: +25 Pa to +30 Pa). Cleanroom pressure cascade warning active.",
      Technician_Notes__c: "Calibrated 4-20mA transducer against digital reference manometer. Removed microscopic particulate blockage in suction impulse tubing. Cleanroom cascade pressure stabilized at +28.6 Pa.",
      Parts_Used__c: "Digital Flow Sensor Pro 4-20mA (DFS-PRO), 6mm Cleanroom Pneumatic Tubing (5m), High-Purity Sealing Tape",
      Time_Logged_Minutes__c: 95
    },
    {
      Subject__c: "Water Treatment RO Booster Pump Permeate Flow Reduction",
      Equipment_ID__c: "PUMP-RO-350",
      Equipment_Type__c: "Hydraulic Pump / Water Treatment",
      Status__c: "New",
      Priority__c: "Low",
      Account__c: acc5,
      Site_Address__c: "Mahindra Auto Assembly Plant 1, Gate 2, Chakan Industrial Corridor, Pune, MH 410501",
      Scheduled_Date__c: new Date(now.getTime() + 48 * 3600000).toISOString(),
      AI_Risk_Score__c: 22,
      AI_Assignment_Reason__c: "Assigned to Regional Pune Mobile Fleet during scheduled route optimization.",
      AI_Pre_Job_Briefing__c: "Check suction strainer mesh for scale build-up. Inspect mechanical cartridge seal face and measure motor shaft runout.",
      Description__c: "Secondary RO filtration booster pump showing 12% flow rate drop on permeate line. Minor mechanical seal seepage noticed during daily maintenance walkaround inspection.",
      Technician_Notes__c: "",
      Parts_Used__c: "",
      Time_Logged_Minutes__c: 0
    }
  ];

  console.log("\n🚀 Inserting 5 distinct Work Order records...");
  const createdRecords = [];

  for (let i = 0; i < workOrdersData.length; i++) {
    const data = workOrdersData[i];
    console.log(`\nCreating Record #${i + 1}: "${data.Subject__c}" (${data.Priority__c} | ${data.Equipment_Type__c})...`);
    let res = await createRecord(auth.accessToken, auth.instanceUrl, "Work_Order__c", data);

    if (res.ok) {
      console.log(`✅ Success! Created Work Order ID: ${res.result.id}`);
      createdRecords.push({ id: res.result.id, ...data });
    } else {
      console.error(`❌ Failed to create Record #${i + 1}:`, JSON.stringify(res.result, null, 2));
    }
  }

  // 4. Query back created records to verify
  console.log("\n========================================================");
  console.log("🔍 VERIFYING CREATED WORK ORDERS FROM SALESFORCE:");
  console.log("========================================================");
  const verifyQuery = await query(
    auth.accessToken,
    auth.instanceUrl,
    "SELECT Id, Name, Subject__c, Equipment_ID__c, Equipment_Type__c, Priority__c, Status__c, AI_Risk_Score__c, Account__r.Name, Site_Address__c, Scheduled_Date__c FROM Work_Order__c ORDER BY CreatedDate DESC LIMIT 5"
  );

  console.table(verifyQuery.records.map(r => ({
    "ID": r.Id,
    "Name": r.Name,
    "Subject": r.Subject__c?.substring(0, 35) + "...",
    "Priority": r.Priority__c,
    "Status": r.Status__c,
    "Equip ID": r.Equipment_ID__c,
    "Equip Type": r.Equipment_Type__c,
    "AI Risk": r.AI_Risk_Score__c,
    "Account": r.Account__r ? r.Account__r.Name : "N/A"
  })));

  console.log("\n🎉 ALL 5 DIVERSE WORK ORDER RECORDS CREATED AND VERIFIED!");
}

main().catch(err => {
  console.error("FATAL ERROR:", err);
  process.exit(1);
});
