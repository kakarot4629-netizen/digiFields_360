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
  if (!res.ok) throw new Error('Auth failed: ' + JSON.stringify(data));
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
      ${metadataXmlChunks.join('\n')}
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

async function grantPermissions(auth, fieldNames) {
  console.log('\n🔒 Granting Field Permissions...');
  const headers = { Authorization: `Bearer ${auth.accessToken}`, 'Content-Type': 'application/json' };

  // Find permission sets to grant
  const psQuery = await fetch(`${auth.instanceUrl}/services/data/v60.0/query?q=` + encodeURIComponent("SELECT Id, Name FROM PermissionSet WHERE Name IN ('DF360_FSL_MultiResource_Admin', 'DF360_Technician', 'DF360_ServiceManager')"), { headers });
  const psData = await psQuery.json();
  if (!psData.records || psData.records.length === 0) {
    console.log('No specific PermissionSets found to grant.');
    return;
  }

  for (const ps of psData.records) {
    console.log(`Processing PermissionSet: ${ps.Name} (${ps.Id})`);
    for (const f of fieldNames) {
      const fpQuery = await fetch(`${auth.instanceUrl}/services/data/v60.0/query?q=` + encodeURIComponent(`SELECT Id FROM FieldPermissions WHERE ParentId = '${ps.Id}' AND SobjectType = 'Service_Job__c' AND Field = '${f}'`), { headers });
      const fpData = await fpQuery.json();
      if (fpData.records && fpData.records.length > 0) {
        console.log(`  Permissions already exist for ${f} in ${ps.Name}`);
      } else {
        const createRes = await fetch(`${auth.instanceUrl}/services/data/v60.0/sobjects/FieldPermissions`, {
          method: 'POST',
          headers,
          body: JSON.stringify({
            ParentId: ps.Id,
            SobjectType: 'Service_Job__c',
            Field: f,
            PermissionsRead: true,
            PermissionsEdit: true
          })
        });
        const cData = await createRes.json();
        console.log(`  Granted Read/Edit for ${f} in ${ps.Name}:`, cData.success || cData.id || cData);
      }
    }
  }
}

async function main() {
  console.log('🔐 Authenticating with Salesforce...');
  const auth = await getAuth();
  console.log('Connected to:', auth.instanceUrl);

  console.log('\n📦 Deploying Before/After Photo fields on Service_Job__c...');
  const fieldsXml = [
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Service_Job__c.Before_Photo_URL__c</met:fullName>
      <met:label>Before Photo URL</met:label>
      <met:type>Url</met:type>
      <met:description>Download/Public URL of the photo taken before service commences</met:description>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Service_Job__c.Before_Photo_Id__c</met:fullName>
      <met:label>Before Photo ID</met:label>
      <met:type>Text</met:type>
      <met:length>80</met:length>
      <met:description>ContentDocument or ContentVersion ID of Before photo</met:description>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Service_Job__c.Before_Photo_Timestamp__c</met:fullName>
      <met:label>Before Photo Timestamp</met:label>
      <met:type>DateTime</met:type>
      <met:description>Timestamp when Before photo was taken</met:description>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Service_Job__c.After_Photo_URL__c</met:fullName>
      <met:label>After Photo URL</met:label>
      <met:type>Url</met:type>
      <met:description>Download/Public URL of the photo taken after service completion</met:description>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Service_Job__c.After_Photo_Id__c</met:fullName>
      <met:label>After Photo ID</met:label>
      <met:type>Text</met:type>
      <met:length>80</met:length>
      <met:description>ContentDocument or ContentVersion ID of After photo</met:description>
    </met:metadata>`,
    `<met:metadata xsi:type="met:CustomField">
      <met:fullName>Service_Job__c.After_Photo_Timestamp__c</met:fullName>
      <met:label>After Photo Timestamp</met:label>
      <met:type>DateTime</met:type>
      <met:description>Timestamp when After photo was taken</met:description>
    </met:metadata>`
  ];

  const soapResp = await callMetadataSoap(auth, 'createMetadata', fieldsXml);
  const results = parseResult(soapResp);
  console.log('SOAP Deployment Results:');
  results.forEach(r => {
    console.log(` - ${r.fullName}: ${r.success ? 'SUCCESS' : 'FAILED: ' + r.message}`);
  });

  const fieldList = [
    'Service_Job__c.Before_Photo_URL__c',
    'Service_Job__c.Before_Photo_Id__c',
    'Service_Job__c.Before_Photo_Timestamp__c',
    'Service_Job__c.After_Photo_URL__c',
    'Service_Job__c.After_Photo_Id__c',
    'Service_Job__c.After_Photo_Timestamp__c'
  ];
  await grantPermissions(auth, fieldList);
  console.log('\n✅ Before and After photo fields deployed and permissions configured!');
}

main().catch(console.error);
