const fs = require("fs");
const path = require("path");

const targets = [
  path.resolve(__dirname, "../mobile-developer-package/digiField360_Salesforce_Live_APIs.postman_collection.json"),
  path.resolve(__dirname, "../docs/digiField360_Salesforce_Live_APIs.postman_collection.json")
];

const newRequests = [
  {
    name: "2.8 Get Work Order Service Appointments",
    request: {
      method: "GET",
      header: [
        { key: "Authorization", value: "Bearer {{accessToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      url: {
        raw: "{{baseUrl}}/api/work-orders/{{workOrderId}}/service-appointments",
        host: ["{{baseUrl}}"],
        path: ["api", "work-orders", "{{workOrderId}}", "service-appointments"]
      },
      description: "Retrieves all child Service Appointments scheduled for a specific parent Work Order."
    }
  },
  {
    name: "2.9 List & Filter Service Appointments",
    request: {
      method: "GET",
      header: [
        { key: "Authorization", value: "Bearer {{accessToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      url: {
        raw: "{{baseUrl}}/api/service-appointments?workOrderId={{workOrderId}}",
        host: ["{{baseUrl}}"],
        path: ["api", "service-appointments"],
        query: [{ key: "workOrderId", value: "{{workOrderId}}" }]
      },
      description: "Queries Service Appointments with optional filters by workOrderId, technicianId, or status."
    }
  },
  {
    name: "2.10 Get Service Appointment Details",
    request: {
      method: "GET",
      header: [
        { key: "Authorization", value: "Bearer {{accessToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      url: {
        raw: "{{baseUrl}}/api/service-appointments/{{serviceAppointmentId}}",
        host: ["{{baseUrl}}"],
        path: ["api", "service-appointments", "{{serviceAppointmentId}}"]
      },
      description: "Fetches full details of a specific Service Appointment including parent Work Order, Case, Asset, and Account lookups."
    }
  },
  {
    name: "2.11 Create Service Appointment",
    request: {
      method: "POST",
      header: [
        { key: "Authorization", value: "Bearer {{accessToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      body: {
        mode: "raw",
        raw: JSON.stringify(
          {
            workOrderId: "{{workOrderId}}",
            jobType: "Repair",
            priority: "High",
            status: "Scheduled",
            notes: "Field diagnostic appointment scheduled.",
            slaDeadline: "2026-10-25T18:00:00Z"
          },
          null,
          2
        )
      },
      url: {
        raw: "{{baseUrl}}/api/service-appointments",
        host: ["{{baseUrl}}"],
        path: ["api", "service-appointments"]
      },
      description: "Creates a new Service Appointment linked to a Work Order in Salesforce."
    }
  },
  {
    name: "2.12 Service Appointment GPS Check-In (Geofenced)",
    request: {
      method: "POST",
      header: [
        { key: "Authorization", value: "Bearer {{accessToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      body: {
        mode: "raw",
        raw: JSON.stringify(
          {
            latitude: 18.52043,
            longitude: 73.856743,
            accuracy: 5.0,
            overrideReason: null
          },
          null,
          2
        )
      },
      url: {
        raw: "{{baseUrl}}/api/service-appointments/{{serviceAppointmentId}}/check-in",
        host: ["{{baseUrl}}"],
        path: [
          "api",
          "service-appointments",
          "{{serviceAppointmentId}}",
          "check-in"
        ]
      },
      description: "Performs GPS geofenced check-in for the technician at the service appointment job site."
    }
  },
  {
    name: "2.13 Complete Service Appointment",
    request: {
      method: "POST",
      header: [
        { key: "Authorization", value: "Bearer {{accessToken}}" },
        { key: "Content-Type", value: "application/json" }
      ],
      body: {
        mode: "raw",
        raw: JSON.stringify(
          {
            technicianNotes: "Service appointment completed successfully and verified with customer.",
            resolutionTimeMin: 45
          },
          null,
          2
        )
      },
      url: {
        raw: "{{baseUrl}}/api/service-appointments/{{serviceAppointmentId}}/complete",
        host: ["{{baseUrl}}"],
        path: [
          "api",
          "service-appointments",
          "{{serviceAppointmentId}}",
          "complete"
        ]
      },
      description: "Marks the Service Appointment as Completed, records resolution duration, and generates completion report."
    }
  }
];

targets.forEach((filePath) => {
  if (fs.existsSync(filePath)) {
    const col = JSON.parse(fs.readFileSync(filePath, "utf8"));
    const woFolder = col.item.find((folder) =>
      folder.name.includes("Work Orders")
    );
    if (woFolder) {
      newRequests.forEach((newReq) => {
        const existingIdx = woFolder.item.findIndex(
          (i) => i.name === newReq.name
        );
        if (existingIdx >= 0) {
          woFolder.item[existingIdx] = newReq;
        } else {
          woFolder.item.push(newReq);
        }
      });
    }

    // Add variables if missing
    if (!col.variable.find((v) => v.key === "serviceAppointmentId")) {
      col.variable.push({
        key: "serviceAppointmentId",
        value: "SA-001001",
        type: "string"
      });
    }
    if (!col.variable.find((v) => v.key === "lineItemId")) {
      col.variable.push({
        key: "lineItemId",
        value: "WOLI-00101",
        type: "string"
      });
    }

    fs.writeFileSync(filePath, JSON.stringify(col, null, 2), "utf8");
    console.log(`Updated Postman collection at: ${filePath}`);
  }
});
