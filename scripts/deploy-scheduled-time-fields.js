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

async function callMetadataSoap(auth, action, metadataXmlChunks) {
  const soapBody = `<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:met="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soapenv:Header>
    <met:SessionHeader>
      <met:sessionId>${auth.accessToken}</met:sessionId>
    </met:SessionHeader>
  </soapenv:Header>
  <soapenv:Body>
    <met:${action}>
      ${metadataXmlChunks.join("\n")}
    </met:${action}>
  </soapenv:Body>
</soapenv:Envelope>`;

  const sRes = await fetch(`${auth.instanceUrl}/services/Soap/m/60.0`, {
    method: "POST",
    headers: {
      "Content-Type": "text/xml",
      SOAPAction: action
    },
    body: soapBody
  });
  const sText = await sRes.text();
  return sText;
}

function parseResult(responseXml) {
  const results = [];
  const regex = /<result>([\s\S]*?)<\/result>/g;
  let match;
  while ((match = regex.exec(responseXml)) !== null) {
    const chunk = match[1];
    const nameMatch = /<fullName>(.*?)<\/fullName>/.exec(chunk);
    const successMatch = /<success>(.*?)<\/success>/.exec(chunk);
    const errorMatch = /<message>(.*?)<\/message>/.exec(chunk);
    results.push({
      fullName: nameMatch ? nameMatch[1] : "unknown",
      success: successMatch ? successMatch[1] === "true" : false,
      message: errorMatch ? errorMatch[1] : ""
    });
  }
  return results;
}

async function grantPermissions(auth) {
  console.log("\n🔒 Granting Field Permissions...");
  const headers = { Authorization: `Bearer ${auth.accessToken}`, "Content-Type": "application/json" };
  
  // Find or create PermissionSet
  const psQuery = await fetch(`${auth.instanceUrl}/services/data/v60.0/query?q=` + encodeURIComponent("SELECT Id FROM PermissionSet WHERE Name = 'DF360_FSL_MultiResource_Admin'"), { headers });
  const psData = await psQuery.json();
  if (!psData.records || psData.records.length === 0) {
    console.log("PermissionSet DF360_FSL_MultiResource_Admin not found, skipping specific PS grant.");
    return;
  }
  const psId = psData.records[0].Id;
  console.log("Found PermissionSet ID:", psId);

  const fields = [
    "Service_Job__c.Scheduled_Start_Time__c",
    "Service_Job__c.Scheduled_End_Time__c",
    "Service_Job__c.Check_In_Time__c",
    "Service_Job__c.Completed_Time__c",
    "Service_Job__c.Resolution_Time_Min__c"
  ];

  for (const f of fields) {
    const fpQuery = await fetch(`${auth.instanceUrl}/services/data/v60.0/query?q=` + encodeURIComponent(`SELECT Id, PermissionsRead, PermissionsEdit FROM FieldPermissions WHERE ParentId = '${psId}' AND SobjectType = 'Service_Job__c' AND Field = '${f}'`), { headers });
    const fpData = await fpQuery.json();
    if (fpData.records && fpData.records.length > 0) {
      console.log(`  Permissions already exist for ${f}`);
    } else {
      const createRes = await fetch(`${auth.instanceUrl}/services/data/v60.0/sobjects/FieldPermissions`, {
        method: "POST",
        headers,
        body: JSON.stringify({
          ParentId: psId,
          SobjectType: "Service_Job__c",
          Field: f,
          PermissionsRead: true,
          PermissionsEdit: true
        })
      });
      const cData = await createRes.json();
      console.log(`  Granted Read/Edit for ${f}:`, cData.success || cData.id || cData);
    }
  }
}

async function main() {
  console.log("🔐 Authenticating with Salesforce...");
  const auth = await getAuth();
  console.log("Connected to:", auth.instanceUrl);

  console.log("\n📦 Deploying Scheduled_Start_Time__c and Scheduled_End_Time__c fields to Service_Job__c...");
  const fieldsXml = [
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Service_Job__c.Scheduled_Start_Time__c</met:fullName>
      <met:label>Scheduled Start Time</met:label>
      <met:description>Planned appointment start date and time.</met:description>
      <met:type>DateTime</met:type>
      <met:required>false</met:required>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Service_Job__c.Scheduled_End_Time__c</met:fullName>
      <met:label>Scheduled End Time</met:label>
      <met:description>Planned appointment end date and time.</met:description>
      <met:type>DateTime</met:type>
      <met:required>false</met:required>
    </met:metadata>`
  ];

  const xml = await callMetadataSoap(auth, "createMetadata", fieldsXml);
  const results = parseResult(xml);
  results.forEach(r => console.log(`  ${r.success ? "✅" : "ℹ️"} ${r.fullName}: ${r.success ? "Created" : r.message}`));

  await grantPermissions(auth);
  console.log("\n🎉 Deployment completed successfully!");
}

main().catch(console.error);
