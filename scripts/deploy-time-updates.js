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
  return data.access_token;
}

async function deploy() {
  const token = await getAuth();
  console.log("Connected to org.");

  // 1. Deploy Class DF360_WorkOrderAppointmentsAPI
  console.log("Deploying DF360_WorkOrderAppointmentsAPI...");
  const classCode = fs.readFileSync(
    path.resolve(__dirname, "../force-app/main/default/classes/DF360_WorkOrderAppointmentsAPI.cls"),
    "utf8"
  );

  const containerName = "DeployTimes_" + Date.now();
  const cRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/MetadataContainer`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ Name: containerName })
  });
  const cData = await cRes.json();
  const containerId = cData.id;

  // Query Class ID
  const qClass = await (await fetch(
    `${INSTANCE_URL}/services/data/v60.0/tooling/query?q=` + encodeURIComponent("SELECT Id FROM ApexClass WHERE Name = 'DF360_WorkOrderAppointmentsAPI'"),
    { headers: { Authorization: `Bearer ${token}` } }
  )).json();
  const classId = qClass.records[0].Id;

  await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ApexClassMember`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      MetadataContainerId: containerId,
      ContentEntityId: classId,
      Body: classCode
    })
  });

  // Query Trigger ID
  const triggerCode = fs.readFileSync(
    path.resolve(__dirname, "../force-app/main/default/triggers/DF360_ServiceJobTrigger.trigger"),
    "utf8"
  );
  const qTrig = await (await fetch(
    `${INSTANCE_URL}/services/data/v60.0/tooling/query?q=` + encodeURIComponent("SELECT Id FROM ApexTrigger WHERE Name = 'DF360_ServiceJobTrigger'"),
    { headers: { Authorization: `Bearer ${token}` } }
  )).json();

  if (qTrig.records && qTrig.records.length > 0) {
    const triggerId = qTrig.records[0].Id;
    console.log("Found trigger ID:", triggerId);
    await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ApexTriggerMember`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        MetadataContainerId: containerId,
        ContentEntityId: triggerId,
        Body: triggerCode
      })
    });
  }

  // Request deployment
  const reqRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ContainerAsyncRequest`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      MetadataContainerId: containerId,
      IsCheckOnly: false
    })
  });
  const reqData = await reqRes.json();
  console.log("Async Request ID:", reqData.id);

  for (let i = 0; i < 25; i++) {
    await new Promise((r) => setTimeout(r, 1000));
    const statusRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ContainerAsyncRequest/${reqData.id}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    const statusData = await statusRes.json();
    console.log(`Polling (${i + 1}):`, statusData.State);
    if (statusData.State === "Completed") {
      console.log("🎉 SUCCESS: Class and Trigger deployed successfully!");
      return;
    } else if (statusData.State === "Failed" || statusData.State === "Error") {
      console.error("Deploy failed:", JSON.stringify(statusData, null, 2));
      return;
    }
  }
}

deploy().catch(console.error);
