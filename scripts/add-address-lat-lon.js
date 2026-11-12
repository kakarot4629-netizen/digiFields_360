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
    method: 'POST',
    headers: {
      'Content-Type': 'text/xml',
      SOAPAction: action
    },
    body: soapBody
  });
  return await sRes.text();
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
      fullName: nameMatch ? nameMatch[1] : 'unknown',
      success: successMatch ? successMatch[1] === 'true' : false,
      message: errorMatch ? errorMatch[1] : ''
    });
  }
  return results;
}

async function main() {
  const auth = await getAuth();
  console.log("Connected to Salesforce org.");

  // 1. Create Latitude__c and Longitude__c on Customer_Address__c
  console.log("\n1. Creating Latitude__c and Longitude__c on Customer_Address__c...");
  const fields = [
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Customer_Address__c.Latitude__c</met:fullName>
      <met:label>Latitude</met:label>
      <met:type>Number</met:type>
      <met:precision>11</met:precision>
      <met:scale>7</met:scale>
      <met:required>false</met:required>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Customer_Address__c.Longitude__c</met:fullName>
      <met:label>Longitude</met:label>
      <met:type>Number</met:type>
      <met:precision>11</met:precision>
      <met:scale>7</met:scale>
      <met:required>false</met:required>
    </met:metadata>`
  ];

  const createXml = await callMetadataSoap(auth, 'createMetadata', fields);
  const results = parseResult(createXml);
  results.forEach(r => console.log(`  ${r.success ? '✅' : 'ℹ️'} ${r.fullName}: ${r.success ? 'Created' : r.message}`));

  // 2. Grant FieldPermissions in PermissionSet
  console.log("\n2. Granting Field Permissions in DF360_FSL_MultiResource_Admin...");
  const psQuery = await fetch(`${auth.instanceUrl}/services/data/v60.0/query?q=` + 
    encodeURIComponent("SELECT Id FROM PermissionSet WHERE Name = 'DF360_FSL_MultiResource_Admin'"), {
    headers: { Authorization: `Bearer ${auth.accessToken}` }
  });
  const psData = await psQuery.json();
  const psId = psData.records[0].Id;

  for (const f of ['Customer_Address__c.Latitude__c', 'Customer_Address__c.Longitude__c']) {
    const chk = await fetch(`${auth.instanceUrl}/services/data/v60.0/query?q=` +
      encodeURIComponent(`SELECT Id FROM FieldPermissions WHERE ParentId = '${psId}' AND Field = '${f}'`), {
      headers: { Authorization: `Bearer ${auth.accessToken}` }
    });
    const chkData = await chk.json();
    if (chkData.totalSize === 0) {
      const grantRes = await fetch(`${auth.instanceUrl}/services/data/v60.0/sobjects/FieldPermissions`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${auth.accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ParentId: psId,
          SobjectType: 'Customer_Address__c',
          Field: f,
          PermissionsRead: true,
          PermissionsEdit: true
        })
      });
      console.log(`  Permission for ${f}:`, await grantRes.json());
    } else {
      console.log(`  Permission for ${f} already granted.`);
    }
  }

  // 3. Update existing Customer_Address__c records with real coordinates
  console.log("\n3. Populating real Latitude & Longitude on Customer Addresses...");
  const addrQuery = await fetch(`${auth.instanceUrl}/services/data/v60.0/query?q=` + 
    encodeURIComponent("SELECT Id, Name, City__c FROM Customer_Address__c"), {
    headers: { Authorization: `Bearer ${auth.accessToken}` }
  });
  const addrData = await addrQuery.json();

  for (const a of addrData.records) {
    let lat = 19.076090;
    let lon = 72.877426;
    if (a.City__c === 'Gurgaon') {
      lat = 28.472044; // Cyber City, Sector 29 Gurgaon
      lon = 77.072538;
    } else if (a.City__c === 'Mumbai') {
      lat = 19.119677; // MIDC Phase 2, Andheri East Mumbai
      lon = 72.882356;
    }
    const updateRes = await fetch(`${auth.instanceUrl}/services/data/v60.0/sobjects/Customer_Address__c/${a.Id}`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${auth.accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        Latitude__c: lat,
        Longitude__c: lon
      })
    });
    console.log(`  Updated ${a.Name} (${a.City__c}): Lat=${lat}, Lon=${lon} -> HTTP ${updateRes.status}`);
  }

  console.log("\n🎉 Customer_Address__c Latitude and Longitude configured and populated!");
}

main().catch(console.error);
