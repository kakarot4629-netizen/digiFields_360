const fs = require('fs');
const path = require('path');

function loadEnv() {
  const envPath = path.resolve(__dirname, '../.env');
  if (fs.existsSync(envPath)) {
    const lines = fs.readFileSync(envPath, 'utf8').split('\n');
    lines.forEach((l) => {
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
  return await res.json();
}

async function updateExistingClasses(token, classNames) {
  const containerName = 'Deploy_' + Date.now();
  const cRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/MetadataContainer`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ Name: containerName })
  });
  const containerId = (await cRes.json()).id;

  for (const name of classNames) {
    const filePath = path.resolve(__dirname, `../force-app/main/default/classes/${name}.cls`);
    const code = fs.readFileSync(filePath, 'utf8');
    const qUrl = `${INSTANCE_URL}/services/data/v60.0/tooling/query?q=` + 
      encodeURIComponent(`SELECT Id FROM ApexClass WHERE Name = '${name}'`);
    const qData = await (await fetch(qUrl, { headers: { Authorization: `Bearer ${token}` } })).json();
    const classId = qData.records[0].Id;

    await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ApexClassMember`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        MetadataContainerId: containerId,
        ContentEntityId: classId,
        Body: code
      })
    });
  }

  const reqRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ContainerAsyncRequest`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ MetadataContainerId: containerId, IsCheckOnly: false })
  });
  const requestId = (await reqRes.json()).id;

  while (true) {
    await new Promise(r => setTimeout(r, 2000));
    const statusRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/sobjects/ContainerAsyncRequest/${requestId}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    const statusData = await statusRes.json();
    console.log('Deploy Status:', statusData.State);
    if (statusData.State === 'Completed') {
      return true;
    } else if (statusData.State === 'Failed') {
      console.error('Compiler Errors:', JSON.stringify(statusData.CompilerErrors, null, 2));
      console.error('Error Msg:', statusData.ErrorMsg);
      throw new Error('Deployment failed');
    }
  }
}

(async () => {
  try {
    const auth = await getAuth();
    console.log('Connected to Salesforce.');
    console.log('Deploying updated DF360_AppointmentLifecycleAPI, DF360_AppointmentLifecycleAPITest, and DF360_WorkOrderAppointmentsAPI...');
    await updateExistingClasses(auth.access_token, [
      'DF360_AppointmentLifecycleAPI',
      'DF360_AppointmentLifecycleAPITest',
      'DF360_WorkOrderAppointmentsAPI'
    ]);
    console.log('✅ Successfully deployed all classes!');
  } catch (err) {
    console.error('Deployment error:', err.message);
    process.exit(1);
  }
})();
