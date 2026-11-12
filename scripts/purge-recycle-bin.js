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

async function getAuth() {
  const params = new URLSearchParams({
    grant_type: "refresh_token",
    client_id: process.env.SF_CLIENT_ID || "PlatformCLI",
    refresh_token: process.env.SF_REFRESH_TOKEN
  });
  const res = await fetch(`${process.env.SF_INSTANCE_URL}/services/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params.toString()
  });
  return await res.json();
}

async function executeApex(auth, apexCode) {
  const url = `${process.env.SF_INSTANCE_URL}/services/data/v60.0/tooling/executeAnonymous?anonymousBody=${encodeURIComponent(apexCode)}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${auth.access_token}` }
  });
  return await res.json();
}

async function main() {
  const auth = await getAuth();
  console.log("Connected to org.");

  let hasMore = true;
  let batch = 1;
  while (hasMore) {
    const apex = `
      List<SLA_Event__c> binList = [SELECT Id FROM SLA_Event__c WHERE isDeleted = true ALL ROWS LIMIT 1000];
      if (!binList.isEmpty()) {
        Database.emptyRecycleBin(binList);
      }
    `;
    const res = await executeApex(auth, apex);
    if (!res.success) {
      console.error("Apex error:", res);
      break;
    }
    
    // Check remaining
    const countRes = await fetch(`${process.env.SF_INSTANCE_URL}/services/data/v60.0/queryAll?q=` + encodeURIComponent("SELECT count() FROM SLA_Event__c WHERE isDeleted = true"), {
      headers: { Authorization: `Bearer ${auth.access_token}` }
    });
    const countData = await countRes.json();
    console.log(`Batch ${batch++}: Recycle bin remaining = ${countData.totalSize}`);
    if (countData.totalSize === 0) {
      hasMore = false;
    }
  }

  // Check limits
  const limitsRes = await fetch(`${process.env.SF_INSTANCE_URL}/services/data/v60.0/limits`, {
    headers: { Authorization: `Bearer ${auth.access_token}` }
  });
  const limits = await limitsRes.json();
  console.log("DataStorageMB now:", limits.DataStorageMB);
}

main().catch(console.error);
