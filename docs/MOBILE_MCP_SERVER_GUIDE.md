# digiField360 Mobile MCP Server Setup & Integration Guide

## Overview

The digiField360 Mobile Application (React Native) uses the **Model Context Protocol (MCP)** to interact with Salesforce data, support offline caching via `OfflineMCPGateway.js`, and execute field service operations.

This guide details how to configure both:

1. **Salesforce Hosted MCP Server** (Production & Cloud Staging)
2. **Local Node.js MCP Gateway** (Development & Local Testing)

---

## 1. Salesforce Hosted MCP Server Setup (Cloud)

### Step 1.1: Enable Salesforce Hosted MCP Server

1. In Salesforce Setup, search for **API Catalog** or **MCP Servers**.
2. Enable **Salesforce Hosted MCP Server**.
3. Confirm the endpoint URL: `https://[your-org-domain].my.salesforce.com/services/mcp/v1`

### Step 1.2: Create External Client App (ECA) / Connected App for OAuth

1. Go to **Setup > App Manager > New Connected App** (or External Client Apps).
2. Configure the following parameters:

| Field Name                | Value                                    | Description                          |
| ------------------------- | ---------------------------------------- | ------------------------------------ |
| **App Name**              | `digiField360 Mobile`                    | Mobile application identifier        |
| **API Name**              | `digiField360_Mobile`                    | Salesforce API name                  |
| **Enable OAuth Settings** | `Checked`                                | Enables OAuth 2.0 flow               |
| **Callback URL**          | `field360://callback`                    | Mobile app redirect URI              |
| **OAuth Scopes**          | `api`, `refresh_token`, `offline_access` | Required permissions                 |
| **Require PKCE**          | `Checked`                                | Essential for mobile OAuth security  |
| **Permitted Users**       | `Admin-approved users only`              | Restricts access by profile/perm set |
| **IP Relaxation**         | `Relax IP restrictions`                  | Required for mobile dynamic IPs      |

3. Save the Connected App and copy the **Consumer Key** (`Client ID`).

### Step 1.3: Mobile App Environment Configuration

Set the following environment variables in the React Native mobile application `.env` file:

```env
SF_MCP_SERVER_URL=https://[your-org].my.salesforce.com/services/mcp/v1
SF_OAUTH_CLIENT_ID=[Consumer Key from Connected App]
SF_OAUTH_CALLBACK_URL=field360://callback
SF_INSTANCE_URL=https://[your-org].my.salesforce.com
```

---

## 2. Supported MCP Tools Reference

The mobile app relies on 5 core MCP tools exposed by the MCP Server:

### 1. `sobject_query`

- **Type**: Read (Cached)
- **Used For**: Fetching work orders (`Work_Order__c`), technician profile (`Technician__c`), and job history (`Job_History__c`) during morning offline pre-load.
- **Example Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "sobject_query",
      "arguments": {
        "soql": "SELECT Id, Subject__c, Status__c, Priority__c FROM Work_Order__c WHERE Status__c != 'Completed' LIMIT 10"
      }
    }
  }
  ```

### 2. `sobject_search`

- **Type**: Read (Cached)
- **Used For**: Searching Knowledge articles (`Knowledge__kav`) and product catalogues for AI troubleshooting assistance.
- **Example Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "sobject_search",
      "arguments": {
        "searchTerm": "compressor overheating",
        "sobjectName": "Knowledge__kav"
      }
    }
  }
  ```

### 3. `sobject_update`

- **Type**: Write (Queued Offline)
- **Used For**: Updating work order status, technician notes, parts used, and completion time.
- **Example Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
      "name": "sobject_update",
      "arguments": {
        "sobjectName": "Work_Order__c",
        "recordId": "a00000000000WO1",
        "fields": {
          "Status__c": "Completed",
          "Technician_Notes__c": "Replaced thermal fuse and tested motor."
        }
      }
    }
  }
  ```

### 4. `sobject_create`

- **Type**: Write (Queued Offline)
- **Used For**: Creating time log entries, photo attachment records (`ContentVersion`), and `Job_History__c` records.
- **Example Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "id": 4,
    "method": "tools/call",
    "params": {
      "name": "sobject_create",
      "arguments": {
        "sobjectName": "Job_History__c",
        "fields": {
          "Work_Order__c": "a00000000000WO1",
          "Equipment_ID__c": "EQ-992",
          "Resolution_Notes__c": "Replaced fuse"
        }
      }
    }
  }
  ```

### 5. `sobject_describe`

- **Type**: Read (Cached)
- **Used For**: Fetching SObject field schemas for dynamic offline mobile field validation.
- **Example Payload**:
  ```json
  {
    "jsonrpc": "2.0",
    "id": 5,
    "method": "tools/call",
    "params": {
      "name": "sobject_describe",
      "arguments": {
        "sobjectName": "Work_Order__c"
      }
    }
  }
  ```

---

## 3. Local Node.js MCP Gateway (`scripts/mcp-server.js`)

For local development and testing, run the Node.js MCP server:

```powershell
node scripts/mcp-server.js
```

### Running with Mock Mode (No Auth Needed)

Send header `x-mock-mode: true` to get instant structured responses for testing offline mobile sync logic without a live Salesforce org connection.

### Running with Live Salesforce Connection

Pass the `Authorization: Bearer <Access_Token>` and `x-instance-url: <Salesforce_Instance_URL>` headers to proxy queries directly to your scratch org or developer sandbox.
