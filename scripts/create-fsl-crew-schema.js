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
  return {
    accessToken: data.access_token,
    instanceUrl: data.instance_url || INSTANCE_URL
  };
}

async function toolingRequest(auth, endpoint, method = "GET", body = null) {
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
  return { status: res.status, ok: res.ok, data: json };
}

async function createCustomObject(auth, fullName, label, pluralLabel, nameField) {
  console.log(`Creating CustomObject ${fullName}...`);
  const body = {
    FullName: fullName,
    Metadata: {
      label: label,
      pluralLabel: pluralLabel,
      nameField: nameField,
      deploymentStatus: "Deployed",
      sharingModel: "ReadWrite"
    }
  };
  const res = await toolingRequest(auth, "/services/data/v60.0/tooling/sobjects/CustomObject", "POST", body);
  if (res.ok) {
    console.log(`✅ CustomObject ${fullName} created successfully (ID: ${res.data.id})`);
  } else {
    if (JSON.stringify(res.data).includes("duplicate") || JSON.stringify(res.data).includes("already exists")) {
      console.log(`ℹ️ CustomObject ${fullName} already exists.`);
    } else {
      console.error(`❌ Failed to create ${fullName}:`, res.data);
    }
  }
}

async function createCustomField(auth, fullName, metadata) {
  console.log(`Creating CustomField ${fullName}...`);
  const body = {
    FullName: fullName,
    Metadata: metadata
  };
  const res = await toolingRequest(auth, "/services/data/v60.0/tooling/sobjects/CustomField", "POST", body);
  if (res.ok) {
    console.log(`  ✅ Field ${fullName} created successfully`);
  } else {
    if (JSON.stringify(res.data).includes("duplicate") || JSON.stringify(res.data).includes("already exists")) {
      console.log(`  ℹ️ Field ${fullName} already exists.`);
    } else {
      console.error(`  ❌ Failed to create field ${fullName}:`, res.data);
    }
  }
}

async function main() {
  console.log("🔐 Authenticating with Salesforce Tooling API...");
  const auth = await getAuth();
  console.log("Connected to instance:", auth.instanceUrl);

  // ==========================================
  // 1. Create Service_Crew__c
  // ==========================================
  await createCustomObject(auth, "Service_Crew__c", "Service Crew", "Service Crews", {
    type: "Text",
    label: "Crew Name"
  });

  await createCustomField(auth, "Service_Crew__c.Crew_Size__c", {
    type: "Number",
    label: "Crew Size",
    precision: 3,
    scale: 0,
    required: false
  });

  await createCustomField(auth, "Service_Crew__c.Zone__c", {
    type: "Lookup",
    label: "Service Zone",
    referenceTo: "Service_Zone__c",
    relationshipName: "Service_Crews",
    relationshipLabel: "Service Crews",
    required: false
  });

  await createCustomField(auth, "Service_Crew__c.Is_Active__c", {
    type: "Checkbox",
    label: "Active",
    defaultValue: "true"
  });

  await createCustomField(auth, "Service_Crew__c.Description__c", {
    type: "TextArea",
    label: "Description"
  });

  // ==========================================
  // 2. Create Service_Crew_Member__c
  // ==========================================
  await createCustomObject(auth, "Service_Crew_Member__c", "Service Crew Member", "Service Crew Members", {
    type: "AutoNumber",
    label: "Member ID",
    displayFormat: "SCM-{000000}"
  });

  await createCustomField(auth, "Service_Crew_Member__c.Service_Crew__c", {
    type: "Lookup",
    label: "Service Crew",
    referenceTo: "Service_Crew__c",
    relationshipName: "Crew_Members",
    relationshipLabel: "Crew Members",
    required: true
  });

  await createCustomField(auth, "Service_Crew_Member__c.Technician__c", {
    type: "Lookup",
    label: "Technician",
    referenceTo: "Technician__c",
    relationshipName: "Crew_Memberships",
    relationshipLabel: "Crew Memberships",
    required: true
  });

  await createCustomField(auth, "Service_Crew_Member__c.Start_Date__c", {
    type: "Date",
    label: "Start Date"
  });

  await createCustomField(auth, "Service_Crew_Member__c.End_Date__c", {
    type: "Date",
    label: "End Date"
  });

  await createCustomField(auth, "Service_Crew_Member__c.Is_Leader__c", {
    type: "Checkbox",
    label: "Crew Leader",
    defaultValue: "false"
  });

  // ==========================================
  // 3. Create Assigned_Resource__c
  // ==========================================
  await createCustomObject(auth, "Assigned_Resource__c", "Assigned Resource", "Assigned Resources", {
    type: "AutoNumber",
    label: "Assigned Resource Number",
    displayFormat: "AR-{000000}"
  });

  await createCustomField(auth, "Assigned_Resource__c.Service_Job__c", {
    type: "Lookup",
    label: "Service Appointment",
    referenceTo: "Service_Job__c",
    relationshipName: "Assigned_Resources",
    relationshipLabel: "Assigned Resources",
    required: true
  });

  await createCustomField(auth, "Assigned_Resource__c.Technician__c", {
    type: "Lookup",
    label: "Technician",
    referenceTo: "Technician__c",
    relationshipName: "Assigned_Resources",
    relationshipLabel: "Assigned Resources",
    required: false
  });

  await createCustomField(auth, "Assigned_Resource__c.Service_Crew__c", {
    type: "Lookup",
    label: "Service Crew",
    referenceTo: "Service_Crew__c",
    relationshipName: "Assigned_Resources",
    relationshipLabel: "Assigned Resources",
    required: false
  });

  await createCustomField(auth, "Assigned_Resource__c.Resource_Type__c", {
    type: "Picklist",
    label: "Resource Type",
    valueSet: {
      valueSetDefinition: {
        sorted: false,
        value: [
          { fullName: "Technician", default: true, label: "Technician" },
          { fullName: "Crew", default: false, label: "Crew" },
          { fullName: "Equipment", default: false, label: "Equipment" }
        ]
      }
    }
  });

  await createCustomField(auth, "Assigned_Resource__c.Role__c", {
    type: "Picklist",
    label: "Role",
    valueSet: {
      valueSetDefinition: {
        sorted: false,
        value: [
          { fullName: "Lead Technician", default: true, label: "Lead Technician" },
          { fullName: "Crew Member", default: false, label: "Crew Member" },
          { fullName: "Safety Specialist", default: false, label: "Safety Specialist" },
          { fullName: "Apprentice", default: false, label: "Apprentice" }
        ]
      }
    }
  });

  await createCustomField(auth, "Assigned_Resource__c.Is_Leader__c", {
    type: "Checkbox",
    label: "Is Leader",
    defaultValue: "false"
  });

  await createCustomField(auth, "Assigned_Resource__c.Status__c", {
    type: "Picklist",
    label: "Status",
    valueSet: {
      valueSetDefinition: {
        sorted: false,
        value: [
          { fullName: "Assigned", default: true, label: "Assigned" },
          { fullName: "En Route", default: false, label: "En Route" },
          { fullName: "On Site", default: false, label: "On Site" },
          { fullName: "Completed", default: false, label: "Completed" },
          { fullName: "Cancelled", default: false, label: "Cancelled" }
        ]
      }
    }
  });

  await createCustomField(auth, "Assigned_Resource__c.Check_In_Time__c", {
    type: "DateTime",
    label: "Check-In Time"
  });

  await createCustomField(auth, "Assigned_Resource__c.Completed_Time__c", {
    type: "DateTime",
    label: "Completed Time"
  });

  await createCustomField(auth, "Assigned_Resource__c.Actual_Hours__c", {
    type: "Number",
    label: "Actual Hours",
    precision: 4,
    scale: 2
  });

  await createCustomField(auth, "Assigned_Resource__c.Notes__c", {
    type: "TextArea",
    label: "Notes"
  });

  console.log("\n🎉 ALL CUSTOM OBJECTS AND FIELDS CREATED SUCCESSFULLY IN SALESFORCE!");
}

main().catch(console.error);
