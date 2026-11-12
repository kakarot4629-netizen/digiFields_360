const fs = require("fs");
const path = require("path");

const postmanPath = path.resolve(__dirname, "../version_1_DigiFiled_360.postman_collection.json");
const postman = JSON.parse(fs.readFileSync(postmanPath, "utf8"));

// Create the dedicated Check-In request
const checkInRequest = {
  name: "3. Service Appointment Check-In (POST with GPS & Timestamp)",
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
          "pm.test('Check-In was successful', function () {",
          "    pm.expect(jsonData.success).to.be.true;",
          "    pm.expect(jsonData.appointment).to.be.an('object');",
          "    pm.expect(jsonData.appointment.checkInTime).to.be.a('string').and.not.empty;",
          "    pm.expect(jsonData.appointment.status).to.eql('In Progress');",
          "});",
          "",
          "console.log('✅ Technician checked in at site!');",
          "console.log('   ⏰ Check-In Time:', jsonData.appointment.checkInTime);",
          "console.log('   📍 Lat:', jsonData.appointment.latitude, '| Lon:', jsonData.appointment.longitude);",
          "if (jsonData.parentWorkOrder) {",
          "    console.log('   📋 Parent Work Order:', jsonData.parentWorkOrder.name, '| Status:', jsonData.parentWorkOrder.status);",
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
        value: "Bearer {{access_token}}",
        type: "text"
      },
      {
        key: "Content-Type",
        value: "application/json",
        type: "text"
      }
    ],
    body: {
      mode: "raw",
      raw: "{\n  \"latitude\": 19.119677,\n  \"longitude\": 72.882356,\n  \"status\": \"In Progress\"\n}"
    },
    url: {
      raw: "{{instance_url}}/services/apexrest/df360/v1/service-appointments/{{service_appointment_id}}/check-in",
      host: ["{{instance_url}}"],
      path: [
        "services",
        "apexrest",
        "df360",
        "v1",
        "service-appointments",
        "{{service_appointment_id}}",
        "check-in"
      ]
    },
    description: "Dedicated mobile technician Check-In endpoint. Accepts either Appointment Record ID or Name (e.g. SA-0000024). Automatically stamps check-in timestamp, records GPS coordinates, computes SLA countdown, and updates parent Work Order status to 'In Progress'."
  },
  response: []
};

// Replace items 3A and 3B with our new dedicated Check-In request
// Find any items with "3" or "Appointment"
const idx = postman.item.findIndex(it => it.name.includes("Start Appointment") || it.name.includes("Check In"));
if (idx >= 0) {
  // Remove 3A and 3B if both exist
  const countToRemove = postman.item[idx + 1] && postman.item[idx + 1].name.includes("Complete Appointment") ? 2 : 1;
  postman.item.splice(idx, countToRemove, checkInRequest);
} else {
  postman.item.splice(2, 0, checkInRequest);
}

// Renumber items cleanly
postman.item.forEach((it, i) => {
  // Clean existing number prefix if any
  const cleanName = it.name.replace(/^\d+([A-Z])?\.?\s*/, "");
  it.name = `${i + 1}. ${cleanName}`;
});

fs.writeFileSync(postmanPath, JSON.stringify(postman, null, 2), "utf8");
console.log("Postman collection updated successfully with dedicated Check-In API!");
