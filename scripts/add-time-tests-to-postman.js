const fs = require('fs');
const path = require('path');

const filePath = path.resolve(__dirname, '../version_1_DigiFiled_360.postman_collection.json');
const collection = JSON.parse(fs.readFileSync(filePath, 'utf8'));

// Update Item 1 (Get Technician Work Orders & Appointments)
const item1 = collection.item[1];
if (item1 && item1.event && item1.event[0]) {
  const exec = item1.event[0].script.exec;
  if (!exec.some(l => l.includes('Scheduled or Start Time'))) {
    exec.push(
      '',
      'pm.test("Service Appointment contains Scheduled or Start Time", function () {',
      '    if (jsonData.workOrders && jsonData.workOrders.length > 0 && jsonData.workOrders[0].serviceAppointments && jsonData.workOrders[0].serviceAppointments.length > 0) {',
      '        var sa = jsonData.workOrders[0].serviceAppointments[0];',
      '        pm.expect(sa.startTime || sa.scheduledStartTime).to.be.a("string").and.not.empty;',
      '        console.log("   ⏰ SA Start Time:", sa.startTime || sa.scheduledStartTime);',
      '        console.log("   ⏰ SA End Time:", sa.endTime || sa.scheduledEndTime);',
      '    }',
      '});'
    );
  }
}

// Update Item 3 (Get Specific Work Order & Appointments by ID)
const item3 = collection.item[3];
if (item3 && item3.event && item3.event[0]) {
  const exec = item3.event[0].script.exec;
  if (!exec.some(l => l.includes('Scheduled or Start Time'))) {
    exec.push(
      '',
      'pm.test("Service Appointment contains Scheduled or Start Time", function () {',
      '    if (jsonData.serviceAppointments && jsonData.serviceAppointments.length > 0) {',
      '        var sa = jsonData.serviceAppointments[0];',
      '        pm.expect(sa.startTime || sa.scheduledStartTime).to.be.a("string").and.not.empty;',
      '        console.log("   ⏰ SA Start Time:", sa.startTime || sa.scheduledStartTime);',
      '        console.log("   ⏰ SA End Time:", sa.endTime || sa.scheduledEndTime);',
      '    }',
      '});'
    );
  }
}

fs.writeFileSync(filePath, JSON.stringify(collection, null, 2), 'utf8');
console.log("✅ Successfully updated version_1_DigiFiled_360.postman_collection.json with Service Appointment Start/End Time tests!");
