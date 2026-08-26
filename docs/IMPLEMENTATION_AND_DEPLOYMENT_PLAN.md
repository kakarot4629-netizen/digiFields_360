# digiField360 Implementation and Deployment Plan

## Current baseline

The four custom objects and their fields are now source-controlled with these API names:

| Specification name           | Project API name       |
| ---------------------------- | ---------------------- |
| `F360__Work_Order__c`        | `Work_Order__c`        |
| `F360__Technician__c`        | `Technician__c`        |
| `F360__Job_History__c`       | `Job_History__c`       |
| `F360__Maintenance_Alert__c` | `Maintenance_Alert__c` |

This is the required mapping for every Apex class, Flow, LWC import, permission set, test, and manifest entry. Do not deploy the existing Apex, LWC, Flows, or permission sets yet: they still reference the old `F360__...` object API names and will fail.

`Technician__c.User__c` is intentionally optional because Salesforce does not support a required lookup to the standard `User` object.

## Phase 1 — Deploy and verify data model

1. Deploy each object folder separately, in this order: `Work_Order__c`, `Technician__c`, `Job_History__c`, `Maintenance_Alert__c`.
2. In Object Manager, confirm the field counts: 23, 12, 14, and 10 respectively.
3. Create the seven User fields from section 3 of the developer specification before any Apex deployment: Skills, First Time Fix Rate, Is Active, Preferred Language, Current Latitude, Current Longitude, and Jobs Completed Total.
4. Confirm all relationship fields point to `Work_Order__c`, `Account`, or `User` as applicable.

Example deployment command:

```powershell
sf project deploy start --target-org field360-dev --source-dir force-app/main/default/objects/Work_Order__c --wait 10
```

Repeat the command for the other three object folders.

## Phase 2 — Align implementation with the deployed schema

Before deploying application metadata, replace these references everywhere in `classes`, `flows`, `lwc`, `permissionsets`, tests, and `package.xml`:

```text
F360__Work_Order__c          -> Work_Order__c
F360__Technician__c          -> Technician__c
F360__Job_History__c         -> Job_History__c
F360__Maintenance_Alert__c   -> Maintenance_Alert__c
```

Required implementation checks:

- Smart Assignment currently queries User-based skills and metrics. Decide whether it uses the seven User fields (as specified) or the `Technician__c` profile fields; use one source consistently.
- Update the Job History and Work Order lookup queries to the new object names.
- Update all LWC `@salesforce/schema` imports to `Work_Order__c`.
- Update every Flow object reference and record-create target.
- Update permission-set `<object>` and `<field>` members.
- Update `package.xml` CustomObject members to the four deployed names.

## Phase 3 — Platform setup (manual)

Before AI components are deployed, enable Agentforce, Einstein, Salesforce Knowledge, Chatter/Files, Salesforce Hosted MCP Server, and Custom Notifications. Create the `F360_Maintenance_Alert_Notification` custom notification type. Publish at least 10 Knowledge articles before production use of troubleshooting.

## Phase 4 — Deploy application metadata

Deploy in this strict order after Phase 2 changes are complete:

1. User fields and custom objects
2. Apex classes and tests
3. GenAI Prompt Templates; publish each template in Prompt Builder
4. Lightning Web Components
5. Permission sets
6. Record-triggered and scheduled Flows
7. Agentforce agent, topics, actions, guardrails, and activation (manual)
8. Lightning Record Page and Dispatch Board App Page (manual)

Do not use a single combined deployment for the first release. Each stage has dependencies on the stage before it.

## Phase 5 — Verification and release gate

1. Run `sf apex run test --test-level RunLocalTests --target-org field360-dev --wait 20`.
2. Confirm at least 75% Apex coverage and no failed tests.
3. Create a Work Order; assign it; verify the Pre-Job Briefing Flow.
4. Complete it; verify service report, ContentVersion, Job History record, and technician count update.
5. Verify Smart Assignment returns recommendations without auto-assigning.
6. Run predictive maintenance manually; verify a Maintenance Alert and preventive Work Order.
7. Assign permission sets to a technician, dispatcher, manager, and AI integration user; test least-privilege access.

## Production deployment gate

Deploy to production only after a sandbox/UAT deployment passes all Phase 5 checks. Take a metadata backup, use a validated deployment, and schedule the nightly predictive-maintenance flow only after historical Job History data has been loaded.
