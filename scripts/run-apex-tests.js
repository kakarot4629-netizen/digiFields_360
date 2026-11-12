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
  return data.access_token;
}

async function runTests(testClassNames) {
  const token = await getAuth();
  console.log("Getting class IDs for:", testClassNames.join(", "));

  const namesList = testClassNames.map(n => `'${n}'`).join(",");
  const qUrl = `${INSTANCE_URL}/services/data/v60.0/tooling/query?q=` + 
    encodeURIComponent(`SELECT Id, Name FROM ApexClass WHERE Name IN (${namesList})`);
  const qRes = await fetch(qUrl, { headers: { Authorization: `Bearer ${token}` } });
  const qData = await qRes.json();
  const classIds = qData.records.map(r => r.Id);
  console.log("Found class IDs:", classIds);

  const testRes = await fetch(`${INSTANCE_URL}/services/data/v60.0/tooling/runTestsSynchronous/`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      tests: classIds.map(id => ({ classId: id }))
    })
  });
  const testResult = await testRes.json();
  console.log("\n--- TEST RUN SUMMARY ---");
  console.log("Num Tests Run:", testResult.numTestsRun);
  console.log("Num Failures:", testResult.numFailures);
  console.log("Total Time:", testResult.totalTime, "ms");

  if (testResult.successes && testResult.successes.length > 0) {
    console.log("\n✅ SUCCESSES:");
    testResult.successes.forEach(s => console.log(`  - ${s.name}.${s.methodName} (${s.time}ms)`));
  }

  if (testResult.failures && testResult.failures.length > 0) {
    console.log("\n❌ FAILURES:");
    testResult.failures.forEach(f => {
      console.log(`  - ${f.name}.${f.methodName}: ${f.message}`);
      console.log(`    Stack: ${f.stackTrace}`);
    });
  }
}

runTests(["DF360_AssignedResourceTriggerHandlerTest", "DF360_WorkOrderAppointmentsAPITest"]).catch(console.error);
