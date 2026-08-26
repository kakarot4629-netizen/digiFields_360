# FIELD360 AI — DEPLOYMENT GUIDE

## Salesforce Lightning Platform (No FSL Required)

## Estimated time: 2–3 hours for first deployment

---

## PREREQUISITES

### Org requirements

- Salesforce Enterprise Edition or above
- Agentforce enabled (Setup > Agentforce > Enable)
- Einstein enabled (comes with Enterprise + Agentforce)
- Salesforce Hosted MCP Server enabled (Setup > API Catalog > MCP Servers)
- Knowledge enabled (required for Troubleshooting Assistant — Setup > Knowledge Settings)
- Custom Notifications enabled (for nightly maintenance alert)

### Tools

```bash
npm install -g @salesforce/cli
sf --version  # must be >= 2.x
```

### Custom User Fields (create later, before Apex deployment)

Do not deploy these fields in the object-only deployment. Create the seven User fields later, before deploying Apex classes.

| Field Label               | API Name                      | Type      | Notes                          |
| ------------------------- | ----------------------------- | --------- | ------------------------------ |
| F360 Skills               | F360__Skills__c               | Long Text | HVAC, Generator, Compressor... |
| F360 First Time Fix Rate  | F360__First_Time_Fix_Rate__c  | Percent   | 0-100, 1 decimal               |
| F360 Is Active            | F360__Is_Active__c            | Checkbox  | Default: true                  |
| F360 Preferred Language   | F360__Preferred_Language__c   | Picklist  | en, hi, mr, ta, te             |
| F360 Current Latitude     | F360__Current_Latitude__c     | Number    | 10,6 precision                 |
| F360 Current Longitude    | F360__Current_Longitude__c    | Number    | 10,6 precision                 |
| F360 Jobs Completed Total | F360__Jobs_Completed_Total__c | Number    | 6,0 precision                  |

---

## DEPLOYMENT ORDER

### Step 1: Authenticate

```bash
sf org login web --alias field360-dev
# Choose your sandbox or developer org
```

### Step 2: Deploy custom objects only

Objects must exist before any Apex that references them can compile.

```bash
sf project deploy start \
  --target-org field360-dev \
  --source-dir force-app/main/default/objects \
  --wait 10
```

Verify in Setup > Object Manager — you should see:

- F360__Work_Order__c
- F360__Technician__c
- F360__Job_History__c
- F360__Maintenance_Alert__c

### Step 3: Deploy Apex Classes

```bash
sf project deploy start \
  --target-org field360-dev \
  --source-dir force-app/main/default/classes \
  --wait 15
```

Create the seven User fields before this step.

### Step 5: Deploy Prompt Templates

```bash
sf project deploy start \
  --target-org field360-dev \
  --source-dir force-app/main/default/genAiPromptTemplates \
  --wait 10
```

Verify in Setup > Prompt Builder — should see 4 templates starting with "F360".

### Step 6: Deploy LWC Components

```bash
sf project deploy start \
  --target-org field360-dev \
  --source-dir force-app/main/default/lwc \
  --wait 10
```

### Step 7: Deploy Flows

```bash
sf project deploy start \
  --target-org field360-dev \
  --source-dir force-app/main/default/flows \
  --wait 10
```

Verify in Setup > Flow Builder — 3 flows should be Active.

### Step 8: Run Tests

```bash
sf apex run test \
  --test-level RunLocalTests \
  --target-org field360-dev \
  --wait 20 \
  --result-format human
```

Target: 80%+ coverage on all F360_ classes.
Expected: ~85-90% from F360_AI_Tests.

### Step 9: Configure Agentforce Agent (MANUAL — cannot be scripted)

1. Go to Setup > Agentforce > Agents
2. Click "New Agent"
3. Select "Internal — Lightning Experience Copilot"
4. Name: "Field360 AI Assistant" | API Name: Field360_AI_Agent
5. Add Topics manually (see Field360_AI_Agent.agent for topic details):
   - Job Preparation
   - Work Order Dispatch
   - Job Completion
   - On-Site Technical Support
   - Preventive Maintenance
   - Customer Booking
6. For each topic, add the corresponding Apex action
7. Set guardrails as defined in the .agent file
8. Click "Activate"

### Step 10: Add LWC to App Pages (MANUAL)

1. Setup > App Manager > Field360 App (create if needed) > Edit
2. Lightning App Builder:
   - Create "Work Order" record page → add `field360WorkOrderDetail` component
   - Create "Dispatch Board" app page → add `field360DispatchBoard` component
3. Activate both pages

### Step 11: Create Permission Set and Assign

```bash
# Or create manually in Setup
sf org assign permset --name Field360_Technician --target-org field360-dev --on-behalf-of user@email.com
```

### Step 12: Load Test Data

```bash
sf data import tree \
  --plan test-data/field360-plan.json \
  --target-org field360-dev
```

---

## COMMON DEPLOYMENT ERRORS

| Error                                         | Cause                                 | Fix                                                 |
| --------------------------------------------- | ------------------------------------- | --------------------------------------------------- |
| `F360__Skills__c does not exist on User`      | User fields have not been created yet | Create the seven User fields before Apex deployment |
| `No such column 'Knowledge__kav.ArticleBody'` | Knowledge not enabled                 | Enable Knowledge in Setup > Knowledge Settings      |
| `ConnectApi.EinsteinLLM not found`            | Einstein not enabled                  | Enable in Setup > Einstein > Einstein Features      |
| `Flow: Cannot find referenced component`      | Apex not deployed before Flow         | Deploy Apex first, then Flows                       |
| `Agent activation failed`                     | Prompt Template not found             | Verify templates deployed and published             |
| `GenAiPromptTemplate invalid`                 | Wrong API version                     | Ensure package.xml has version 66.0                 |

---

## VERIFICATION CHECKLIST

After deployment, verify each AI feature manually:

### Feature 1: Pre-Job Briefing

1. Create a Work Order with Equipment_ID__c populated
2. Create 2+ Job History records with same Equipment_ID__c
3. Assign the work order to a technician
4. Flow fires automatically — check Work Order AI_Pre_Job_Briefing__c field
5. Expected: populated briefing text within 30 seconds

### Feature 3: Troubleshooting Assistant

1. Open a Work Order record page
2. The field360WorkOrderDetail LWC should be visible
3. Type "compressor not starting" in the troubleshooting input
4. Click "Get Guidance"
5. Expected: diagnostic steps appear within 10 seconds

### Feature 4: Smart Assignment

1. Open the Dispatch Board app page
2. For an unassigned work order, click "Get AI Recommendation"
3. Expected: a technician is suggested with reason text
4. Click "Assign" to confirm

### Feature 6: Predictive Maintenance

1. Run manually: Setup > Flow Builder > F360_Nightly_Predictive_Maintenance > Run
2. Check F360__Maintenance_Alert__c records created
3. Check Dispatch Board "Predictive Maintenance Alerts" section

### Feature 7: Customer Booking

1. Configure the Agentforce agent on WhatsApp channel
2. Send a test WhatsApp: "I need a technician for my generator"
3. Agent should ask clarifying questions and offer time slots
4. Confirm a slot — verify F360__Work_Order__c created

---

## POST-DEPLOYMENT MONITORING

### Flows

Setup > Flows > F360_WO_Assigned_Generate_Briefing > View Details
Check "Paused and Failed Flow Interviews" for any failures.

### Agentforce

Setup > Agentforce > Agents > Field360 AI Assistant > Analytics
Monitor: conversations, action success rate, escalations.

### Apex

Setup > Apex Jobs — check for any failed batch or async invocations.

### API Limits

Setup > Company Information > API Requests, Last 24 Hours
MCP tool calls count toward this limit. At 50 technicians, 10 jobs/day = ~500 calls/day. Well within limits.
