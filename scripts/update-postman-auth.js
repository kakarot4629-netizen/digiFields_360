const fs = require("fs");
const path = require("path");

const postmanPath = path.resolve(__dirname, "../version_1_DigiFiled_360.postman_collection.json");
const postman = JSON.parse(fs.readFileSync(postmanPath, "utf8"));

// 1. Update Request 1 test script to save technician_id default
const req1 = postman.item.find(it => it.name.includes("OAuth 2.0 Token"));
if (req1) {
  req1.event[0].script.exec = [
    "var jsonData = pm.response.json();",
    "if (jsonData.access_token) {",
    "    pm.collectionVariables.set('access_token', jsonData.access_token);",
    "    if (jsonData.instance_url) {",
    "        pm.collectionVariables.set('instance_url', jsonData.instance_url);",
    "    }",
    "    pm.collectionVariables.set('technician_id', 'a02g500000Bvf9mAAB');",
    "    console.log('✅ Access Token & Default technician_id saved to collection variables!');",
    "}"
  ];
}

// 2. Add /auth/me Profile Request
const profileRequest = {
  name: "2. Get Authenticated Technician Profile (Auto-Sets technician_id)",
  event: [
    {
      listen: "test",
      script: {
        exec: [
          "pm.test('Status code is 200 OK', function () {",
          "    pm.response.to.have.status(200);",
          "});",
          "",
          "var jsonData = pm.response.json();",
          "pm.test('Returns authenticated technician', function () {",
          "    pm.expect(jsonData.success).to.be.true;",
          "    pm.expect(jsonData.technician).to.be.an('object');",
          "    pm.expect(jsonData.technician.id).to.be.a('string').and.not.empty;",
          "});",
          "",
          "if (jsonData.technician && jsonData.technician.id) {",
          "    pm.collectionVariables.set('technician_id', jsonData.technician.id);",
          "    console.log('✅ Auto-captured technician_id:', jsonData.technician.id, 'for', jsonData.technician.name);",
          "}"
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
        value: "Bearer {{access_token}}",
        type: "text"
      },
      {
        key: "Content-Type",
        value: "application/json",
        type: "text"
      }
    ],
    url: {
      raw: "{{instance_url}}/services/apexrest/df360/v1/auth/me",
      host: ["{{instance_url}}"],
      path: ["services", "apexrest", "df360", "v1", "auth", "me"]
    },
    description: "Returns the authenticated user details and their associated active Technician__c record. Automatically saves `{{technician_id}}` for all subsequent requests."
  },
  response: []
};

// Check if profile request already exists, if not insert at position 1 (right after OAuth)
const existingProfileIdx = postman.item.findIndex(it => it.name.includes("Get Authenticated Technician Profile"));
if (existingProfileIdx >= 0) {
  postman.item[existingProfileIdx] = profileRequest;
} else {
  postman.item.splice(1, 0, profileRequest);
}

// 3. Update Get Technician Work Orders & Appointments to use ?technicianId={{technician_id}}
const woReq = postman.item.find(it => it.name.includes("Get Technician Work Orders & Appointments"));
if (woReq) {
  woReq.request.url = {
    raw: "{{instance_url}}/services/apexrest/df360/v1/work-orders/my?technicianId={{technician_id}}&status=Assigned",
    host: ["{{instance_url}}"],
    path: ["services", "apexrest", "df360", "v1", "work-orders", "my"],
    query: [
      {
        key: "technicianId",
        value: "{{technician_id}}",
        description: "Filters strictly by the authenticated technician ID so only their work orders and appointments are returned."
      },
      {
        key: "status",
        value: "Assigned",
        description: "Filters both Work Orders and child Service Appointments by status (e.g. Assigned, In Progress, On Site. Uncheck/remove to retrieve all assigned records)."
      }
    ]
  };
}

// Renumber all items cleanly
postman.item.forEach((it, i) => {
  const cleanName = it.name.replace(/^\d+([A-Z])?\.?\s*/, "");
  it.name = `${i + 1}. ${cleanName}`;
});

fs.writeFileSync(postmanPath, JSON.stringify(postman, null, 2), "utf8");
console.log("Postman collection updated successfully!");
