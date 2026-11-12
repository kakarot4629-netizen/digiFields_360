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

async function run() {
  const params = new URLSearchParams({
    grant_type: 'refresh_token',
    client_id: process.env.SF_CLIENT_ID || 'PlatformCLI',
    refresh_token: process.env.SF_REFRESH_TOKEN
  });
  const res = await fetch(process.env.SF_INSTANCE_URL + '/services/oauth2/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString()
  });
  const auth = await res.json();
  const token = auth.access_token;

  // Query CustomObject
  const objUrl = `${process.env.SF_INSTANCE_URL}/services/data/v60.0/tooling/query?q=` + 
    encodeURIComponent("SELECT Id, DeveloperName FROM CustomObject WHERE DeveloperName IN ('Assigned_Resource', 'Service_Crew', 'Service_Crew_Member')");
  const objRes = await fetch(objUrl, { headers: { Authorization: `Bearer ${token}` } });
  const objData = await objRes.json();
  console.log('CustomObjects:', objData.records);

  for (const obj of objData.records) {
    const fUrl = `${process.env.SF_INSTANCE_URL}/services/data/v60.0/tooling/query?q=` +
      encodeURIComponent(`SELECT Id, DeveloperName, TableEnumOrId FROM CustomField WHERE TableEnumOrId = '${obj.Id}'`);
    const fRes = await fetch(fUrl, { headers: { Authorization: `Bearer ${token}` } });
    const fData = await fRes.json();
    console.log(`Fields for ${obj.DeveloperName} (${obj.Id}):`, fData.records ? fData.records.map(r => r.DeveloperName) : fData);
  }
}

run().catch(console.error);
