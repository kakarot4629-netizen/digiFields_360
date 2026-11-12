const fs = require("fs");
const path = require("path");

function ensureDir(p) {
  if (!fs.existsSync(p)) fs.mkdirSync(p, { recursive: true });
}

const basePath = path.resolve(__dirname, "../force-app/main/default/objects");

// 1. Service_Crew__c
const scDir = path.join(basePath, "Service_Crew__c");
const scFieldsDir = path.join(scDir, "fields");
ensureDir(scFieldsDir);

fs.writeFileSync(
  path.join(scDir, "Service_Crew__c.object-meta.xml"),
  `<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Service Crew</label>
    <pluralLabel>Service Crews</pluralLabel>
    <nameField>
        <label>Crew Name</label>
        <type>Text</type>
    </nameField>
    <deploymentStatus>Deployed</deploymentStatus>
    <sharingModel>ReadWrite</sharingModel>
</CustomObject>`,
  "utf8"
);

// 2. Service_Crew_Member__c
const scmDir = path.join(basePath, "Service_Crew_Member__c");
const scmFieldsDir = path.join(scmDir, "fields");
ensureDir(scmFieldsDir);

fs.writeFileSync(
  path.join(scmDir, "Service_Crew_Member__c.object-meta.xml"),
  `<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Service Crew Member</label>
    <pluralLabel>Service Crew Members</pluralLabel>
    <nameField>
        <label>Member ID</label>
        <type>AutoNumber</type>
        <displayFormat>SCM-{000000}</displayFormat>
    </nameField>
    <deploymentStatus>Deployed</deploymentStatus>
    <sharingModel>ReadWrite</sharingModel>
</CustomObject>`,
  "utf8"
);

// 3. Assigned_Resource__c
const arDir = path.join(basePath, "Assigned_Resource__c");
const arFieldsDir = path.join(arDir, "fields");
ensureDir(arFieldsDir);

fs.writeFileSync(
  path.join(arDir, "Assigned_Resource__c.object-meta.xml"),
  `<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Assigned Resource</label>
    <pluralLabel>Assigned Resources</pluralLabel>
    <nameField>
        <label>Assigned Resource Number</label>
        <type>AutoNumber</type>
        <displayFormat>AR-{000000}</displayFormat>
    </nameField>
    <deploymentStatus>Deployed</deploymentStatus>
    <sharingModel>ReadWrite</sharingModel>
</CustomObject>`,
  "utf8"
);

console.log("Local metadata files written for all 3 objects.");
