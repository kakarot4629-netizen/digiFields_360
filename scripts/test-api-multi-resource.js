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

async function testEndpoint(endpoint, desc) {
  const token = await getAuth();
  console.log(`\n========================================`);
  console.log(`Testing: ${desc}`);
  console.log(`URL: ${INSTANCE_URL}${endpoint}`);
  console.log(`========================================`);

  const res = await fetch(`${INSTANCE_URL}${endpoint}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const data = await res.json();
  console.log(`Status Code: ${res.status}`);
  console.log(`Success: ${data.success}, Count: ${data.count}`);
  
  if (data.workOrders && data.workOrders.length > 0) {
    data.workOrders.forEach((wo, wIdx) => {
      const woDetails = wo.workOrder || wo;
      if (woDetails.case && woDetails.case.serviceAddress) {
        const addr = woDetails.case.serviceAddress;
        console.log(`   📍 Address: ${addr.name} (${addr.city}) - ${addr.streetAddress}`);
        console.log(`      Contact: ${addr.contactPerson} (${addr.contactPhone})`);
      }
      console.log(`   📅 Service Appointments (${wo.serviceAppointments ? wo.serviceAppointments.length : 0}):`);
      if (wo.serviceAppointments) {
        wo.serviceAppointments.forEach((sa, sIdx) => {
          console.log(`      (${sIdx + 1}) ${sa.name} [${sa.status}] - Tech: ${sa.technician ? sa.technician.name : 'Unassigned'}`);
          if (sa.assignedTeam && sa.assignedTeam.length > 0) {
            console.log(`          👥 Assigned Team (${sa.assignedTeam.length}):`);
            sa.assignedTeam.forEach(member => {
              const techName = member.technician ? member.technician.name : 'N/A';
              const crewName = member.crew ? ` (Crew: ${member.crew.name})` : '';
              console.log(`             • ${techName} [${member.role}] - IsLeader: ${member.isLeader}${crewName}`);
            });
          }
        });
      }
    });
  } else {
    console.log("No work orders found.");
  }
}

async function main() {
  // Test 1: All appointments for logged in technician
  await testEndpoint('/services/apexrest/df360/v1/work-orders/my', 'GET /df360/v1/work-orders/my (All Statuses)');

  // Test 2: Filter by status=Assigned
  await testEndpoint('/services/apexrest/df360/v1/work-orders/my?status=Assigned', 'GET /df360/v1/work-orders/my?status=Assigned');
}

main().catch(console.error);
