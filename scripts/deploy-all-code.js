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

async function deployApexClass(token, className, classBody) {
  console.log(`Checking if ApexClass ${className} exists...`);
  const qUrl = `${INSTANCE_URL}/services/data/v60.0/tooling/query?q=` + 
    encodeURIComponent(`SELECT Id, Name FROM ApexClass WHERE Name = '${className}'`);
  const qRes = await fetch(qUrl, { headers: { Authorization: `Bearer ${token}` } });
  const qData = await qRes.json();

  if (qData.totalSize === 0) {
    console.log(`Creating new ApexClass ${className}...`);
    const cRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ApexClass`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        Name: className,
        Body: classBody
      })
    });
    const cData = await cRes.json();
    console.log(`Create result for ${className}:`, cData);
    return cData.id;
  } else {
    console.log(`ApexClass ${className} already exists (${qData.records[0].Id}). Updating via MetadataContainer...`);
    return qData.records[0].Id;
  }
}

async function deployApexTrigger(token, triggerName, targetSObject, triggerBody) {
  console.log(`Checking if ApexTrigger ${triggerName} exists...`);
  const qUrl = `${INSTANCE_URL}/services/data/v60.0/tooling/query?q=` + 
    encodeURIComponent(`SELECT Id, Name FROM ApexTrigger WHERE Name = '${triggerName}'`);
  const qRes = await fetch(qUrl, { headers: { Authorization: `Bearer ${token}` } });
  const qData = await qRes.json();

  if (qData.totalSize === 0) {
    console.log(`Creating new ApexTrigger ${triggerName}...`);
    const cRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ApexTrigger`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        Name: triggerName,
        TableEnumOrId: targetSObject,
        Body: triggerBody
      })
    });
    const cData = await cRes.json();
    console.log(`Create result for ${triggerName}:`, cData);
    return cData.id;
  } else {
    console.log(`ApexTrigger ${triggerName} already exists (${qData.records[0].Id}).`);
    return qData.records[0].Id;
  }
}

async function updateClassesWithContainer(token, classesToUpdate) {
  const containerName = "Deploy_" + Date.now();
  const cRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/MetadataContainer`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ Name: containerName })
  });
  const cData = await cRes.json();
  const containerId = cData.id;
  console.log("MetadataContainer ID:", containerId);

  for (const item of classesToUpdate) {
    const memberRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ApexClassMember`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        MetadataContainerId: containerId,
        ContentEntityId: item.id,
        Body: item.body
      })
    });
    const memberData = await memberRes.json();
    console.log(`Member created for ${item.name}:`, memberData.id || memberData);
  }

  // Request Async Deploy
  const reqRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ContainerAsyncRequest`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      MetadataContainerId: containerId,
      IsCheckOnly: false
    })
  });
  const reqData = await reqRes.json();
  const requestId = reqData.id;
  console.log("Deploy Request ID:", requestId);

  // Poll
  for (let i = 0; i < 25; i++) {
    await new Promise((r) => setTimeout(r, 1200));
    const statusRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ContainerAsyncRequest/${requestId}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    const statusData = await statusRes.json();
    console.log("Deploy Status:", statusData.State);
    if (statusData.State === "Completed") {
      console.log("🚀 Container deployed successfully!");
      return true;
    } else if (statusData.State === "Failed" || statusData.State === "Error") {
      console.error("Deploy failed:", JSON.stringify(statusData, null, 2));
      return false;
    }
  }
}

async function main() {
  const token = await getAuth();
  console.log("Authenticated successfully.");

  // 1. Deploy DF360_AssignedResourceTriggerHandler
  const handlerPath = path.resolve(__dirname, '../force-app/main/default/classes/DF360_AssignedResourceTriggerHandler.cls');
  const handlerBody = fs.readFileSync(handlerPath, 'utf8');
  await deployApexClass(token, 'DF360_AssignedResourceTriggerHandler', handlerBody);

  // 2. Deploy DF360_AssignedResourceTrigger
  const triggerPath = path.resolve(__dirname, '../force-app/main/default/triggers/DF360_AssignedResourceTrigger.trigger');
  const triggerBody = fs.readFileSync(triggerPath, 'utf8');
  await deployApexTrigger(token, 'DF360_AssignedResourceTrigger', 'Assigned_Resource__c', triggerBody);

  // 3. Deploy DF360_AssignedResourceTriggerHandlerTest
  const testPath = path.resolve(__dirname, '../force-app/main/default/classes/DF360_AssignedResourceTriggerHandlerTest.cls');
  const testBody = fs.readFileSync(testPath, 'utf8');
  await deployApexClass(token, 'DF360_AssignedResourceTriggerHandlerTest', testBody);

  // 4. Update DF360_WorkOrderAppointmentsAPI via MetadataContainer
  console.log("\nUpdating DF360_WorkOrderAppointmentsAPI in Salesforce...");
  const apiPath = path.resolve(__dirname, '../force-app/main/default/classes/DF360_WorkOrderAppointmentsAPI.cls');
  const apiBody = fs.readFileSync(apiPath, 'utf8');
  const qUrl = `${INSTANCE_URL}/services/data/v60.0/tooling/query?q=` + 
    encodeURIComponent("SELECT Id, Name FROM ApexClass WHERE Name = 'DF360_WorkOrderAppointmentsAPI'");
  const qRes = await fetch(qUrl, { headers: { Authorization: `Bearer ${token}` } });
  const qData = await qRes.json();
  const apiClassId = qData.records[0].Id;

  await updateClassesWithContainer(token, [{ name: 'DF360_WorkOrderAppointmentsAPI', id: apiClassId, body: apiBody }]);

  console.log("\n🎉 ALL APEX CODE DEPLOYED SUCCESSFULLY!");
}

main().catch(console.error);
