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

  const qRes = await fetch(process.env.SF_INSTANCE_URL + '/services/data/v60.0/query?q=' + 
    encodeURIComponent("SELECT Id, Name, Subject__c, Case__c, Case__r.CaseNumber, Case__r.Customer_Address__c, Case__r.Customer_Address__r.Name, Case__r.Customer_Address__r.City__c FROM Work_Order__c WHERE Id IN ('a03g500000mKkO1AAK', 'a03g500000mKkPdAAK')"), {
    headers: { Authorization: 'Bearer ' + token }
  });
  const data = await qRes.json();
  console.log("Direct SOQL on Work_Order__c:", JSON.stringify(data, null, 2));
}

run().catch(console.error);
