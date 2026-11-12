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
  if (!res.ok) throw new Error("Auth failed: " + JSON.stringify(data));
  return {
    accessToken: data.access_token,
    instanceUrl: data.instance_url || INSTANCE_URL
  };
}

async function sfRequest(auth, endpoint, method = "GET", body = null) {
  const opts = {
    method,
    headers: {
      Authorization: `Bearer ${auth.accessToken}`,
      "Content-Type": "application/json"
    }
  };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(`${auth.instanceUrl}${endpoint}`, opts);
  if (res.status === 204) return { success: true };
  const json = await res.json();
  if (!res.ok) throw new Error(`HTTP ${res.status}: ` + JSON.stringify(json));
  return json;
}

async function main() {
  console.log("🔐 Authenticating with Salesforce...");
  const auth = await getAuth();
  console.log("Connected to instance:", auth.instanceUrl);

  // 1. Find Piyush's Work Orders
  const soql = "SELECT Id, Name, Subject__c, Account__c FROM Work_Order__c WHERE Assigned_Technician__r.Name LIKE '%Piyush%' ORDER BY CreatedDate DESC LIMIT 5";
  const woRes = await sfRequest(auth, "/services/data/v60.0/query?q=" + encodeURIComponent(soql));
  console.log(`Found ${woRes.records.length} Work Orders assigned to Piyush.`);

  const woB = woRes.records.find((r) => r.Subject__c && r.Subject__c.includes("WO-B")) || woRes.records[0];
  const woA = woRes.records.find((r) => r.Subject__c && r.Subject__c.includes("WO-A")) || woRes.records[1];

  console.log(`WO-A: ${woA.Name} (${woA.Id}) - ${woA.Subject__c}`);
  console.log(`WO-B: ${woB.Name} (${woB.Id}) - ${woB.Subject__c}`);

  // 2. Create Customer_Address__c Record 1 for WO-A
  console.log("\n📍 Creating Customer Address #1 (Gurgaon Site)...");
  const addr1 = await sfRequest(auth, "/services/data/v60.0/sobjects/Customer_Address__c", "POST", {
    Account__c: woA.Account__c,
    Address_Type__c: "Commercial Site / Branch",
    Street_Address__c: "Building B, Cyber City, Sector 29",
    City__c: "Gurgaon",
    State__c: "Haryana",
    Postal_Code__c: "122002",
    Country__c: "India",
    Landmark__c: "Near IFFCO Chowk Metro Station",
    Contact_Person_Name__c: "Vikram Malhotra (Facility Operations Lead)",
    Contact_Phone__c: "+91-9820198765",
    Is_Default__c: true
  });
  console.log(`✅ Customer Address #1 Created: ${addr1.id}`);

  // 3. Create Case Record 1 for WO-A
  console.log("\n📁 Creating Case #1 with Service Address lookup...");
  const case1 = await sfRequest(auth, "/services/data/v60.0/sobjects/Case", "POST", {
    Subject: "Chilled Water Loop Overheat & Delta-T Anomaly - Unit #4",
    Status: "Working",
    Priority: "High",
    Origin: "Phone",
    AccountId: woA.Account__c,
    Customer_Address__c: addr1.id
  });
  console.log(`✅ Case #1 Created: ${case1.id}`);

  // 4. Link Case 1 to WO-A
  await sfRequest(auth, `/services/data/v60.0/sobjects/Work_Order__c/${woA.Id}`, "PATCH", {
    Case__c: case1.id
  });
  console.log(`🔗 Linked Case #1 to Work Order WO-A (${woA.Id})`);

  // 5. Create Customer_Address__c Record 2 for WO-B
  console.log("\n📍 Creating Customer Address #2 (Mumbai Substation)...");
  const addr2 = await sfRequest(auth, "/services/data/v60.0/sobjects/Customer_Address__c", "POST", {
    Account__c: woB.Account__c,
    Address_Type__c: "Commercial Site / Branch",
    Street_Address__c: "Plot 45, MIDC Phase 2, Central Road",
    City__c: "Mumbai",
    State__c: "Maharashtra",
    Postal_Code__c: "400093",
    Country__c: "India",
    Landmark__c: "Opposite SEEPZ Gate No. 3, Andheri East",
    Contact_Person_Name__c: "Anil Deshmukh (Substation Chief Engineer)",
    Contact_Phone__c: "+91-9820234567",
    Is_Default__c: true
  });
  console.log(`✅ Customer Address #2 Created: ${addr2.id}`);

  // 6. Create Case Record 2 for WO-B
  console.log("\n📁 Creating Case #2 with Service Address lookup...");
  const case2 = await sfRequest(auth, "/services/data/v60.0/sobjects/Case", "POST", {
    Subject: "Scheduled Preventive Maintenance: 33kV Substation Bushing & Oil DGA",
    Status: "New",
    Priority: "Medium",
    Origin: "Phone",
    AccountId: woB.Account__c,
    Customer_Address__c: addr2.id
  });
  console.log(`✅ Case #2 Created: ${case2.id}`);

  // 7. Link Case 2 to WO-B
  await sfRequest(auth, `/services/data/v60.0/sobjects/Work_Order__c/${woB.Id}`, "PATCH", {
    Case__c: case2.id
  });
  console.log(`🔗 Linked Case #2 to Work Order WO-B (${woB.Id})`);

  console.log("\n🎉 ALL ADDRESS & CASE RECORDS CREATED AND LINKED TO PIYUSH'S WORK ORDERS!");
}

main().catch(console.error);
