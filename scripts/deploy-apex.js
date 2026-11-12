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
  return data.access_token;
}

async function deployClasses(classNames) {
  const token = await getAuth();

  // Create MetadataContainer
  const containerName = "Deploy_" + Date.now();
  const cRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/MetadataContainer`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ Name: containerName })
  });
  const cData = await cRes.json();
  const containerId = cData.id;
  console.log("Container ID:", containerId);

  for (const name of classNames) {
    const filePath = path.resolve(__dirname, `../force-app/main/default/classes/${name}.cls`);
    const code = fs.readFileSync(filePath, "utf8");

    const qUrl = `${INSTANCE_URL}/services/data/v60.0/tooling/query?q=` + encodeURIComponent(`SELECT Id, Name FROM ApexClass WHERE Name = '${name}'`);
    const qRes = await fetch(qUrl, { headers: { Authorization: `Bearer ${token}` } });
    const qData = await qRes.json();
    const classId = qData.records[0].Id;

    const memberRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ApexClassMember`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        MetadataContainerId: containerId,
        ContentEntityId: classId,
        Body: code
      })
    });
    const memberData = await memberRes.json();
    console.log(`Member for ${name}:`, memberData.id);
  }

  // Create ContainerAsyncRequest
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

  // Poll for completion
  for (let i = 0; i < 20; i++) {
    await new Promise((r) => setTimeout(r, 1000));
    const statusRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ContainerAsyncRequest/${requestId}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    const statusData = await statusRes.json();
    console.log("Status:", statusData.State);
    if (statusData.State === "Completed") {
      console.log("🚀 ALL CLASSES DEPLOYED SUCCESSFULLY!");
      return;
    } else if (statusData.State === "Failed" || statusData.State === "Error") {
      console.error("Deploy failed raw statusData:", JSON.stringify(statusData, null, 2));
      return;
    }
  }
}

deployClasses(["DF360_WorkOrderAppointmentsAPI", "DF360_WorkOrderAppointmentsAPITest"]).catch(console.error);
