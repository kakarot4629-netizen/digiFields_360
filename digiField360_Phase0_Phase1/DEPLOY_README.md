# digiField360 — Phase 0 & 1 Deployment Package

## What's in this package

### Phase 0 — Schema Foundation
- **18 Custom Objects** (10 new + 3 enhanced + 5 from prior prototype)
- **3 Platform Events**: DF360_Job_Assigned__e, DF360_SLA_Alert__e, DF360_Parts_Approved__e
- **6 Permission Sets**: Technician, ServiceManager, CustomerPortal, PartsAdmin, Analytics, AgentRuntime

### Phase 1 — Apex Backend
- **14 Controller Classes** (all @AuraEnabled + REST resource methods)
- **4 Apex Triggers** (ServiceJob, PartsRequest, CSAT, GPSLog)
- **2 Trigger Helpers** (async @future methods to avoid mixed DML)
- **5 Batch/Scheduled Classes** (SLA Monitor, GPS Retention, Contract Expiry, Cert Expiry, CSAT Rollup)

## Deploy order

```bash
# Step 1 — Objects first (dependencies must exist before Apex compiles)
sf project deploy start --metadata CustomObject --target-org <alias>

# Step 2 — Platform Events
sf project deploy start --metadata CustomObject:DF360_Job_Assigned__e \
  --metadata CustomObject:DF360_SLA_Alert__e \
  --metadata CustomObject:DF360_Parts_Approved__e \
  --target-org <alias>

# Step 3 — Permission Sets
sf project deploy start --metadata PermissionSet --target-org <alias>

# Step 4 — All Apex (classes + triggers together; triggers reference classes)
sf project deploy start --metadata ApexClass --metadata ApexTrigger --target-org <alias>

# Or deploy everything at once via manifest:
sf project deploy start --manifest package.xml --target-org <alias>
```

## Seed data required after deploy

1. **SLA_Config__c** — At minimum create one record:
   - Product_Category__c = 'All', Customer_Tier__c = 'All', Priority__c = 'Medium'
   - Ack_SLA_Mins__c = 30, Response_SLA_Hrs__c = 4, Resolution_SLA_Hrs__c = 8
   
2. **Service_Zone__c** — Create at least one zone before creating Technicians

3. **Depot__c** — Create at least one depot before managing Parts_Stock

## Schedule batch jobs (run after deploy)

```apex
// SLA Monitor every 5 minutes
System.schedule('DF360 SLA Monitor', '0 0/5 * * * ?', new DF360_SLAMonitorBatch());

// Daily maintenance jobs
System.schedule('DF360 GPS Retention', '0 0 1 * * ?', new DF360_GPSLogRetentionBatch());
System.schedule('DF360 Contract Expiry', '0 0 7 * * ?', new DF360_ContractExpiryBatch());
System.schedule('DF360 Cert Expiry', '0 30 7 * * ?', new DF360_CertExpiryBatch());
System.schedule('DF360 CSAT Rollup', '0 30 0 * * ?', new DF360_CSATRollupBatch());
```

## Named Credentials required (configure in Salesforce Setup)

| Named Credential | External URL | Used By |
|---|---|---|
| DF360_MetaWhatsApp | Meta WhatsApp Business API | DF360_WhatsAppService |
| DF360_AIService | Agentforce / LLM endpoint | DF360_GuruAIController |
| DF360_Firebase | Firebase Cloud Messaging | DF360_GPSController |
| DF360_GoogleVision | Google Cloud Vision API | (Phase 3 - Agentforce) |
| DF360_ERP | Customer ERP endpoint | (Phase 5 - Mobile) |

## Gap analysis status: Phase 0 + 1 COMPLETE

Remaining phases (this package covers 0 and 1 only):
- Phase 2: 8 Salesforce Flows
- Phase 3: 5 Agentforce Agent configurations  
- Phase 4: 12 Lightning Web Components
- Phase 5: Mobile MCP Gateway expansion (scripts/mcp-server.js)
- Phase 6: Apex test suite + seed data + end-to-end verification
