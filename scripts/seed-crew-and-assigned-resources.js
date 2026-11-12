const fs = require('fs');
const path = require('path');

function loadEnv() {
  const envPath = path.resolve(__dirname, '../.env');
  if (fs.existsSync(envPath)) {
    fs.readFileSync(envPath, 'utf8').split('\n').forEach(l => {
      const idx = l.indexOf('=');
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
const CLIENT_ID = process.env.SF_CLIENT_ID || 'PlatformCLI';

async function getAuth() {
  const params = new URLSearchParams({
    grant_type: 'refresh_token',
    client_id: CLIENT_ID,
    refresh_token: REFRESH_TOKEN
  });
  const res = await fetch(`${INSTANCE_URL}/services/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString()
  });
  const data = await res.json();
  return data.access_token;
}

async function postSObject(token, sobject, body) {
  const res = await fetch(`${INSTANCE_URL}/services/data/v60.0/sobjects/${sobject}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  const data = await res.json();
  return data;
}

async function main() {
  const token = await getAuth();
  console.log("Connected to Salesforce org.");

  const piyushTechId = 'a02g500000Bvf9mAAB';
  const tech4Id = 'a02g500000C6F77AAF';
  const tech5Id = 'a02g500000C6F78AAF';

  // Appointment IDs
  const sa21Id = 'a0Ig5000002KfYvEAK'; // WO-A (In Progress)
  const sa24Id = 'a0Ig5000002Kfc9EAC'; // WO-B (Assigned)

  // 1. Direct Multi-Technician Assignment on SA-0000021
  console.log("\n1. Seeding Direct Multi-Technician Assignment on SA-0000021 (WO-A)...");
  const arPiyushDirect = await postSObject(token, 'Assigned_Resource__c', {
    Service_Job__c: sa21Id,
    Technician__c: piyushTechId,
    Resource_Type__c: 'Technician',
    Role__c: 'Lead Technician',
    Is_Leader__c: true,
    Status__c: 'In Progress'
  });
  console.log("  Piyush Lead Assignment:", arPiyushDirect.id || arPiyushDirect);

  const arSecondaryDirect = await postSObject(token, 'Assigned_Resource__c', {
    Service_Job__c: sa21Id,
    Technician__c: tech4Id,
    Resource_Type__c: 'Technician',
    Role__c: 'Crew Member',
    Is_Leader__c: false,
    Status__c: 'In Progress'
  });
  console.log("  Secondary Tech (TECH-00004) Assignment:", arSecondaryDirect.id || arSecondaryDirect);

  // 2. Create Service Crew
  console.log("\n2. Creating Service Crew: 'High Voltage Heavy Overhaul Crew Alpha'...");
  const crewRes = await postSObject(token, 'Service_Crew__c', {
    Name: 'High Voltage Heavy Overhaul Crew Alpha',
    Crew_Size__c: 2,
    Is_Active__c: true,
    Description__c: 'Specialized high-voltage transformer dielectric & bushing maintenance crew.'
  });
  const crewId = crewRes.id;
  console.log("  Crew Created ID:", crewId);

  // 3. Add Crew Members
  console.log("\n3. Adding Crew Members (Piyush Channe as Leader, TECH-00005 as Member)...");
  const mem1 = await postSObject(token, 'Service_Crew_Member__c', {
    Service_Crew__c: crewId,
    Technician__c: piyushTechId,
    Is_Leader__c: true
  });
  console.log("  Member 1 (Piyush Leader):", mem1.id || mem1);

  const mem2 = await postSObject(token, 'Service_Crew_Member__c', {
    Service_Crew__c: crewId,
    Technician__c: tech5Id,
    Is_Leader__c: false
  });
  console.log("  Member 2 (TECH-00005):", mem2.id || mem2);

  // 4. Assign Crew to SA-0000024 (WO-B, Assigned status)
  console.log("\n4. Assigning Service Crew unit to SA-0000024 (Triggers automated crew explosion)...");
  const arCrew = await postSObject(token, 'Assigned_Resource__c', {
    Service_Job__c: sa24Id,
    Service_Crew__c: crewId,
    Resource_Type__c: 'Crew',
    Status__c: 'Assigned'
  });
  console.log("  Crew Assigned Resource:", arCrew.id || arCrew);

  // 5. Query and verify exploded resources
  console.log("\n5. Verifying Assigned Resources under SA-0000024...");
  const qUrl = `${INSTANCE_URL}/services/data/v60.0/query?q=` +
    encodeURIComponent(`SELECT Id, Name, Technician__c, Technician__r.Name, Service_Crew__r.Name, Resource_Type__c, Role__c, Is_Leader__c, Status__c FROM Assigned_Resource__c WHERE Service_Job__c = '${sa24Id}'`);
  const qRes = await fetch(qUrl, { headers: { Authorization: `Bearer ${token}` } });
  const qData = await qRes.json();
  console.log("Assigned Resources for SA-0000024:", JSON.stringify(qData.records, null, 2));

  console.log("\n🎉 MULTI-RESOURCE & CREW DATA SEEDED SUCCESSFULLY!");
}

main().catch(console.error);
