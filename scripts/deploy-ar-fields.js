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

async function main() {
  const auth = await getAuth();

  console.log("Creating fields for Assigned_Resource__c in chunks of 5...");

  const arFields = [
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Assigned_Resource__c.Service_Job__c</met:fullName>
      <met:label>Service Appointment</met:label>
      <met:type>Lookup</met:type>
      <met:referenceTo>Service_Job__c</met:referenceTo>
      <met:relationshipName>Assigned_Resources</met:relationshipName>
      <met:relationshipLabel>Assigned Resources</met:relationshipLabel>
      <met:deleteConstraint>SetNull</met:deleteConstraint>
      <met:required>false</met:required>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Assigned_Resource__c.Technician__c</met:fullName>
      <met:label>Technician</met:label>
      <met:type>Lookup</met:type>
      <met:referenceTo>Technician__c</met:referenceTo>
      <met:relationshipName>Assigned_Resources</met:relationshipName>
      <met:relationshipLabel>Assigned Resources</met:relationshipLabel>
      <met:deleteConstraint>SetNull</met:deleteConstraint>
      <met:required>false</met:required>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Assigned_Resource__c.Service_Crew__c</met:fullName>
      <met:label>Service Crew</met:label>
      <met:type>Lookup</met:type>
      <met:referenceTo>Service_Crew__c</met:referenceTo>
      <met:relationshipName>Assigned_Resources</met:relationshipName>
      <met:relationshipLabel>Assigned Resources</met:relationshipLabel>
      <met:deleteConstraint>SetNull</met:deleteConstraint>
      <met:required>false</met:required>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Assigned_Resource__c.Resource_Type__c</met:fullName>
      <met:label>Resource Type</met:label>
      <met:type>Picklist</met:type>
      <met:valueSet>
        <met:valueSetDefinition>
          <met:sorted>false</met:sorted>
          <met:value><met:fullName>Technician</met:fullName><met:default>true</met:default><met:label>Technician</met:label></met:value>
          <met:value><met:fullName>Crew</met:fullName><met:default>false</met:default><met:label>Crew</met:label></met:value>
          <met:value><met:fullName>Equipment</met:fullName><met:default>false</met:default><met:label>Equipment</met:label></met:value>
        </met:valueSetDefinition>
      </met:valueSet>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Assigned_Resource__c.Role__c</met:fullName>
      <met:label>Role</met:label>
      <met:type>Picklist</met:type>
      <met:valueSet>
        <met:valueSetDefinition>
          <met:sorted>false</met:sorted>
          <met:value><met:fullName>Lead Technician</met:fullName><met:default>true</met:default><met:label>Lead Technician</met:label></met:value>
          <met:value><met:fullName>Crew Member</met:fullName><met:default>false</met:default><met:label>Crew Member</met:label></met:value>
          <met:value><met:fullName>Safety Specialist</met:fullName><met:default>false</met:default><met:label>Safety Specialist</met:label></met:value>
          <met:value><met:fullName>Apprentice</met:fullName><met:default>false</met:default><met:label>Apprentice</met:label></met:value>
        </met:valueSetDefinition>
      </met:valueSet>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Assigned_Resource__c.Is_Leader__c</met:fullName>
      <met:label>Is Leader</met:label>
      <met:type>Checkbox</met:type>
      <met:defaultValue>false</met:defaultValue>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Assigned_Resource__c.Status__c</met:fullName>
      <met:label>Status</met:label>
      <met:type>Picklist</met:type>
      <met:valueSet>
        <met:valueSetDefinition>
          <met:sorted>false</met:sorted>
          <met:value><met:fullName>Assigned</met:fullName><met:default>true</met:default><met:label>Assigned</met:label></met:value>
          <met:value><met:fullName>En Route</met:fullName><met:default>false</met:default><met:label>En Route</met:label></met:value>
          <met:value><met:fullName>On Site</met:fullName><met:default>false</met:default><met:label>On Site</met:label></met:value>
          <met:value><met:fullName>Completed</met:fullName><met:default>false</met:default><met:label>Completed</met:label></met:value>
          <met:value><met:fullName>Cancelled</met:fullName><met:default>false</met:default><met:label>Cancelled</met:label></met:value>
        </met:valueSetDefinition>
      </met:valueSet>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Assigned_Resource__c.Check_In_Time__c</met:fullName>
      <met:label>Check-In Time</met:label>
      <met:type>DateTime</met:type>
      <met:required>false</met:required>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Assigned_Resource__c.Completed_Time__c</met:fullName>
      <met:label>Completed Time</met:label>
      <met:type>DateTime</met:type>
      <met:required>false</met:required>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Assigned_Resource__c.Actual_Hours__c</met:fullName>
      <met:label>Actual Hours</met:label>
      <met:type>Number</met:type>
      <met:precision>4</met:precision>
      <met:scale>2</met:scale>
      <met:required>false</met:required>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Assigned_Resource__c.Notes__c</met:fullName>
      <met:label>Notes</met:label>
      <met:type>LongTextArea</met:type>
      <met:length>32768</met:length>
      <met:visibleLines>3</met:visibleLines>
      <met:required>false</met:required>
    </met:metadata>`
  ];

  for (let i = 0; i < arFields.length; i += 4) {
    const chunk = arFields.slice(i, i + 4);
    const xml = await callMetadataSoap(auth, "createMetadata", chunk);
    const res = parseResult(xml);
    res.forEach((r) => console.log(`  ${r.success ? "✅" : "ℹ️"} ${r.fullName}: ${r.success ? "Created" : r.message}`));
  }
  console.log("Done!");
}

main().catch(console.error);
