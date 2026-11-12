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

async function deployOrUpdateClass(token, className) {
  const filePath = path.resolve(__dirname, `../force-app/main/default/classes/${className}.cls`);
  const classBody = fs.readFileSync(filePath, "utf8");

  const qUrl = `${INSTANCE_URL}/services/data/v60.0/tooling/query?q=` + 
    encodeURIComponent(`SELECT Id, Name FROM ApexClass WHERE Name = '${className}'`);
  const qRes = await fetch(qUrl, { headers: { Authorization: `Bearer ${token}` } });
  const qData = await qRes.json();

  if (qData.totalSize === 0) {
    console.log(`Creating new ApexClass: ${className}...`);
    const cRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ApexClass`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        Name: className,
        Body: classBody
      })
    });
    const cData = await cRes.json();
    if (!cRes.ok) {
      throw new Error(`Failed to create ${className}: ` + JSON.stringify(cData));
    }
    console.log(`Created ${className} with ID:`, cData.id);
    return cData.id;
  } else {
    console.log(`Class ${className} exists (${qData.records[0].Id}), updating via MetadataContainer...`);
    const classId = qData.records[0].Id;

    const containerName = "Deploy_" + Date.now();
    const cRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/MetadataContainer`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ Name: containerName })
    });
    const containerId = (await cRes.json()).id;

    await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ApexClassMember`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        MetadataContainerId: containerId,
        ContentEntityId: classId,
        Body: classBody
      })
    });

    const reqRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ContainerAsyncRequest`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ MetadataContainerId: containerId, IsCheckOnly: false })
    });
    const requestId = (await reqRes.json()).id;

    for (let i = 0; i < 20; i++) {
      await new Promise((r) => setTimeout(r, 1000));
      const sRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ContainerAsyncRequest/${requestId}`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      const sData = await sRes.json();
      if (sData.State === "Completed") {
        console.log(`Updated ${className} successfully!`);
        return classId;
      } else if (sData.State === "Failed" || sData.State === "Error") {
        throw new Error(`Deploy failed for ${className}: ` + JSON.stringify(sData));
      }
    }
  }
}

async function main() {
  const token = await getAuth();
  console.log("Connected to org.");

  await deployOrUpdateClass(token, "DF360_AppointmentLifecycleAPI");
  await deployOrUpdateClass(token, "DF360_AppointmentLifecycleAPITest");
  console.log("🎉 All Check-In API classes deployed successfully!");
}

main().catch(console.error);
