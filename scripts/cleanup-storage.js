const fs = require("fs");
const path = require("path");

function loadEnvFile() {
  try {
    const envPath = path.resolve(__dirname, "../.env");
    if (fs.existsSync(envPath)) {
      const content = fs.readFileSync(envPath, "utf8");
      content.split("\n").forEach((line) => {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith("#")) {
          const idx = trimmed.indexOf("=");
          if (idx > 0) {
            const key = trimmed.substring(0, idx).trim();
            const val = trimmed.substring(idx + 1).trim();
            if (!process.env[key]) {
              process.env[key] = val;
            }
          }
        }
      });
    }
  } catch (e) {}
}
loadEnvFile();

const INSTANCE_URL = process.env.SF_INSTANCE_URL || "https://orgfarm-4036b01401-dev-ed.develop.my.salesforce.com";
const REFRESH_TOKEN = process.env.SF_REFRESH_TOKEN || "";
const CLIENT_ID = process.env.SF_CLIENT_ID || "PlatformCLI";

async function getAccessToken() {
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
  if (!res.ok || !data.access_token) {
    throw new Error("OAuth token refresh failed: " + JSON.stringify(data));
  }
  return {
    accessToken: data.access_token,
    instanceUrl: data.instance_url || INSTANCE_URL
  };
}

async function query(token, instanceUrl, soql) {
  const url = `${instanceUrl}/services/data/v60.0/query?q=${encodeURIComponent(soql)}`;
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    }
  });
  return res.json();
}

async function deleteRecord(token, instanceUrl, sobject, id) {
  const url = `${instanceUrl}/services/data/v60.0/sobjects/${sobject}/${id}`;
  const res = await fetch(url, {
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${token}`
    }
  });
  return res.status === 204;
}

async function deleteBatchComposite(token, instanceUrl, ids) {
  if (!ids || ids.length === 0) return;
  // Composite collection delete (up to 200 at a time)
  const url = `${instanceUrl}/services/data/v60.0/composite/sobjects?ids=${ids.join(",")}&allOrNone=false`;
  const res = await fetch(url, {
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${token}`
    }
  });
  return res.json();
}

async function emptyRecycleBin(token, instanceUrl, ids) {
  if (!ids || ids.length === 0) return;
  const idTags = ids.map(id => `<ids>${id}</ids>`).join("");
  const soapBody = `<?xml version="1.0" encoding="utf-8" ?>
<env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
  <env:Header>
    <n1:SessionHeader xmlns:n1="urn:partner.soap.sforce.com">
      <n1:sessionId>${token}</n1:sessionId>
    </n1:SessionHeader>
  </env:Header>
  <env:Body>
    <n1:emptyRecycleBin xmlns:n1="urn:partner.soap.sforce.com">
      ${idTags}
    </n1:emptyRecycleBin>
  </env:Body>
</env:Envelope>`;

  const url = `${instanceUrl}/services/Soap/u/59.0`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "text/xml; charset=UTF-8",
      SOAPAction: "emptyRecycleBin"
    },
    body: soapBody
  });
  return res.text();
}

async function checkStorageLimits(token, instanceUrl) {
  const url = `${instanceUrl}/services/data/v60.0/limits`;
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    }
  });
  return res.json();
}

async function main() {
  const auth = await getAccessToken();
  console.log("Connected to:", auth.instanceUrl);

  console.log("Starting bulk purge of SLA_Event__c records...");
  let totalDeleted = 0;
  while (true) {
    const q = await query(auth.accessToken, auth.instanceUrl, "SELECT Id FROM SLA_Event__c LIMIT 200");
    const records = q.records || [];
    if (records.length === 0) break;

    const ids = records.map(r => r.Id);
    await deleteBatchComposite(auth.accessToken, auth.instanceUrl, ids);
    totalDeleted += ids.length;
    console.log(`Deleted ${totalDeleted} SLA_Event__c records...`);

    // Empty recycle bin for these ids
    await emptyRecycleBin(auth.accessToken, auth.instanceUrl, ids);
  }

  // Also check any deleted records in Recycle bin for SLA_Event__c
  const binQ = await query(auth.accessToken, auth.instanceUrl, "SELECT Id FROM SLA_Event__c WHERE isDeleted = true LIMIT 200");
  const binIds = (binQ.records || []).map(r => r.Id);
  if (binIds.length > 0) {
    await emptyRecycleBin(auth.accessToken, auth.instanceUrl, binIds);
  }

  console.log(`\n✅ Purged ${totalDeleted} SLA_Event__c records and emptied Recycle Bin!`);

  // Verify limits now
  const limits = await checkStorageLimits(auth.accessToken, auth.instanceUrl);
  console.log("\n--- UPDATED ORG STORAGE LIMITS ---");
  console.log("DataStorageMB:", limits.DataStorageMB);
  console.log("FileStorageMB:", limits.FileStorageMB);
}

main().catch(console.error);
