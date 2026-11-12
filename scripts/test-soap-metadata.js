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
  return {
    accessToken: data.access_token,
    instanceUrl: data.instance_url || INSTANCE_URL
  };
}

async function run() {
  const auth = await getAuth();

  const soapBody = `<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:met="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soapenv:Header>
    <met:SessionHeader>
      <met:sessionId>${auth.accessToken}</met:sessionId>
    </met:SessionHeader>
  </soapenv:Header>
  <soapenv:Body>
    <met:createMetadata>
      <met:metadata xsi:type="met:CustomObject">
        <met:fullName>Service_Crew__c</met:fullName>
        <met:label>Service Crew</met:label>
        <met:pluralLabel>Service Crews</met:pluralLabel>
        <met:nameField>
          <met:type>Text</met:type>
          <met:label>Crew Name</met:label>
        </met:nameField>
        <met:deploymentStatus>Deployed</met:deploymentStatus>
        <met:sharingModel>ReadWrite</met:sharingModel>
      </met:metadata>
    </met:createMetadata>
  </soapenv:Body>
</soapenv:Envelope>`;

  const sRes = await fetch(`${auth.instanceUrl}/services/Soap/m/60.0`, {
    method: "POST",
    headers: {
      "Content-Type": "text/xml",
      SOAPAction: "createMetadata"
    },
    body: soapBody
  });
  const sText = await sRes.text();
  console.log("Response:", sText);
}

run().catch(console.error);
