/**
 * Instant Live Salesforce Login Tester
 * Run: node scripts/test-live-login.js
 */

async function testLogin(username, password, label) {
  const url = "https://digifields-360.onrender.com/api/auth/login";
  console.log(`\n------------------------------------------------------------`);
  console.log(`▶ Testing: ${label}`);
  console.log(`  POST ${url}`);
  console.log(`  Username: ${username}`);
  console.log(`  Password: ${password ? password.substring(0, 3) + '***' : ''}`);

  const start = Date.now();
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username, password })
    });

    const elapsed = Date.now() - start;
    const data = await res.json();

    console.log(`  Status: ${res.status} ${res.statusText} (${elapsed}ms)`);
    if (res.ok) {
      console.log(`  ✅ SUCCESS!`);
      console.log(`  Token Type: ${data.tokenType} (Real 00D Token: ${data.token?.startsWith('00D')})`);
      console.log(`  Token (first 30 chars): ${data.token?.substring(0, 30)}...`);
      console.log(`  Technician Name: ${data.technician?.name}`);
      console.log(`  Technician ID: ${data.technician?.id}`);
      console.log(`  Skills: ${JSON.stringify(data.technician?.skills)}`);
      console.log(`  First Time Fix Rate: ${data.technician?.firstTimeFixRate}%`);
    } else {
      console.log(`  ❌ REJECTED as expected:`);
      console.log(`  Error: ${data.error}`);
      console.log(`  Code: ${data.code}`);
    }
  } catch (err) {
    console.error(`  ⚠️ Network Error: ${err.message}`);
  }
}

async function main() {
  console.log("════════════════════════════════════════════════════════════");
  console.log("🚀 digiField360.ai — Real-Time Salesforce Login Test Suite");
  console.log("════════════════════════════════════════════════════════════");

  // 1. Valid Live Salesforce Login
  await testLogin(
    "piyush.channe.3868c7575da5@agentforce.com",
    "Dhanashree@123",
    "1. VALID LIVE SALESFORCE CREDENTIALS"
  );

  // 2. Wrong Password
  await testLogin(
    "piyush.channe.3868c7575da5@agentforce.com",
    "WRONG_PASS_999",
    "2. WRONG PASSWORD (EXPECT 401)"
  );

  // 3. Unknown User
  await testLogin(
    "fake.user@example.com",
    "YOUR_PASSWORD_HERE",
    "3. UNKNOWN USER (EXPECT 401)"
  );

  console.log(`\n════════════════════════════════════════════════════════════\n`);
}

main();
