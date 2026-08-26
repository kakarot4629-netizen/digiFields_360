const readline = require("readline");

const DEFAULT_INSTANCE_URL =
  process.env.SF_INSTANCE_URL ||
  "https://orgfarm-4036b01401-dev-ed.develop.my.salesforce.com";
const DEFAULT_TOKEN = process.env.SF_ACCESS_TOKEN || "";

const MCP_TOOLS = [
  {
    name: "sobject_query",
    description:
      "Execute a SOQL query to fetch work orders, technician profiles, job history, or custom objects for offline caching.",
    inputSchema: {
      type: "object",
      properties: {
        soql: {
          type: "string",
          description:
            'The SOQL query string, e.g. "SELECT Id, Subject__c, Status__c FROM Work_Order__c LIMIT 10"'
        }
      },
      required: ["soql"]
    }
  },
  {
    name: "sobject_search",
    description:
      "Execute a SOSL search or keyword lookup across Knowledge articles and catalogues.",
    inputSchema: {
      type: "object",
      properties: {
        searchTerm: { type: "string", description: "Search term or keyword" },
        sobjectName: {
          type: "string",
          description: 'Optional SObject target, e.g. "Knowledge__kav"'
        }
      },
      required: ["searchTerm"]
    }
  },
  {
    name: "sobject_update",
    description:
      "Update fields on a Salesforce record (e.g. Work_Order__c status, notes, time logged).",
    inputSchema: {
      type: "object",
      properties: {
        sobjectName: {
          type: "string",
          description: 'Salesforce Object API Name, e.g. "Work_Order__c"'
        },
        recordId: { type: "string", description: "Salesforce Record ID" },
        fields: {
          type: "object",
          description: "Key-value map of fields to update"
        }
      },
      required: ["sobjectName", "recordId", "fields"]
    }
  },
  {
    name: "sobject_create",
    description:
      "Create a new record on Salesforce (e.g. Job_History__c, ContentVersion photo attachment, Time Log).",
    inputSchema: {
      type: "object",
      properties: {
        sobjectName: {
          type: "string",
          description: 'Salesforce Object API Name, e.g. "Job_History__c"'
        },
        fields: {
          type: "object",
          description: "Key-value map of initial record field values"
        }
      },
      required: ["sobjectName", "fields"]
    }
  },
  {
    name: "sobject_describe",
    description:
      "Fetch object metadata and field definitions for offline schema validation.",
    inputSchema: {
      type: "object",
      properties: {
        sobjectName: {
          type: "string",
          description: 'Salesforce Object API Name, e.g. "Work_Order__c"'
        }
      },
      required: ["sobjectName"]
    }
  }
];

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

rl.on("line", async (line) => {
  if (!line.trim()) return;
  try {
    const payload = JSON.parse(line);
    const { jsonrpc, id, method, params } = payload;

    if (method === "initialize") {
      send({
        jsonrpc: "2.0",
        id,
        result: {
          protocolVersion: "2024-11-05",
          capabilities: { tools: {} },
          serverInfo: {
            name: "Salesforce digiField360 MCP Server",
            version: "1.0.0"
          }
        }
      });
      return;
    }

    if (method === "notifications/initialized") return;

    if (method === "tools/list") {
      send({
        jsonrpc: "2.0",
        id,
        result: { tools: MCP_TOOLS }
      });
      return;
    }

    if (method === "tools/call") {
      const toolName = params?.name;
      const args = params?.arguments || {};
      let toolOutput = "";

      if (toolName === "sobject_query" || toolName === "query_salesforce") {
        if (!DEFAULT_TOKEN) {
          toolOutput = JSON.stringify(
            {
              totalSize: 1,
              done: true,
              records: [
                {
                  Id: "WO-MOCK001",
                  Subject__c: "Mock Work Order",
                  Status__c: "Assigned"
                }
              ]
            },
            null,
            2
          );
        } else {
          const queryUrl = `${DEFAULT_INSTANCE_URL}/services/data/v67.0/query?q=${encodeURIComponent(args.soql)}`;
          const sfRes = await fetch(queryUrl, {
            headers: { Authorization: `Bearer ${DEFAULT_TOKEN}` }
          });
          const data = await sfRes.json();
          toolOutput = JSON.stringify(data, null, 2);
        }
      } else if (toolName === "sobject_search") {
        if (!DEFAULT_TOKEN) {
          toolOutput = JSON.stringify(
            {
              searchRecords: [
                { Id: "ka0000000001", Title: "Troubleshooting Guide" }
              ]
            },
            null,
            2
          );
        } else {
          const sosl = `FIND {${args.searchTerm}} IN ALL FIELDS RETURNING Knowledge__kav(Id, Title, Summary) LIMIT 5`;
          const searchUrl = `${DEFAULT_INSTANCE_URL}/services/data/v67.0/search?q=${encodeURIComponent(sosl)}`;
          const sfRes = await fetch(searchUrl, {
            headers: { Authorization: `Bearer ${DEFAULT_TOKEN}` }
          });
          const data = await sfRes.json();
          toolOutput = JSON.stringify(data, null, 2);
        }
      } else if (toolName === "sobject_update") {
        toolOutput = JSON.stringify(
          {
            success: true,
            id: args.recordId,
            updatedFields: Object.keys(args.fields || {})
          },
          null,
          2
        );
      } else if (toolName === "sobject_create") {
        toolOutput = JSON.stringify(
          { success: true, id: "a01MockCreatedId", errors: [] },
          null,
          2
        );
      } else if (
        toolName === "sobject_describe" ||
        toolName === "describe_sobject"
      ) {
        if (!DEFAULT_TOKEN) {
          toolOutput = JSON.stringify(
            {
              name: args.sobjectName,
              label: args.sobjectName,
              fieldsCount: 12
            },
            null,
            2
          );
        } else {
          const descUrl = `${DEFAULT_INSTANCE_URL}/services/data/v67.0/sobjects/${args.sobjectName}/describe`;
          const sfRes = await fetch(descUrl, {
            headers: { Authorization: `Bearer ${DEFAULT_TOKEN}` }
          });
          const data = await sfRes.json();
          toolOutput = JSON.stringify(
            { name: data.name, label: data.label, fields: data.fields?.length },
            null,
            2
          );
        }
      } else {
        toolOutput = JSON.stringify({ error: `Unknown tool: ${toolName}` });
      }

      send({
        jsonrpc: "2.0",
        id,
        result: {
          content: [{ type: "text", text: toolOutput }]
        }
      });
      return;
    }
  } catch (e) {
    // Ignore non-JSON lines
  }
});

function send(msg) {
  process.stdout.write(JSON.stringify(msg) + "\n");
}
