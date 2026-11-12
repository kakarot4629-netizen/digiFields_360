const fs = require('fs');
const path = require('path');

const filePath = path.resolve(__dirname, '../scripts/mcp-server.js');
let code = fs.readFileSync(filePath, 'utf8');

// 1. Add Scheduled_Start_Time__c, Scheduled_End_Time__c to all saSoql queries
code = code.replaceAll(
  'Check_In_Time__c, Completed_Time__c, Resolution_Time_Min__c,',
  'Scheduled_Start_Time__c, Scheduled_End_Time__c, Check_In_Time__c, Completed_Time__c, Resolution_Time_Min__c,'
);

// 2. Line 2807 query (which doesn't have Resolution_Time_Min__c)
code = code.replace(
  'SLA_Status__c, Check_In_Time__c, Completed_Time__c, Work_Order__c,',
  'SLA_Status__c, Scheduled_Start_Time__c, Scheduled_End_Time__c, Check_In_Time__c, Completed_Time__c, Work_Order__c,'
);

// 3. Update mappedJobs in /api/work-orders
if (!code.includes("scheduledStartTime: r.Scheduled_Start_Time__c,")) {
  code = code.replace(
    "slaStatus: r.SLA_Status__c,\n                checkInTime: r.Check_In_Time__c,\n                completedTime: r.Completed_Time__c,",
    `slaStatus: r.SLA_Status__c,
                scheduledStartTime: r.Scheduled_Start_Time__c,
                scheduledEndTime: r.Scheduled_End_Time__c,
                checkInTime: r.Check_In_Time__c,
                completedTime: r.Completed_Time__c,
                startTime: r.Check_In_Time__c || r.Scheduled_Start_Time__c,
                endTime: r.Completed_Time__c || r.Scheduled_End_Time__c,
                actualStartTime: r.Check_In_Time__c,
                actualEndTime: r.Completed_Time__c,`
  );
}

// 4. Update /api/service-appointments/:id response
if (!code.includes("scheduledStartTime: currentSa.Scheduled_Start_Time__c,")) {
  code = code.replace(
    "serviceAppointment: currentSa,",
    `serviceAppointment: {
                  ...currentSa,
                  scheduledStartTime: currentSa.Scheduled_Start_Time__c,
                  scheduledEndTime: currentSa.Scheduled_End_Time__c,
                  actualStartTime: currentSa.Check_In_Time__c,
                  actualEndTime: currentSa.Completed_Time__c,
                  startTime: currentSa.Check_In_Time__c || currentSa.Scheduled_Start_Time__c,
                  endTime: currentSa.Completed_Time__c || currentSa.Scheduled_End_Time__c
                },`
  );
}

// 5. Update PATCH status endpoint to auto-stamp timestamps
if (!code.includes("auto-stamp completed/on-site")) {
  code = code.replace(
    "if (actualSaId.startsWith(\"a0I\")) {",
    `// auto-stamp completed/on-site
          if (status === "Completed" && !updateFields.Completed_Time__c) {
            updateFields.Completed_Time__c = new Date().toISOString();
          } else if (status === "On Site" && !updateFields.Check_In_Time__c) {
            updateFields.Check_In_Time__c = new Date().toISOString();
          }
          if (actualSaId.startsWith("a0I")) {`
  );
}

fs.writeFileSync(filePath, code, 'utf8');
console.log("✅ Successfully updated scripts/mcp-server.js with Service Appointment time tracking fields!");
