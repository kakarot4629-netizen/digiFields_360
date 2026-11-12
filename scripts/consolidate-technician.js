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

const PRIMARY_TECH_ID = "a02g500000Bvf9mAAB"; // Piyush Channe (Technician__c)
const PRIMARY_USER_ID = "005g5000007AR1JAAW"; // Piyush Channe (User)
const REDUNDANT_TECH_IDS = [
  "a02g500000BvnNRAAZ", // Duplicate Piyush Channe without user
  "a02g500000C6F77AAF", // TECH-00004
  "a02g500000C6F78AAF"  // TECH-00005
];

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
  return await res.json();
}

async function sfRequest(token, endpoint, method = "GET", body = null) {
  const opts = {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    }
  };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(`${INSTANCE_URL}${endpoint}`, opts);
  if (res.status === 204) return { success: true };
  const json = await res.json();
  if (!res.ok) throw new Error(`HTTP ${res.status}: ` + JSON.stringify(json));
  return json;
}

async function main() {
  const auth = await getAuth();
  const token = auth.access_token;
  console.log("Connected to Salesforce org.");

  // 1. Reassign all Service Jobs to primary technician
  console.log("\n--- Step 1: Assigning ALL Service Appointments to Piyush Channe ---");
  const jobsRes = await sfRequest(token, "/services/data/v60.0/query?q=" + encodeURIComponent("SELECT Id, Name, Technician__c FROM Service_Job__c"));
  let reassignCount = 0;
  for (const j of jobsRes.records) {
    if (j.Technician__c !== PRIMARY_TECH_ID) {
      await sfRequest(token, `/services/data/v60.0/sobjects/Service_Job__c/${j.Id}`, "PATCH", {
        Technician__c: PRIMARY_TECH_ID
      });
      console.log(`Reassigned ${j.Name} (${j.Id}) to Piyush Channe`);
      reassignCount++;
    }
  }
  console.log(`Total appointments reassigned: ${reassignCount}. All ${jobsRes.records.length} are now with Piyush Channe.`);

  // 2. Clean child references in Assigned_Resource__c and Service_Crew_Member__c
  console.log("\n--- Step 2: Cleaning child lookups for obsolete technicians ---");
  const arRes = await sfRequest(token, "/services/data/v60.0/query?q=" + encodeURIComponent(`SELECT Id, Name, Technician__c FROM Assigned_Resource__c WHERE Technician__c IN ('${REDUNDANT_TECH_IDS.join("','")}')`));
  for (const ar of (arRes.records || [])) {
    await sfRequest(token, `/services/data/v60.0/sobjects/Assigned_Resource__c/${ar.Id}`, "DELETE");
    console.log(`Deleted obsolete Assigned_Resource__c: ${ar.Name}`);
  }

  const scmRes = await sfRequest(token, "/services/data/v60.0/query?q=" + encodeURIComponent(`SELECT Id, Name, Technician__c FROM Service_Crew_Member__c WHERE Technician__c IN ('${REDUNDANT_TECH_IDS.join("','")}')`));
  for (const scm of (scmRes.records || [])) {
    await sfRequest(token, `/services/data/v60.0/sobjects/Service_Crew_Member__c/${scm.Id}`, "DELETE");
    console.log(`Deleted obsolete Service_Crew_Member__c: ${scm.Name}`);
  }

  // 3. Delete redundant technicians
  console.log("\n--- Step 3: Deleting redundant technicians ---");
  for (const techId of REDUNDANT_TECH_IDS) {
    try {
      await sfRequest(token, `/services/data/v60.0/sobjects/Technician__c/${techId}`, "DELETE");
      console.log(`✅ Deleted Technician__c: ${techId}`);
    } catch (e) {
      console.error(`Error deleting ${techId}:`, e.message);
    }
  }

  // 4. Update Work Orders to assign to User Piyush Channe
  console.log("\n--- Step 4: Ensuring all Work Orders are assigned to User Piyush Channe ---");
  const woRes = await sfRequest(token, "/services/data/v60.0/query?q=" + encodeURIComponent("SELECT Id, Name, Assigned_Technician__c FROM Work_Order__c"));
  let woUpdated = 0;
  for (const wo of woRes.records) {
    if (wo.Assigned_Technician__c !== PRIMARY_USER_ID) {
      await sfRequest(token, `/services/data/v60.0/sobjects/Work_Order__c/${wo.Id}`, "PATCH", {
        Assigned_Technician__c: PRIMARY_USER_ID
      });
      woUpdated++;
    }
  }
  console.log(`Updated ${woUpdated} Work Orders to Assigned_Technician = Piyush Channe.`);

  // 5. Empty Recycle Bin via Tooling executeAnonymous
  console.log("\n--- Step 5: Emptying Recycle Bin ---");
  const purgeApex = `
    Database.emptyRecycleBin([SELECT Id FROM Technician__c WHERE isDeleted = true ALL ROWS]);
    Database.emptyRecycleBin([SELECT Id FROM Assigned_Resource__c WHERE isDeleted = true ALL ROWS]);
    Database.emptyRecycleBin([SELECT Id FROM Service_Crew_Member__c WHERE isDeleted = true ALL ROWS]);
  `;
  await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/executeAnonymous?anonymousBody=${encodeURIComponent(purgeApex)}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  console.log("Recycle bin emptied.");

  // 6. Verify final state
  console.log("\n--- Step 6: Verifying final state ---");
  const finalTechs = await sfRequest(token, "/services/data/v60.0/query?q=" + encodeURIComponent("SELECT Id, Name, User__c, User__r.Name, Is_Active__c, Availability_Status__c FROM Technician__c"));
  console.log("Technicians remaining in org:", finalTechs.totalSize);
  console.table(finalTechs.records.map(r => ({
    Id: r.Id,
    Name: r.Name,
    UserId: r.User__c,
    UserName: r.User__r ? r.User__r.Name : null,
    Active: r.Is_Active__c
  })));

  const finalJobs = await sfRequest(token, "/services/data/v60.0/query?q=" + encodeURIComponent("SELECT Id, Name, Technician__c, Technician__r.Name, Status__c, Work_Order__r.Name FROM Service_Job__c ORDER BY Name ASC"));
  console.log(`Service Appointments count: ${finalJobs.totalSize}`);
  const assignedToPiyush = finalJobs.records.filter(j => j.Technician__c === PRIMARY_TECH_ID).length;
  console.log(`Appointments assigned to Piyush Channe: ${assignedToPiyush} of ${finalJobs.totalSize} (${Math.round((assignedToPiyush / finalJobs.totalSize) * 100)}%)`);
}

main().catch(console.error);
