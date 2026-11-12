const fs = require('fs');
const path = require('path');

console.log('--- Starting Postman Collections & Environments Update ---');

// 1. Extra Gateway items to add to Safety_Checklist_Mobile_API_Postman_Collection.json
const extraGatewaySafetyItems = [
  {
    name: "10. Pre-Job Safety Protocols & Hazard Checklist (Screen 06)",
    event: [
      {
        listen: "test",
        script: {
          exec: [
            "pm.test(\"Status is 200 OK\", function () {",
            "    pm.response.to.have.status(200);",
            "});",
            "var json = pm.response.json();",
            "pm.test(\"Safety protocols returned successfully\", function () {",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.requiredPPE).to.be.an('array');",
            "    pm.expect(json.hazardChecks).to.be.an('array');",
            "});"
          ],
          type: "text/javascript"
        }
      }
    ],
    request: {
      method: "GET",
      header: [
        {
          key: "Authorization",
          value: "Bearer {{accessToken}}"
        },
        {
          key: "Content-Type",
          value: "application/json"
        }
      ],
      url: {
        raw: "{{baseUrl}}/api/work-orders/{{workOrderId}}/safety-check",
        host: ["{{baseUrl}}"],
        path: ["api", "work-orders", "{{workOrderId}}", "safety-check"]
      },
      description: "Fetches required PPE checklist, site hazard clearance protocols, risk level assessment, and safety warnings tailored to the equipment type."
    },
    response: []
  },
  {
    name: "11. Submit Technician Safety Verification (Screen 08)",
    event: [
      {
        listen: "test",
        script: {
          exec: [
            "pm.test(\"Status is 200 OK\", function () {",
            "    pm.response.to.have.status(200);",
            "});",
            "var json = pm.response.json();",
            "pm.test(\"Safety verification cleared\", function () {",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.assessment.status).to.eql(\"CLEARED\");",
            "});",
            "if (json.assessment && json.assessment.safetyCheckId) {",
            "    pm.collectionVariables.set(\"safetyCheckId\", json.assessment.safetyCheckId);",
            "}"
          ],
          type: "text/javascript"
        }
      }
    ],
    request: {
      method: "POST",
      header: [
        {
          key: "Authorization",
          value: "Bearer {{accessToken}}"
        },
        {
          key: "Content-Type",
          value: "application/json"
        }
      ],
      body: {
        mode: "raw",
        raw: JSON.stringify({
          technicianId: "{{technicianId}}",
          siteRiskLevel: "HIGH",
          ppeVerified: {
            dielectricGloves: true,
            safetyGoggles: true,
            steelToeBoots: true,
            hardHat: true,
            hearingProtection: true
          },
          hazardChecks: [
            { hazardCode: "LOTO_APPLIED", verified: true },
            { hazardCode: "ZERO_ENERGY_STATE", verified: true },
            { hazardCode: "BATTERY_ISOLATION", verified: true },
            { hazardCode: "FUEL_GAS_CLEAR", verified: true },
            { hazardCode: "EXHAUST_VENTILATION", verified: true }
          ],
          technicianDeclaration: "I confirm that all safety protocols and Lockout/Tagout measures have been verified before servicing this equipment.",
          latitude: 18.52043,
          longitude: 73.856743
        }, null, 2)
      },
      url: {
        raw: "{{baseUrl}}/api/work-orders/{{workOrderId}}/safety-check",
        host: ["{{baseUrl}}"],
        path: ["api", "work-orders", "{{workOrderId}}", "safety-check"]
      },
      description: "Submits technician pre-job safety sign-off, PPE verification, and hazard checks. Inserts safety audit activity into Salesforce."
    },
    response: []
  },
  {
    name: "12. Emergency Safety Escalation & Hazard Alert",
    event: [
      {
        listen: "test",
        script: {
          exec: [
            "pm.test(\"Status is 201 Created\", function () {",
            "    pm.response.to.have.status(201);",
            "});",
            "var json = pm.response.json();",
            "pm.test(\"Hazard escalated and job halted\", function () {",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.escalation.workHalted).to.be.true;",
            "});"
          ],
          type: "text/javascript"
        }
      }
    ],
    request: {
      method: "POST",
      header: [
        {
          key: "Authorization",
          value: "Bearer {{accessToken}}"
        },
        {
          key: "Content-Type",
          value: "application/json"
        }
      ],
      body: {
        mode: "raw",
        raw: JSON.stringify({
          hazardType: "ELECTRICAL_ARCING",
          severity: "CRITICAL",
          hazardDetails: "Active electrical arcing detected at main 415V distribution busbar with visible insulation scorch.",
          immediateActionTaken: "Tripped upstream substation breaker and cordoned off 10-meter perimeter.",
          evacuatedSite: true,
          technicianId: "{{technicianId}}"
        }, null, 2)
      },
      url: {
        raw: "{{baseUrl}}/api/work-orders/{{workOrderId}}/safety-escalation",
        host: ["{{baseUrl}}"],
        path: ["api", "work-orders", "{{workOrderId}}", "safety-escalation"]
      },
      description: "Immediately halts work on the Work Order and triggers critical safety hazard escalation to dispatch and supervisors."
    },
    response: []
  },
  {
    name: "13. Get Equipment Safety Audit History",
    event: [
      {
        listen: "test",
        script: {
          exec: [
            "pm.test(\"Status is 200 OK\", function () {",
            "    pm.response.to.have.status(200);",
            "});",
            "var json = pm.response.json();",
            "pm.test(\"Safety history returned\", function () {",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.workOrderId).to.be.ok;",
            "});"
          ],
          type: "text/javascript"
        }
      }
    ],
    request: {
      method: "GET",
      header: [
        {
          key: "Authorization",
          value: "Bearer {{accessToken}}"
        }
      ],
      url: {
        raw: "{{baseUrl}}/api/work-orders/{{workOrderId}}/safety-history",
        host: ["{{baseUrl}}"],
        path: ["api", "work-orders", "{{workOrderId}}", "safety-history"]
      },
      description: "Fetches past safety audits, PPE compliance records, and hazard escalation history for the work order."
    },
    response: []
  }
];

// Helper to add test script to Update Status request if missing
function ensureUpdateStatusTestScript(item) {
  if (!item.event || item.event.length === 0) {
    item.event = [
      {
        listen: "test",
        script: {
          exec: [
            "pm.test(\"Status is 200 OK\", function () {",
            "    pm.response.to.have.status(200);",
            "});",
            "var json = pm.response.json();",
            "pm.test(\"Checklist status updated\", function () {",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data.status).to.eql(\"Passed\");",
            "});"
          ],
          type: "text/javascript"
        }
      }
    ];
  }
}

// ── Update Safety_Checklist_Mobile_API_Postman_Collection.json across paths ──
const safetyColPaths = [
  'Safety_Checklist_Mobile_API_Postman_Collection.json',
  'docs/Safety_Checklist_Mobile_API_Postman_Collection.json',
  'mobile-developer-package/Safety_Checklist_Mobile_API_Postman_Collection.json'
];

safetyColPaths.forEach(relPath => {
  const fullPath = path.resolve(__dirname, '..', relPath);
  if (!fs.existsSync(fullPath)) return;
  const col = JSON.parse(fs.readFileSync(fullPath, 'utf8'));

  // Ensure variables contain safetyCheckId, technicianId, currentLat, currentLng
  const existingVars = new Set(col.variable.map(v => v.key));
  if (!existingVars.has('safetyCheckId')) {
    col.variable.push({ key: 'safetyCheckId', value: 'SAF-849201', type: 'string' });
  }
  if (!existingVars.has('technicianId')) {
    col.variable.push({ key: 'technicianId', value: 'TECH-5021', type: 'string' });
  }
  if (!existingVars.has('currentLat')) {
    col.variable.push({ key: 'currentLat', value: '18.520430', type: 'string' });
  }
  if (!existingVars.has('currentLng')) {
    col.variable.push({ key: 'currentLng', value: '73.856743', type: 'string' });
  }

  // Update item 7 test script
  const updateStatusItem = col.item.find(i => i.name.includes("Update Checklist Status"));
  if (updateStatusItem) {
    ensureUpdateStatusTestScript(updateStatusItem);
  }

  // Add items 10, 11, 12, 13 if not already present
  extraGatewaySafetyItems.forEach(extra => {
    const exists = col.item.some(i => i.name.includes(extra.name.substring(4)));
    if (!exists) {
      col.item.push(JSON.parse(JSON.stringify(extra)));
    }
  });

  fs.writeFileSync(fullPath, JSON.stringify(col, null, 2), 'utf8');
  console.log(`✅ Updated ${relPath} (Total Requests: ${col.item.length})`);
});

// ── Update digiField360_Salesforce_Live_APIs.postman_collection.json ────────
const liveColPaths = [
  'mobile-developer-package/digiField360_Salesforce_Live_APIs.postman_collection.json',
  'docs/digiField360_Salesforce_Live_APIs.postman_collection.json'
];

// Apex REST items to add into Folder 8.5
const apexRestItemsForFolder85 = [
  {
    name: "8.5.5 Get Checklist Templates & Questions (Apex REST)",
    request: {
      method: "GET",
      header: [
        { key: "Authorization", value: "Bearer {{authToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      url: {
        raw: "{{baseUrl}}/services/apexrest/api/safety-checklist/templates",
        host: ["{{baseUrl}}"],
        path: ["services", "apexrest", "api", "safety-checklist", "templates"]
      },
      description: "Fetches standard checklist categories and predefined questions (PPE, Electrical Lockout, Site Clearance, Fire Safety) to store in mobile local storage for offline forms."
    },
    response: []
  },
  {
    name: "8.5.6 Get Safety Checklists by Work Order ID (Apex REST)",
    request: {
      method: "GET",
      header: [
        { key: "Authorization", value: "Bearer {{authToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      url: {
        raw: "{{baseUrl}}/services/apexrest/api/safety-checklist/work-order/{{workOrderId}}",
        host: ["{{baseUrl}}"],
        path: ["services", "apexrest", "api", "safety-checklist", "work-order", "{{workOrderId}}"]
      },
      description: "Retrieves all safety inspections linked to a specific Work Order, including pass/fail rates, dates, technician details, and item answers."
    },
    response: []
  },
  {
    name: "8.5.7 Get Single Checklist Detail with Items",
    request: {
      method: "GET",
      header: [
        { key: "Authorization", value: "Bearer {{authToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      url: {
        raw: "{{baseUrl}}/services/apexrest/api/safety-checklist/{{checklistId}}",
        host: ["{{baseUrl}}"],
        path: ["services", "apexrest", "api", "safety-checklist", "{{checklistId}}"]
      },
      description: "Fetches a full safety checklist report by record ID, including all items, remarks, severity, status, and verification flags."
    },
    response: []
  },
  {
    name: "8.5.8 Submit Complete Safety Checklist (Items + GPS + Signature)",
    event: [
      {
        listen: "test",
        script: {
          exec: [
            "pm.test(\"Status is 201 Created or 200 OK\", function () {",
            "    pm.expect(pm.response.code).to.be.oneOf([200, 201]);",
            "});",
            "var jsonData = pm.response.json();",
            "if (jsonData.success && jsonData.data && jsonData.data.checklistId) {",
            "    pm.environment.set('checklistId', jsonData.data.checklistId);",
            "}"
          ],
          type: "text/javascript"
        }
      }
    ],
    request: {
      method: "POST",
      header: [
        { key: "Authorization", value: "Bearer {{authToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      body: {
        mode: "raw",
        raw: JSON.stringify({
          workOrderId: "{{workOrderId}}",
          assetId: "{{assetId}}",
          technicianName: "Vikram Sharma",
          technicianId: "{{technicianId}}",
          siteLocation: "Solar Power Plant Site #3, Pune",
          latitude: 18.52043,
          longitude: 73.856744,
          inspectionDate: "2026-09-23T11:45:00Z",
          overallComments: "Site clearance completed. All high voltage panels isolated and locked before beginning inverter maintenance.",
          signatureBase64: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
          items: [
            {
              itemName: "PPE - Helmet & Steel-Toe Boots",
              category: "Personal Protective Equipment (PPE)",
              question: "Is certified hard hat and safety shoes worn by all team members?",
              status: "Pass",
              severity: "High",
              remarks: "Verified on entry",
              orderIndex: 1
            },
            {
              itemName: "Eye & Face Shield Protection",
              category: "Personal Protective Equipment (PPE)",
              question: "Are safety goggles/shields worn near cutting or grinding equipment?",
              status: "Pass",
              severity: "Medium",
              remarks: "Equipped on technician",
              orderIndex: 2
            },
            {
              itemName: "Lockout / Tagout (LOTO)",
              category: "Electrical Safety & Lockout",
              question: "Is LOTO applied and verified zero-energy state on main switchboard?",
              status: "Pass",
              severity: "Critical",
              remarks: "Padlock #401 applied with technician key.",
              orderIndex: 3
            },
            {
              itemName: "Fire Extinguisher Availability",
              category: "Site & Environmental Clearance",
              question: "Is a tested ABC fire extinguisher available within 10 meters?",
              status: "Pass",
              severity: "Critical",
              remarks: "Cylinder pressure gauge verified green.",
              orderIndex: 4
            }
          ]
        }, null, 2)
      },
      url: {
        raw: "{{baseUrl}}/services/apexrest/api/safety-checklist/submit",
        host: ["{{baseUrl}}"],
        path: ["services", "apexrest", "api", "safety-checklist", "submit"]
      },
      description: "Submits a full safety inspection report with child checklist items, GPS location, technician comments, and digital signature attachment."
    },
    response: []
  },
  {
    name: "8.5.9 Upload Checklist Item Photo Evidence (Base64)",
    request: {
      method: "POST",
      header: [
        { key: "Authorization", value: "Bearer {{authToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      body: {
        mode: "raw",
        raw: JSON.stringify({
          checklistItemId: "{{checklistItemId}}",
          checklistId: "{{checklistId}}",
          fileName: "site_safety_lockout_proof.jpg",
          contentType: "image/jpeg",
          base64Data: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        }, null, 2)
      },
      url: {
        raw: "{{baseUrl}}/services/apexrest/api/safety-checklist/evidence",
        host: ["{{baseUrl}}"],
        path: ["services", "apexrest", "api", "safety-checklist", "evidence"]
      },
      description: "Uploads photo evidence attached directly to the checklist item and stores it as a Salesforce ContentDocument / File."
    },
    response: []
  },
  {
    name: "8.5.10 Update Checklist Status / Supervisor Sign-off",
    event: [
      {
        listen: "test",
        script: {
          exec: [
            "pm.test(\"Status is 200 OK\", function () {",
            "    pm.response.to.have.status(200);",
            "});",
            "var json = pm.response.json();",
            "pm.test(\"Checklist status updated\", function () {",
            "    pm.expect(json.success).to.be.true;",
            "    pm.expect(json.data.status).to.eql(\"Passed\");",
            "});"
          ],
          type: "text/javascript"
        }
      }
    ],
    request: {
      method: "PATCH",
      header: [
        { key: "Authorization", value: "Bearer {{authToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      body: {
        mode: "raw",
        raw: JSON.stringify({
          status: "Passed",
          overallComments: "Reviewed and approved by Site Safety Supervisor: All LOTO and PPE verified on-site.",
          siteLocation: "Solar Power Plant Station #3, Pune"
        }, null, 2)
      },
      url: {
        raw: "{{baseUrl}}/services/apexrest/api/safety-checklist/{{checklistId}}",
        host: ["{{baseUrl}}"],
        path: ["services", "apexrest", "api", "safety-checklist", "{{checklistId}}"]
      },
      description: "Updates status (e.g. 'Passed', 'Requires Review', 'Failed') or supervisor notes on an existing checklist."
    },
    response: []
  },
  {
    name: "8.5.11 Delete / Cancel Draft Checklist",
    request: {
      method: "DELETE",
      header: [
        { key: "Authorization", value: "Bearer {{authToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      url: {
        raw: "{{baseUrl}}/services/apexrest/api/safety-checklist/{{checklistId}}",
        host: ["{{baseUrl}}"],
        path: ["services", "apexrest", "api", "safety-checklist", "{{checklistId}}"]
      },
      description: "Deletes a draft checklist record and its associated child items."
    },
    response: []
  },
  {
    name: "8.5.12 Get Work Order Attachments & Photos",
    request: {
      method: "GET",
      header: [
        { key: "Authorization", value: "Bearer {{authToken}}" },
        { key: "Accept", value: "application/json" }
      ],
      url: {
        raw: "{{baseUrl}}/api/attachments?workOrderId={{workOrderId}}",
        host: ["{{baseUrl}}"],
        path: ["api", "attachments"],
        query: [{ key: "workOrderId", value: "{{workOrderId}}" }]
      },
      description: "Fetches all photo attachments, safety proofs, and signatures uploaded to Salesforce ContentVersion linked to this Work Order."
    },
    response: []
  }
];

liveColPaths.forEach(relPath => {
  const fullPath = path.resolve(__dirname, '..', relPath);
  if (!fs.existsSync(fullPath)) return;
  const col = JSON.parse(fs.readFileSync(fullPath, 'utf8'));

  const folder85 = col.item.find(i => i.name && i.name.startsWith("8.5"));
  if (folder85 && folder85.item) {
    folder85.name = "8.5 Work Order Safety, PPE & Checklist Lifecycle (Screens 06, 08)";
    apexRestItemsForFolder85.forEach(newItem => {
      const exists = folder85.item.some(i => i.name.includes(newItem.name.substring(6)));
      if (!exists) {
        folder85.item.push(JSON.parse(JSON.stringify(newItem)));
      }
    });
    console.log(`✅ Updated ${relPath} Folder 8.5 (Items in folder: ${folder85.item.length})`);
    fs.writeFileSync(fullPath, JSON.stringify(col, null, 2), 'utf8');
  }
});

// ── Update Environment Files ────────────────────────────────────────────────
const envPaths = [
  'mobile-developer-package/digiField360_Salesforce_Live.postman_environment.json',
  'mobile-developer-package/digiField360_Local_Development.postman_environment.json',
  'docs/digiField360_Salesforce_Live.postman_environment.json'
];

envPaths.forEach(relPath => {
  const fullPath = path.resolve(__dirname, '..', relPath);
  if (!fs.existsSync(fullPath)) return;
  const env = JSON.parse(fs.readFileSync(fullPath, 'utf8'));

  const existingKeys = new Set(env.values.map(v => v.key));
  const toAdd = [
    { key: "checklistId", value: "a0X5g000000AbCdEAI", enabled: true },
    { key: "checklistItemId", value: "a0Y5g000000Xyz2EAA", enabled: true },
    { key: "safetyCheckId", value: "SAF-849201", enabled: true }
  ];

  toAdd.forEach(item => {
    if (!existingKeys.has(item.key)) {
      env.values.push(item);
    }
  });

  fs.writeFileSync(fullPath, JSON.stringify(env, null, 2), 'utf8');
  console.log(`✅ Updated environment: ${relPath} (Variables: ${env.values.length})`);
});

console.log('--- All Postman Collections & Environments Successfully Synchronized ---');
