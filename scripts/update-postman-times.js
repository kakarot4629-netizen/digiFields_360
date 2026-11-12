const fs = require("fs");
const path = require("path");

const postmanPath = path.resolve(__dirname, "../version_1_DigiFiled_360.postman_collection.json");
const postman = JSON.parse(fs.readFileSync(postmanPath, "utf8"));

// Find the index of item "3. Update Service Appointment Status"
const idx = postman.item.findIndex(it => it.name.includes("Update Service Appointment Status"));

if (idx >= 0) {
  // Replace item 3 with 3A (Check-In / Start) and 3B (Complete)
  const item3A = {
    name: "3A. Start Appointment / Check In (Sets Status & Actual Start Time)",
    event: [
      {
        listen: "test",
        script: {
          exec: [
            "pm.test('Status code is 204 No Content (Started Successfully)', function () {",
            "    pm.response.to.have.status(204);",
            "});",
            "console.log('✅ Service Appointment started! Check_In_Time stamped.');"
          ],
          type: "text/javascript"
        }
      }
    ],
    request: {
      method: "PATCH",
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
        raw: "{\n  \"Status__c\": \"In Progress\",\n  \"Check_In_Time__c\": \"{{$isoTimestamp}}\"\n}"
      },
      url: {
        raw: "{{instance_url}}/services/data/v60.0/sobjects/Service_Job__c/{{service_appointment_id}}",
        host: ["{{instance_url}}"],
        path: ["services", "data", "v60.0", "sobjects", "Service_Job__c", "{{service_appointment_id}}"]
      },
      description: "Technician taps 'Start Work' or 'Check In' on the mobile app. Updates Status to 'In Progress' and stamps actual start time (`Check_In_Time__c`). If the timestamp is omitted, Salesforce automatically stamps current server time via trigger."
    },
    response: []
  };

  const item3B = {
    name: "3B. Complete Appointment (Sets Status, Actual End Time & Resolution Notes)",
    event: [
      {
        listen: "test",
        script: {
          exec: [
            "pm.test('Status code is 204 No Content (Completed Successfully)', function () {",
            "    pm.response.to.have.status(204);",
            "});",
            "console.log('✅ Service Appointment completed! Completed_Time & notes stamped.');"
          ],
          type: "text/javascript"
        }
      }
    ],
    request: {
      method: "PATCH",
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
        raw: "{\n  \"Status__c\": \"Completed\",\n  \"Completed_Time__c\": \"{{$isoTimestamp}}\",\n  \"Resolution_Notes__c\": \"Service completed as per standard procedure. All diagnostics within nominal limits.\",\n  \"Is_First_Time_Fix__c\": true\n}"
      },
      url: {
        raw: "{{instance_url}}/services/data/v60.0/sobjects/Service_Job__c/{{service_appointment_id}}",
        host: ["{{instance_url}}"],
        path: ["services", "data", "v60.0", "sobjects", "Service_Job__c", "{{service_appointment_id}}"]
      },
      description: "Technician taps 'Complete Work' on the mobile app. Updates Status to 'Completed', stamps actual end time (`Completed_Time__c`), resolution notes, and First-Time-Fix flag. Salesforce automatically calculates `Resolution_Time_Min__c`."
    },
    response: []
  };

  postman.item.splice(idx, 1, item3A, item3B);
}

// Update tests in Request 2 and Request 4 to verify scheduled vs actual null
postman.item.forEach(it => {
  if (it.name.includes("2. Get Technician Work Orders") || it.name.includes("4. Get Specific Work Order")) {
    it.event.forEach(ev => {
      if (ev.listen === "test") {
        ev.script.exec = ev.script.exec.map(line => {
          if (line.includes("pm.expect(sa.startTime || sa.scheduledStartTime).to.be.a(\"string\")")) {
            return "        pm.expect(sa.scheduledStartTime).to.be.a(\"string\").and.not.empty;\n        console.log('   📅 Scheduled:', sa.scheduledStartTime, 'to', sa.scheduledEndTime);\n        console.log('   ⏱️ Actual (null if unstarted): Start =', sa.startTime, '| End =', sa.endTime);";
          }
          return line;
        });
      }
    });
  }
});

fs.writeFileSync(postmanPath, JSON.stringify(postman, null, 2), "utf8");
console.log("Updated Postman collection successfully!");
