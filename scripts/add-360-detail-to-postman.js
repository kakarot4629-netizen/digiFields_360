const fs = require('fs');

const col = JSON.parse(fs.readFileSync('version_1_DigiFiled_360.postman_collection.json', 'utf8'));

const newDetailItem = {
  name: '4. Get Service Appointment 360 Details (Multi-Assets, Parts, Crew & Address)',
  event: [
    {
      listen: 'test',
      script: {
        exec: [
          'pm.test("Status code is 200 OK", function () {',
          '    pm.response.to.have.status(200);',
          '});',
          '',
          'var jsonData = pm.response.json();',
          'pm.test("Returns valid 360 Service Appointment", function () {',
          '    pm.expect(jsonData.success).to.be.true;',
          '    pm.expect(jsonData.serviceAppointment).to.be.an("object");',
          '    pm.expect(jsonData.serviceAppointment.id).to.eql(pm.collectionVariables.get("service_appointment_id"));',
          '});',
          '',
          'var sa = jsonData.serviceAppointment;',
          'console.log("\\n--- 📱 SERVICE APPOINTMENT 360 DETAILS ---");',
          'console.log("Name:", sa.name, "| Status:", sa.status, "| Priority:", sa.priority);',
          'console.log("Piyush Channe Match: isAssignedToMe =", sa.isAssignedToMe, "| Type =", sa.assignmentType);',
          'if (sa.myCrewAssignment) {',
          '    console.log("👥 Tagged Crew:", sa.myCrewAssignment.crewName, "| Role:", sa.myCrewAssignment.role, "| Leader:", sa.myCrewAssignment.isLeader);',
          '}',
          'if (sa.primaryAsset) {',
          '    console.log("🏭 Primary Asset:", sa.primaryAsset.name, "-", sa.primaryAsset.productName);',
          '}',
          'console.log("📦 Multi-Asset Line Items Count:", sa.multiAssetLineItemsCount);',
          'if (sa.multiAssetLineItems && sa.multiAssetLineItems.length > 0) {',
          '    sa.multiAssetLineItems.forEach(function(item, idx) {',
          '        console.log("   " + (idx + 1) + ". [" + item.name + "] " + (item.asset ? item.asset.name : "Asset") + ": " + item.description + " (Status: " + item.status + ")");',
          '    });',
          '}',
          'console.log("🔩 Parts Requests Count:", sa.partsRequestsCount);',
          'if (sa.partsRequests && sa.partsRequests.length > 0) {',
          '    sa.partsRequests.forEach(function(pr, idx) {',
          '        console.log("   " + (idx + 1) + ". [" + pr.name + "] " + pr.partName + " (Qty: " + pr.quantity + ", Status: " + pr.status + ")");',
          '    });',
          '}',
          'if (sa.serviceAddress) {',
          '    console.log("📍 Site Address:", sa.serviceAddress.streetAddress + ", " + sa.serviceAddress.city + " | Contact:", sa.serviceAddress.contactPerson, sa.serviceAddress.contactPhone);',
          '}',
          '',
          'pm.test("Piyush Channe unique identifier is populated", function () {',
          '    pm.expect(sa.isAssignedToMe).to.be.true;',
          '    pm.expect(sa.assignmentType).to.be.a("string").and.not.empty;',
          '});',
          '',
          'pm.test("Multi-Assets and Parts Requests are returned as arrays", function () {',
          '    pm.expect(sa.multiAssetLineItems).to.be.an("array");',
          '    pm.expect(sa.partsRequests).to.be.an("array");',
          '});'
        ],
        type: 'text/javascript'
      }
    }
  ],
  request: {
    method: 'GET',
    header: [
      {
        key: 'Authorization',
        value: 'Bearer {{access_token}}',
        type: 'text'
      }
    ],
    url: {
      raw: '{{instance_url}}/services/apexrest/df360/v1/service-appointments/{{service_appointment_id}}?technicianId={{technician_id}}',
      host: [
        '{{instance_url}}'
      ],
      path: [
        'services',
        'apexrest',
        'df360',
        'v1',
        'service-appointments',
        '{{service_appointment_id}}'
      ],
      query: [
        {
          key: 'technicianId',
          value: '{{technician_id}}',
          description: 'Technician ID (e.g. Piyush Channe). Enables unique isAssignedToMe and crew match resolution.'
        }
      ]
    },
    description: 'Returns complete 360-degree operational details for a Service Appointment including multi-asset checklists, requested parts, assigned crew roster, customer address, and Piyush Channe identifier flags.'
  },
  response: []
};

// Check if already exists or insert after Request 3
const existingIdx = col.item.findIndex(i => i.name.includes('Get Service Appointment 360 Details'));
if (existingIdx >= 0) {
  col.item[existingIdx] = newDetailItem;
} else {
  // Insert at index 3 (4th item)
  col.item.splice(3, 0, newDetailItem);
}

// Renumber names
col.item.forEach((item, idx) => {
  item.name = (idx + 1) + '. ' + item.name.replace(/^\d+\.\s*/, '');
});

fs.writeFileSync('version_1_DigiFiled_360.postman_collection.json', JSON.stringify(col, null, 2), 'utf8');
fs.writeFileSync('mobile-developer-package/version_1_DigiFiled_360.postman_collection.json', JSON.stringify(col, null, 2), 'utf8');
console.log('Updated Postman collections successfully! Total items:', col.item.length);
col.item.forEach((item, idx) => console.log((idx+1) + '. ' + item.name + ' [' + item.request.method + ']'));
