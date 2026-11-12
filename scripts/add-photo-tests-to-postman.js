const fs = require('fs');

const col = JSON.parse(fs.readFileSync('version_1_DigiFiled_360.postman_collection.json', 'utf8'));

// 1. Upload Photo Request
const uploadPhotoItem = {
  name: 'Upload Service Appointment Photo (Before / After Evidence)',
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
          'pm.test("Photo uploaded successfully", function () {',
          '    pm.expect(jsonData.success).to.be.true;',
          '    pm.expect(jsonData.photo).to.be.an("object");',
          '    pm.expect(jsonData.photo.photoUrl).to.be.a("string").and.not.empty;',
          '});',
          '',
          'console.log("📸 " + jsonData.photo.photoType + " Photo Saved:");',
          'console.log("   🔗 URL:", jsonData.photo.photoUrl);',
          'if (jsonData.photo.contentVersionId) {',
          '    console.log("   📁 Salesforce File ID:", jsonData.photo.contentVersionId);',
          '}',
          'if (jsonData.photo.workOrderLineItem) {',
          '    console.log("   🏭 Synced to Multi-Asset:", jsonData.photo.workOrderLineItem.name);',
          '}'
        ],
        type: 'text/javascript'
      }
    }
  ],
  request: {
    method: 'POST',
    header: [
      {
        key: 'Authorization',
        value: 'Bearer {{access_token}}',
        type: 'text'
      },
      {
        key: 'Content-Type',
        value: 'application/json',
        type: 'text'
      }
    ],
    body: {
      mode: 'raw',
      raw: '{\n  "photoType": "Before",\n  "imageBase64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",\n  "fileName": "before_inspection.jpg",\n  "notes": "Pre-service visual inspection: slight oil seepage on bushing seal before overhaul."\n}'
    },
    url: {
      raw: '{{instance_url}}/services/apexrest/df360/v1/service-appointments/{{service_appointment_id}}/photos',
      host: [
        '{{instance_url}}'
      ],
      path: [
        'services',
        'apexrest',
        'df360',
        'v1',
        'service-appointments',
        '{{service_appointment_id}}',
        'photos'
      ]
    },
    description: 'Uploads Before or After photo evidence from mobile camera (base64) or hosted URL. Automatically creates Salesforce ContentVersion and stamps Before/After fields on the Service Appointment.'
  },
  response: []
};

// 2. Get Photos Request
const getPhotosItem = {
  name: 'Get Service Appointment Photos & Evidence Gallery',
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
          'pm.test("Returns appointment photos", function () {',
          '    pm.expect(jsonData.success).to.be.true;',
          '});',
          '',
          'console.log("🖼️ Service Appointment Photo Evidence:");',
          'if (jsonData.beforePhoto) {',
          '    console.log("   📷 Before Photo:", jsonData.beforePhoto.url);',
          '}',
          'if (jsonData.afterPhoto) {',
          '    console.log("   📸 After Photo:", jsonData.afterPhoto.url);',
          '}',
          'console.log("   📂 Attached Gallery Count:", jsonData.evidenceGalleryCount);'
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
      raw: '{{instance_url}}/services/apexrest/df360/v1/service-appointments/{{service_appointment_id}}/photos',
      host: [
        '{{instance_url}}'
      ],
      path: [
        'services',
        'apexrest',
        'df360',
        'v1',
        'service-appointments',
        '{{service_appointment_id}}',
        'photos'
      ]
    },
    description: 'Retrieves all Before and After photos, timestamps, and attached Salesforce files for a Service Appointment.'
  },
  response: []
};

// Remove any existing photo items to avoid duplicates
col.item = col.item.filter(i => !i.name.toLowerCase().includes('photo'));

// Insert Upload Photo and Get Photos right after Check-In (index 5)
// Find index of Check-In
const checkInIdx = col.item.findIndex(i => i.name.toLowerCase().includes('check-in'));
const insertIdx = checkInIdx >= 0 ? checkInIdx + 1 : col.item.length;

col.item.splice(insertIdx, 0, uploadPhotoItem, getPhotosItem);

// Re-number items cleanly
col.item.forEach((item, idx) => {
  item.name = (idx + 1) + '. ' + item.name.replace(/^\d+\.\s*/, '');
});

fs.writeFileSync('version_1_DigiFiled_360.postman_collection.json', JSON.stringify(col, null, 2), 'utf8');
fs.writeFileSync('mobile-developer-package/version_1_DigiFiled_360.postman_collection.json', JSON.stringify(col, null, 2), 'utf8');

console.log('Updated Postman Collection! Total items:', col.item.length);
col.item.forEach((item, idx) => console.log((idx+1) + '. ' + item.name + ' [' + item.request.method + ']'));
