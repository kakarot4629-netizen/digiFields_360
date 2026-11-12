const fs = require('fs');
const path = require('path');

const filePath = path.resolve(__dirname, '../version_1_DigiFiled_360.postman_collection.json');
const json = JSON.parse(fs.readFileSync(filePath, 'utf8'));

const newItem = {
  name: "5. Get Work Order AI Pre-Job Briefing",
  event: [
    {
      listen: "test",
      script: {
        exec: [
          "pm.test('Status code is 200', function () {",
          "    pm.response.to.have.status(200);",
          "});",
          "",
          "var jsonData = pm.response.json();",
          "pm.test('Briefing returned successfully', function () {",
          "    pm.expect(jsonData.success).to.be.true;",
          "    pm.expect(jsonData.briefing).to.be.a('string').and.not.empty;",
          "});",
          "console.log('📋 AI Pre-Job Briefing for ' + jsonData.workOrderName + ':');",
          "console.log(jsonData.briefing);"
        ],
        type: "text/javascript"
      }
    }
  ],
  request: {
    method: "GET",
    header: [
      { key: "Authorization", value: "Bearer {{access_token}}", type: "text" },
      { key: "Content-Type", value: "application/json", type: "text" }
    ],
    url: {
      raw: "{{instance_url}}/services/apexrest/df360/v1/work-orders/{{work_order_id}}/briefing",
      host: ["{{instance_url}}"],
      path: ["services", "apexrest", "df360", "v1", "work-orders", "{{work_order_id}}", "briefing"]
    },
    description: "Fetches the 5-point AI Pre-Job Briefing (equipment context, fault symptoms, repair history, safety protocols, and required tools/parts) for the active Work Order."
  },
  response: []
};

if (!json.item.some(i => i.name.includes("AI Pre-Job Briefing"))) {
  json.item.splice(4, 0, newItem);
  fs.writeFileSync(filePath, JSON.stringify(json, null, 2), 'utf8');
  console.log("✅ Successfully added Briefing endpoint to Postman collection!");
} else {
  console.log("Briefing endpoint already exists in collection.");
}
