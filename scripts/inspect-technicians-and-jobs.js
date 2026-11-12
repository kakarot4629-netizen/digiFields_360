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

async function getAuth() {
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
  const data = await res.json();
  return data.access_token;
}

async function run() {
  const token = await getAuth();

  // Query Technicians
  const tRes = await fetch(process.env.SF_INSTANCE_URL + '/services/data/v60.0/query?q=' + 
    encodeURIComponent('SELECT Id, Name, Technician_Name__c, Zone__c, Zone__r.Zone_Name__c, User__c FROM Technician__c LIMIT 10'), {
    headers: { Authorization: 'Bearer ' + token }
  });
  const tData = await tRes.json();
  console.log('Technicians:', tData.records);

  // Query Piyush Service Appointments
  const jRes = await fetch(process.env.SF_INSTANCE_URL + '/services/data/v60.0/query?q=' + 
    encodeURIComponent("SELECT Id, Name, Status__c, Work_Order__c, Work_Order__r.Name, Work_Order__r.Subject__c FROM Service_Job__c WHERE Technician__c = 'a02g500000Bvf9mAAB' ORDER BY CreatedDate DESC LIMIT 10"), {
    headers: { Authorization: 'Bearer ' + token }
  });
  const jData = await jRes.json();
  console.log('Piyush Appointments:', jData.records);
}

run().catch(console.error);
