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

async function main() {
  const token = await getAuth();
  const baseUrl = process.env.SF_INSTANCE_URL;
  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

  // 1. Check or Create PermissionSet
  console.log("Checking for PermissionSet 'DF360_FSL_MultiResource_Admin'...");
  const psQueryRes = await fetch(`${baseUrl}/services/data/v60.0/query?q=` + encodeURIComponent("SELECT Id FROM PermissionSet WHERE Name = 'DF360_FSL_MultiResource_Admin'"), { headers });
  const psData = await psQueryRes.json();
  let psId;

  if (psData.totalSize > 0) {
    psId = psData.records[0].Id;
    console.log("Found existing PermissionSet:", psId);
  } else {
    console.log("Creating new PermissionSet...");
    const createRes = await fetch(`${baseUrl}/services/data/v60.0/sobjects/PermissionSet`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        Name: 'DF360_FSL_MultiResource_Admin',
        Label: 'DF360 FSL Multi Resource Admin'
      })
    });
    const createData = await createRes.json();
    if (!createData.success && !createData.id) {
      console.error("Failed to create PermissionSet:", createData);
      return;
    }
    psId = createData.id;
    console.log("Created PermissionSet:", psId);
  }

  // 2. Add ObjectPermissions
  const sObjects = ['Service_Crew__c', 'Service_Crew_Member__c', 'Assigned_Resource__c'];
  for (const sobj of sObjects) {
    const objCheckRes = await fetch(`${baseUrl}/services/data/v60.0/query?q=` + 
      encodeURIComponent(`SELECT Id FROM ObjectPermissions WHERE ParentId = '${psId}' AND SobjectType = '${sobj}'`), { headers });
    const objCheckData = await objCheckRes.json();
    if (objCheckData.totalSize === 0) {
      const objPermRes = await fetch(`${baseUrl}/services/data/v60.0/sobjects/ObjectPermissions`, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          ParentId: psId,
          SobjectType: sobj,
          PermissionsRead: true,
          PermissionsCreate: true,
          PermissionsEdit: true,
          PermissionsDelete: true,
          PermissionsViewAllRecords: true,
          PermissionsModifyAllRecords: true
        })
      });
      console.log(`ObjectPermissions for ${sobj}:`, await objPermRes.json());
    } else {
      console.log(`ObjectPermissions for ${sobj} already exist.`);
    }
  }

  // 3. Add FieldPermissions
  const fieldList = [
    'Service_Crew__c.Crew_Size__c',
    'Service_Crew__c.Zone__c',
    'Service_Crew__c.Is_Active__c',
    'Service_Crew__c.Description__c',
    'Service_Crew_Member__c.Service_Crew__c',
    'Service_Crew_Member__c.Technician__c',
    'Service_Crew_Member__c.Start_Date__c',
    'Service_Crew_Member__c.End_Date__c',
    'Service_Crew_Member__c.Is_Leader__c',
    'Assigned_Resource__c.Service_Job__c',
    'Assigned_Resource__c.Technician__c',
    'Assigned_Resource__c.Service_Crew__c',
    'Assigned_Resource__c.Resource_Type__c',
    'Assigned_Resource__c.Role__c',
    'Assigned_Resource__c.Is_Leader__c',
    'Assigned_Resource__c.Status__c',
    'Assigned_Resource__c.Check_In_Time__c',
    'Assigned_Resource__c.Completed_Time__c',
    'Assigned_Resource__c.Actual_Hours__c',
    'Assigned_Resource__c.Notes__c'
  ];

  for (const f of fieldList) {
    const fCheckRes = await fetch(`${baseUrl}/services/data/v60.0/query?q=` +
      encodeURIComponent(`SELECT Id FROM FieldPermissions WHERE ParentId = '${psId}' AND Field = '${f}'`), { headers });
    const fCheckData = await fCheckRes.json();
    if (fCheckData.totalSize === 0) {
      const fpRes = await fetch(`${baseUrl}/services/data/v60.0/sobjects/FieldPermissions`, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          ParentId: psId,
          SobjectType: f.split('.')[0],
          Field: f,
          PermissionsRead: true,
          PermissionsEdit: true
        })
      });
      const fpData = await fpRes.json();
      console.log(`FieldPermission for ${f}:`, fpData.success ? 'Granted' : fpData);
    } else {
      console.log(`FieldPermission for ${f} already exists.`);
    }
  }

  // 4. Assign PermissionSet to User Piyush Channe (005g5000007AR1JAAW)
  const userId = '005g5000007AR1JAAW';
  const psaCheckRes = await fetch(`${baseUrl}/services/data/v60.0/query?q=` +
    encodeURIComponent(`SELECT Id FROM PermissionSetAssignment WHERE PermissionSetId = '${psId}' AND AssigneeId = '${userId}'`), { headers });
  const psaCheckData = await psaCheckRes.json();
  if (psaCheckData.totalSize === 0) {
    const assignRes = await fetch(`${baseUrl}/services/data/v60.0/sobjects/PermissionSetAssignment`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        PermissionSetId: psId,
        AssigneeId: userId
      })
    });
    console.log("Assigned PermissionSet to User:", await assignRes.json());
  } else {
    console.log("PermissionSet already assigned to User Piyush Channe.");
  }

  console.log("🎉 All Object and Field Permissions successfully configured!");
}

main().catch(console.error);
