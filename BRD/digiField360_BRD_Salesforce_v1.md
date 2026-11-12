**digiField360.ai**  
Field Service Management — Salesforce Edition  
**Business Requirements Document v1.0**

<table><tbody><tr><td><strong>Attribute</strong></td><td><strong>Detail</strong></td></tr><tr><td>Product</td><td>digiField360.ai — Salesforce Edition</td></tr><tr><td>Namespace</td><td>DF360__</td></tr><tr><td>Document Type</td><td>Business Requirements Document (BRD)</td></tr><tr><td>Version</td><td>1.0</td></tr><tr><td>Status</td><td>Draft for Review</td></tr><tr><td>Date</td><td>August 2026</td></tr><tr><td>Prepared By</td><td>digiCloud Solutions Product Team</td></tr><tr><td>Org Reference</td><td>Salesforce Enterprise + Agentforce</td></tr><tr><td>Target GA</td><td>Private Beta — Q2 2027</td></tr></tbody></table>

1\. Executive Summary
=====================

digiField360.ai is digiCloud Solutions' second AI-native ISV product, targeting companies with field service technician forces in India and South-East Asia. Where digiSFA automates field sales, digiField360 automates field service — job dispatch, technician scheduling, SLA tracking, spare parts, customer communication, and service manager analytics — all on the Salesforce platform with Agentforce as the AI backbone.  
The Salesforce Edition is built entirely within a Salesforce org using native objects, Apex, LWC, Agentforce Agents, and Flows. No external database is required. The package is delivered under the DF360\_\_ managed namespace and co-exists cleanly with digiSFA (dSFA\_\_) in the same org.

1.1 Problem Statement
---------------------

Field service companies in India — telecom OEMs, consumer electronics brands, FMCG service divisions, industrial equipment OEMs — manage 50–5,000 technicians with a combination of spreadsheets, WhatsApp groups, and manual dispatch calls. The result:

*   SLA breaches go undetected until customer complaints
*   Parts are dispatched to wrong locations; technicians waste hours on parts chase
*   Customer communication is inconsistent — no automated updates
*   Supervisor visibility is zero — no real-time GPS, no live job status
*   CSAT measurement is a monthly survey rather than per-job feedback

1.2 Solution Vision
-------------------

digiField360.ai on Salesforce delivers:

*   AI-driven job scheduling and technician dispatch with SLA-awareness
*   Offline-capable technician mobile app (Flutter, identical to digiSFA mobile)
*   Automated customer WhatsApp updates at every job milestone
*   Spare parts request, approval, and tracking within the same platform
*   Per-job CSAT collected via WhatsApp, aggregated to technician and region scorecards
*   Service manager dashboard with live GPS, SLA RAG status, and Agentforce alerts
*   5 Agentforce agents replacing 80% of supervisor manual interventions

_📌 digiField360 shares the same Salesforce org, Named Credentials, WhatsApp service, and Razorpay integration as digiSFA. Companies running both products get a unified platform at marginal additional cost._

2\. Product Scope and Use Cases
===============================

2.1 In-Scope Use Cases
----------------------

The following ten use cases are confirmed in scope for the Salesforce Edition v1.0:

<table><tbody><tr><td><strong>UC#</strong></td><td><strong>Use Case</strong></td><td><strong>Priority</strong></td><td><strong>Module</strong></td></tr><tr><td>UC-01</td><td>AI-Powered Job Scheduling &amp; Dispatch</td><td>P1 — Launch</td><td>Dispatch AI</td></tr><tr><td>UC-02</td><td>Technician Offline Mobile App</td><td>P1 — Launch</td><td>Mobile</td></tr><tr><td>UC-03</td><td>SLA Tracking &amp; Automated Escalation</td><td>P1 — Launch</td><td>SLA Engine</td></tr><tr><td>UC-04</td><td>Spare Parts Request &amp; Inventory Management</td><td>P1 — Launch</td><td>Parts</td></tr><tr><td>UC-05</td><td>Customer CSAT Collection via WhatsApp</td><td>P1 — Launch</td><td>CSAT</td></tr><tr><td>UC-06</td><td>WhatsApp-First Customer Communication</td><td>P1 — Launch</td><td>Comms</td></tr><tr><td>UC-07</td><td>Service Manager Dashboard &amp; Analytics</td><td>P1 — Launch</td><td>Analytics</td></tr><tr><td>UC-08</td><td>Technician Attendance &amp; GPS Verification</td><td>P2 — v1.1</td><td>Workforce</td></tr><tr><td>UC-09</td><td>Warranty &amp; AMC Contract Management</td><td>P2 — v1.1</td><td>Contracts</td></tr><tr><td>UC-10</td><td>Preventive Maintenance Scheduling</td><td>P3 — v1.2</td><td>PM</td></tr></tbody></table>

### UC-01 — AI-Powered Job Scheduling & Dispatch

When a service request arrives (via WhatsApp, customer portal, email, or manual creation), the Dispatch AI Agent (DF360-001) evaluates all open jobs against technician availability, location, skill set, current workload, and SLA priority. It assigns the optimal technician and sends the job to the mobile app within 60 seconds.  
**Business Rules:**

*   Technician must have the required skill certification for the job type
*   Travel time estimated using Google Maps API via Named Credential
*   Jobs with SLA < 2 hours are always escalated to the first available tech regardless of workload
*   If no technician is available, Service Manager is alerted and a hold queue is maintained
*   Manual override by Service Manager always takes precedence over AI assignment

### UC-02 — Technician Offline Mobile App

The Flutter mobile app allows technicians to receive jobs, update status, capture signatures, upload photos, request parts, record activity, and collect CSAT — all with zero internet. Data syncs automatically when connectivity returns. GPS is logged every 5 minutes.  
**Key App Screens:**

*   Today's Jobs — ordered by SLA urgency; swipe to start, pause, complete
*   Job Detail — customer info, equipment, history, parts list, checklist
*   Parts Request — search parts catalogue, raise request, confirm delivery
*   Activity Log — work done, parts used, observations, photos
*   CSAT Capture — WhatsApp-delivered or in-app rating
*   GuruAI — AI assistant for technical troubleshooting and escalation guidance

### UC-03 — SLA Tracking & Automated Escalation

Every service job has a defined SLA based on contract type, product category, and customer tier. The SLA Engine (a combination of Flows and Agentforce Agent DF360-002) monitors job age against SLA milestones in real time.

<table><tbody><tr><td><strong>SLA Milestone</strong></td><td><strong>Trigger</strong></td><td><strong>Action</strong></td></tr><tr><td>Acknowledgement SLA</td><td>Job not acknowledged in 30 min</td><td>WhatsApp to customer; alert to supervisor</td></tr><tr><td>First Response SLA</td><td>Tech not on-site in X hours per contract</td><td>Alert + auto-reassign attempt</td></tr><tr><td>Resolution SLA (80%)</td><td>80% of SLA time elapsed, job open</td><td>Yellow alert to supervisor; GuruAI intervention</td></tr><tr><td>Resolution SLA (100%)</td><td>SLA breached</td><td>Red alert; escalate to Service Manager; CSAT pre-apology sent</td></tr><tr><td>Repeat Visit</td><td>Same asset, 3rd visit in 30 days</td><td>Escalate to Technical Lead; flag for Root Cause Analysis</td></tr></tbody></table>

### UC-04 — Spare Parts Request & Inventory Management

Technicians request parts from a parts catalogue on the mobile app. Requests flow through an approval step (for high-value parts) before dispatch from the nearest depot. Part usage is recorded against the job for billing and warranty purposes.  
**Parts Workflow:**

*   Technician raises Part Request from the job → type, part code, quantity
*   If part cost ≤ threshold: auto-approved and dispatched from depot stock
*   If part cost > threshold: Service Manager approval required within 2 hours
*   Parts stock at each depot tracked via DF360\_\_Parts\_Stock\_\_c
*   Low stock triggers reorder alert to Procurement via Chatter

### UC-05 — Customer CSAT Collection

Within 15 minutes of job completion, a WhatsApp message is sent to the customer with a rating link (1–5 stars) and an optional comment. Rating is captured in DF360\_\_CSAT\_\_c and rolled up to technician, region, and product category scorecards in real time.  
**CSAT Rules:**

*   Response window: 48 hours. Non-responders are excluded from technician KPI
*   CSAT ≤ 2 triggers immediate alert to Service Manager and auto-schedule of follow-up call
*   CSAT is displayed on technician profile and weighted in AI job assignment

### UC-06 — WhatsApp-First Customer Communication

Customers receive automated WhatsApp messages at every job milestone. No customer portal login required. All messages use approved Meta WhatsApp Business templates delivered via the dSFA\_WhatsAppService shared infrastructure.

<table><tbody><tr><td><strong>Trigger</strong></td><td><strong>Template</strong></td><td><strong>Content</strong></td></tr><tr><td>Job created</td><td>job_confirmation</td><td>Job ID, technician name, ETA window</td></tr><tr><td>Tech en route</td><td>tech_enroute</td><td>Tech name, photo, estimated arrival time</td></tr><tr><td>Tech arrived</td><td>tech_arrived</td><td>Check-in confirmation</td></tr><tr><td>Job completed</td><td>job_completed</td><td>Summary of work done; CSAT link</td></tr><tr><td>SLA at risk</td><td>sla_apology</td><td>Delay notification, revised ETA, apology</td></tr><tr><td>Parts required</td><td>parts_delay</td><td>Parts ordered, return visit scheduled</td></tr></tbody></table>

### UC-07 — Service Manager Dashboard & Analytics

The Service Manager Dashboard (LWC: df360CManagerDashboard) provides a live view of team performance, active jobs, SLA status, GPS positions, parts inventory, and CSAT trends. Agentforce Agent DF360-004 surfaces proactive alerts and recommendations.  
**Dashboard KPIs:**

*   Jobs open / in-progress / completed today
*   SLA compliance % — green ≥ 95%, amber 85–95%, red < 85%
*   First-Time Fix Rate (FTFR) — target ≥ 80%
*   Average resolution time vs SLA
*   CSAT average — today, week, month
*   Parts requests pending approval
*   Technician GPS live map

3\. Stakeholder Requirements
============================

<table><tbody><tr><td><strong>Stakeholder</strong></td><td><strong>Role</strong></td><td><strong>Key Requirements</strong></td></tr><tr><td>Service Technician</td><td>Field user on mobile app</td><td>Receive jobs instantly; work offline; request parts easily; avoid manual paperwork</td></tr><tr><td>Service Manager</td><td>Dashboard user; job dispatcher</td><td>Live visibility of team; SLA alerts before breach; override AI assignments; CSAT trends</td></tr><tr><td>Customer</td><td>End recipient of service</td><td>WhatsApp updates without app download; transparent ETAs; easy CSAT feedback</td></tr><tr><td>Finance Admin</td><td>Parts and billing</td><td>Parts cost tracking per job; warranty vs billable distinction; export to ERP</td></tr><tr><td>Technical Lead</td><td>Escalation handler</td><td>Repeat visit flags; RCA assignment; Knowledge Base for technicians</td></tr><tr><td>HR / Workforce</td><td>Attendance and payroll</td><td>GPS attendance, shift management, travel expense claims</td></tr></tbody></table>

4\. Functional Requirements by Module
=====================================

4.1 Dispatch AI Module
----------------------

<table><tbody><tr><td><strong>Req ID</strong></td><td><strong>Requirement</strong></td><td><strong>Priority</strong></td></tr><tr><td>FR-D01</td><td>System shall assign technician to new job within 60 seconds of creation</td><td>Must Have</td></tr><tr><td>FR-D02</td><td>Assignment algorithm shall consider: technician location, skill set, current workload, SLA urgency</td><td>Must Have</td></tr><tr><td>FR-D03</td><td>Service Manager may override any AI assignment without restriction</td><td>Must Have</td></tr><tr><td>FR-D04</td><td>Unassigned jobs older than 15 minutes shall trigger a supervisor alert</td><td>Must Have</td></tr><tr><td>FR-D05</td><td>System shall support bulk job import via CSV (for maintenance campaigns)</td><td>Should Have</td></tr><tr><td>FR-D06</td><td>Dispatch board shall show job status in Kanban view (New / Assigned / In Progress / Completed)</td><td>Must Have</td></tr></tbody></table>

4.2 SLA Management Module
-------------------------

<table><tbody><tr><td><strong>Req ID</strong></td><td><strong>Requirement</strong></td><td><strong>Priority</strong></td></tr><tr><td>FR-S01</td><td>Each job shall have a calculated SLA deadline based on: contract type, customer tier, product category</td><td>Must Have</td></tr><tr><td>FR-S02</td><td>SLA countdown timer shall be visible on job detail screen and dashboard</td><td>Must Have</td></tr><tr><td>FR-S03</td><td>Automated escalation shall trigger at 80% and 100% of SLA elapsed time</td><td>Must Have</td></tr><tr><td>FR-S04</td><td>SLA breach shall be logged as an event and reported in Service Manager analytics</td><td>Must Have</td></tr><tr><td>FR-S05</td><td>SLA pausing shall be supported when parts are awaited (with manager confirmation)</td><td>Should Have</td></tr><tr><td>FR-S06</td><td>Repeat visit detection: 3+ visits to same asset within 30 days = automatic RCA flag</td><td>Must Have</td></tr></tbody></table>

4.3 Mobile App Module
---------------------

<table><tbody><tr><td><strong>Req ID</strong></td><td><strong>Requirement</strong></td><td><strong>Priority</strong></td></tr><tr><td>FR-M01</td><td>App shall be fully functional offline; all data syncs when connectivity returns</td><td>Must Have</td></tr><tr><td>FR-M02</td><td>GPS check-in at job site shall be required before job status can be set to In Progress</td><td>Must Have</td></tr><tr><td>FR-M03</td><td>Technician shall be able to upload before/after photos from mobile camera</td><td>Must Have</td></tr><tr><td>FR-M04</td><td>Customer digital signature capture shall be mandatory for job completion</td><td>Must Have</td></tr><tr><td>FR-M05</td><td>Parts request shall be raiseable from within the job screen</td><td>Must Have</td></tr><tr><td>FR-M06</td><td>App shall support Hindi and regional language display for technician UI</td><td>Should Have</td></tr></tbody></table>

4.4 Parts & Inventory Module
----------------------------

<table><tbody><tr><td><strong>Req ID</strong></td><td><strong>Requirement</strong></td><td><strong>Priority</strong></td></tr><tr><td>FR-P01</td><td>Parts catalogue shall be searchable by part code, name, or asset model</td><td>Must Have</td></tr><tr><td>FR-P02</td><td>Parts request shall distinguish warranty-covered vs billable parts</td><td>Must Have</td></tr><tr><td>FR-P03</td><td>High-value parts (above configurable threshold) shall require manager approval</td><td>Must Have</td></tr><tr><td>FR-P04</td><td>Stock levels at each depot shall be tracked in real time</td><td>Must Have</td></tr><tr><td>FR-P05</td><td>Low stock alerts shall trigger when stock falls below reorder level</td><td>Must Have</td></tr><tr><td>FR-P06</td><td>Parts returned unused shall be tracked and reconciled to depot inventory</td><td>Should Have</td></tr></tbody></table>

4.5 CSAT & Customer Communication Module
----------------------------------------

<table><tbody><tr><td><strong>Req ID</strong></td><td><strong>Requirement</strong></td><td><strong>Priority</strong></td></tr><tr><td>FR-C01</td><td>CSAT WhatsApp message shall be sent within 15 minutes of job completion</td><td>Must Have</td></tr><tr><td>FR-C02</td><td>CSAT shall capture star rating (1–5) and optional text comment</td><td>Must Have</td></tr><tr><td>FR-C03</td><td>Low CSAT (≤ 2) shall trigger immediate Service Manager alert</td><td>Must Have</td></tr><tr><td>FR-C04</td><td>CSAT responses shall be aggregated to technician and region scorecards</td><td>Must Have</td></tr><tr><td>FR-C05</td><td>Non-responding customers (48 hours) shall be excluded from technician KPI</td><td>Must Have</td></tr><tr><td>FR-C06</td><td>Customer shall receive WhatsApp updates at: job created, tech en route, arrived, completed, SLA at risk</td><td>Must Have</td></tr></tbody></table>

5\. Non-Functional Requirements
===============================

<table><tbody><tr><td><strong>Category</strong></td><td><strong>Requirement</strong></td></tr><tr><td>Performance</td><td>AI dispatch to complete technician assignment within 60 seconds for 95th percentile jobs</td></tr><tr><td>Offline</td><td>Mobile app must function for minimum 8 hours with no connectivity</td></tr><tr><td>Availability</td><td>Salesforce platform SLA: 99.9% uptime (managed by Salesforce)</td></tr><tr><td>Scalability</td><td>Must support up to 5,000 technicians and 50,000 jobs/month in a single org</td></tr><tr><td>Security</td><td>Technician can only see their own jobs. Manager sees only their territory. FLS enforced via Permission Sets</td></tr><tr><td>Data Retention</td><td>Job records retained for 5 years. GPS logs retained for 1 year</td></tr><tr><td>Integration</td><td>WhatsApp API latency &lt; 3 seconds. Google Maps API response &lt; 2 seconds</td></tr><tr><td>Mobile</td><td>App package size &lt; 50MB. Sync time on reconnect &lt; 60 seconds for up to 200 pending records</td></tr><tr><td>Audit</td><td>All job status changes and SLA events must be timestamped and immutable</td></tr></tbody></table>

6\. Data Model — Custom Object Summary
======================================

6.1 Object Count Calculation
----------------------------

The following analysis derives the required custom object count from each module's data storage needs. Objects are grouped by module. Standard Salesforce objects (Account, Contact, Case, User, Task) are leveraged where applicable to avoid duplication.  
_📌 Total confirmed custom objects: 18. This is the object count for the DF360\_\_ namespace Salesforce Edition. Salesforce Enterprise supports up to 800 custom objects per org. digiSFA (dSFA\_\_) has 16 objects; combined DF360 + dSFA = 34 objects, well within platform limits._

<table><tbody><tr><td><strong>#</strong></td><td><strong>Object API Name</strong></td><td><strong>Module</strong></td><td><strong>Description</strong></td><td><strong>Key Fields</strong></td></tr><tr><td>1</td><td>DF360__Service_Job__c</td><td>Dispatch / Core</td><td>Master job record. One per service request.</td><td>Customer, Asset, Technician, Status, SLA_Deadline, Job_Type</td></tr><tr><td>2</td><td>DF360__Technician__c</td><td>Workforce</td><td>Extended profile for field technicians. Linked to User.</td><td>User, Zone, Skills, CSAT_Avg, Active_Jobs, Availability_Status</td></tr><tr><td>3</td><td>DF360__Service_Zone__c</td><td>Workforce / Dispatch</td><td>Geographic service zone; technicians belong to a zone.</td><td>Zone_Name, Manager, Pin_Codes, Active</td></tr><tr><td>4</td><td>DF360__Skill__c</td><td>Workforce</td><td>Catalogue of technician skills / certifications.</td><td>Skill_Name, Category, Certification_Required</td></tr><tr><td>5</td><td>DF360__Technician_Skill__c</td><td>Workforce</td><td>Junction: Technician ↔ Skill with proficiency level and expiry.</td><td>Technician, Skill, Proficiency, Cert_Expiry</td></tr><tr><td>6</td><td>DF360__Asset__c</td><td>Asset Mgmt</td><td>Customer asset (equipment) installed at a location.</td><td>Account, Serial_No, Product, Install_Date, Warranty_Expiry, Location</td></tr><tr><td>7</td><td>DF360__Service_Contract__c</td><td>Contracts</td><td>AMC / warranty contract defining SLA parameters.</td><td>Account, Start_Date, End_Date, SLA_Hours, Contract_Type, Status</td></tr><tr><td>8</td><td>DF360__SLA_Config__c</td><td>SLA Engine</td><td>SLA templates per product category and customer tier.</td><td>Product_Category, Customer_Tier, Ack_SLA_Mins, Resolution_SLA_Hrs</td></tr><tr><td>9</td><td>DF360__Job_Activity__c</td><td>Mobile / Jobs</td><td>Work log entries: observations, time spent, photos.</td><td>Service_Job, Activity_Type, Description, Duration_Min, Photo_URL</td></tr><tr><td>10</td><td>DF360__Part__c</td><td>Parts Catalogue</td><td>Master parts catalogue. One record per SKU.</td><td>Part_Code, Name, Category, Unit_Cost, Compatible_Products, Is_Warranty</td></tr><tr><td>11</td><td>DF360__Parts_Request__c</td><td>Parts Workflow</td><td>Technician request for parts against a job.</td><td>Service_Job, Part, Quantity, Status, Approved_By, Dispatched_Date</td></tr><tr><td>12</td><td>DF360__Parts_Stock__c</td><td>Inventory</td><td>Current stock of each part at each depot.</td><td>Part, Depot, Quantity_Available, Reorder_Level, Last_Updated</td></tr><tr><td>13</td><td>DF360__Depot__c</td><td>Inventory</td><td>Parts depot / warehouse. Technicians draw parts from nearest depot.</td><td>Depot_Name, Zone, Address, GPS_Location, Manager</td></tr><tr><td>14</td><td>DF360__CSAT__c</td><td>CSAT</td><td>Customer satisfaction response per completed job.</td><td>Service_Job, Rating, Comment, Response_Date, Via_WhatsApp</td></tr><tr><td>15</td><td>DF360__SLA_Event__c</td><td>SLA / Audit</td><td>Immutable SLA milestone log (created, acknowledged, breached, etc.).</td><td>Service_Job, Event_Type, Timestamp, Notes</td></tr><tr><td>16</td><td>DF360__GPS_Log__c</td><td>Mobile / Tracking</td><td>Technician GPS position snapshots (every 5 minutes while on shift).</td><td>Technician, Latitude, Longitude, Accuracy, Timestamp, Job</td></tr><tr><td>17</td><td>DF360__WhatsApp_Message__c</td><td>Comms Log</td><td>Log of all outbound WhatsApp messages sent to customers.</td><td>Service_Job, Customer_Mobile, Template, Status, Sent_At, Delivered_At</td></tr><tr><td>18</td><td>DF360__Attendance__c</td><td>Workforce</td><td>Technician daily attendance with GPS-verified check-in.</td><td>Technician, Date, Check_In_Time, Check_In_GPS, Check_Out_Time, Status</td></tr></tbody></table>

6.2 Standard Objects Leveraged (No Custom Object Needed)
--------------------------------------------------------

<table><tbody><tr><td><strong>Standard Object</strong></td><td><strong>Usage in digiField360</strong></td></tr><tr><td>Account</td><td>Customer company (B2B service recipient)</td></tr><tr><td>Contact</td><td>Customer contact person who receives WhatsApp updates</td></tr><tr><td>Case</td><td>Optionally linked to Service_Job__c for Service Cloud integration</td></tr><tr><td>User</td><td>System record for Technician and Service Manager (linked to Technician__c)</td></tr><tr><td>ContentVersion</td><td>Job activity photos and customer signature files</td></tr><tr><td>Task</td><td>Follow-up actions from SLA breach or low CSAT</td></tr><tr><td>FeedItem (Chatter)</td><td>Internal alerts and escalation notifications</td></tr></tbody></table>

6.3 Object Count Rationale
--------------------------

The 18-object count is derived as follows:

<table><tbody><tr><td><strong>Module</strong></td><td><strong>Objects Required</strong></td><td><strong>Count</strong></td></tr><tr><td>Core Job Management</td><td>Service_Job, Job_Activity</td><td>2</td></tr><tr><td>Workforce &amp; Dispatch</td><td>Technician, Service_Zone, Skill, Technician_Skill, Attendance</td><td>5</td></tr><tr><td>Asset &amp; Contract Management</td><td>Asset, Service_Contract, SLA_Config</td><td>3</td></tr><tr><td>Parts &amp; Inventory</td><td>Part, Parts_Request, Parts_Stock, Depot</td><td>4</td></tr><tr><td>Customer &amp; CSAT</td><td>CSAT, WhatsApp_Message</td><td>2</td></tr><tr><td>Audit &amp; Tracking</td><td>SLA_Event, GPS_Log</td><td>2</td></tr><tr><td>TOTAL</td><td></td><td>18</td></tr></tbody></table>

_📌 Each object above maps to at least one confirmed functional requirement in Section 4. No speculative or "nice to have" objects are included. Objects UC-08 (Attendance), UC-09 (Service\_Contract), and UC-10 (PM scheduling) are included because they each require data storage not achievable on existing objects._

7\. Agentforce Agents
=====================

digiField360 deploys five Agentforce agents (DF360-001 through DF360-005). Each agent operates autonomously within defined guardrails, with human override always available.

<table><tbody><tr><td><strong>Agent ID</strong></td><td><strong>Agent Name</strong></td><td><strong>Trigger</strong></td><td><strong>Actions</strong></td><td><strong>Guardrails</strong></td></tr><tr><td>DF360-001</td><td>Dispatch AI</td><td>New Service_Job__c created or unassigned for 15 min</td><td>Query technician availability + location + skills; score and assign; send job to app; notify customer</td><td>Cannot assign to technician with active job at same time slot; Service Manager override always wins</td></tr><tr><td>DF360-002</td><td>SLA Guardian</td><td>Scheduled every 5 min; triggered on job status change</td><td>Calculate SLA remaining; send alerts at 80% and 100%; auto-escalate; generate SLA_Event records</td><td>Cannot close or modify a job; alert only; escalation only</td></tr><tr><td>DF360-003</td><td>Parts Expeditor</td><td>New Parts_Request awaiting approval &gt; 2 hours</td><td>Alert manager; check nearest depot stock; suggest alternate part; auto-approve if below threshold</td><td>Cannot approve &gt; ₹5,000 parts without manager confirmation; cannot dispatch from negative stock</td></tr><tr><td>DF360-004</td><td>Service Analytics Agent</td><td>Daily at 07:00; on-demand query from manager dashboard</td><td>Summarise yesterday's KPIs; flag anomalies; recommend technician scheduling for the day</td><td>Read-only; cannot create or modify records; answers in the manager's language preference</td></tr><tr><td>DF360-005</td><td>Customer Comms Agent</td><td>Job status changes; SLA events; CSAT received ≤ 2</td><td>Send WhatsApp templates; personalise message content; log WhatsApp_Message__c; flag low CSAT</td><td>Only sends approved Meta templates; cannot deviate from template content; rate-limited to Meta API limits</td></tr></tbody></table>

8\. Permission Sets and Roles
=============================

<table><tbody><tr><td><strong>Permission Set</strong></td><td><strong>Target User</strong></td><td><strong>Key Permissions</strong></td></tr><tr><td>DF360_Technician</td><td>Field technician</td><td>Read/Write own Service_Job, Job_Activity, Parts_Request, Attendance, GPS_Log. Read Parts catalogue.</td></tr><tr><td>DF360_ServiceManager</td><td>Service manager / team lead</td><td>Full access to all DF360__ objects for their zone. Can approve Parts_Requests. Cannot delete SLA_Event or GPS_Log.</td></tr><tr><td>DF360_CustomerPortal</td><td>Customer Experience Cloud user</td><td>Read own Service_Job and CSAT. No internal fields visible.</td></tr><tr><td>DF360_PartsAdmin</td><td>Depot / parts administrator</td><td>Full access to Part, Parts_Stock, Depot, Parts_Request. Cannot see CSAT or GPS.</td></tr><tr><td>DF360_Analytics</td><td>Regional director / head of service</td><td>Read all DF360__ objects across zones. No write access.</td></tr><tr><td>DF360_AgentRuntime</td><td>Agentforce system user</td><td>Minimal write: assign technician, update job status, create SLA_Event, create WhatsApp_Message. No delete.</td></tr></tbody></table>

9\. Named Credentials & External Integrations
=============================================

digiField360 shares 5 Named Credentials with digiSFA and adds 2 new ones specific to field service:

<table><tbody><tr><td><strong>Named Credential</strong></td><td><strong>External System</strong></td><td><strong>Usage in DF360</strong></td></tr><tr><td>dSFA_MetaWhatsApp (shared)</td><td>Meta WhatsApp Business API</td><td>Customer communications, CSAT delivery, SLA alerts</td></tr><tr><td>dSFA_GoogleMaps (shared)</td><td>Google Maps Distance Matrix API</td><td>Technician travel time estimation for dispatch scoring</td></tr><tr><td>dSFA_AIService (shared)</td><td>Agentforce / LLM endpoint</td><td>All 5 Agentforce agents; GuruAI for technicians</td></tr><tr><td>dSFA_Razorpay (shared)</td><td>Razorpay Payment Gateway</td><td>Billable job payment collection (UC-09, v1.1)</td></tr><tr><td>dSFA_Firebase (shared)</td><td>Firebase Cloud Messaging</td><td>Push notifications to technician mobile app</td></tr><tr><td>DF360_GoogleVision (new)</td><td>Google Cloud Vision API</td><td>Auto-classify job activity photos; detect part damage</td></tr><tr><td>DF360_ERP (new)</td><td>Customer ERP (SAP / Oracle / Tally)</td><td>Parts cost and billing sync; warranty validation</td></tr></tbody></table>

10\. Salesforce Flows
=====================

<table><tbody><tr><td><strong>Flow Name</strong></td><td><strong>Trigger</strong></td><td><strong>Purpose</strong></td></tr><tr><td>DF360_Job_Created_Dispatch</td><td>After Service_Job insert</td><td>Invoke Dispatch AI Agent (DF360-001); send job creation WhatsApp to customer</td></tr><tr><td>DF360_Job_Status_Changed</td><td>After Service_Job Status update</td><td>Send WhatsApp template; update SLA timeline; log SLA_Event</td></tr><tr><td>DF360_SLA_Monitor_Scheduled</td><td>Scheduled every 5 min</td><td>Check all open jobs against SLA deadlines; trigger escalations via DF360-002</td></tr><tr><td>DF360_Job_Completed_CSAT</td><td>After Service_Job Status = Completed</td><td>Send CSAT WhatsApp via DF360-005 (15 min delay); update technician CSAT rollup</td></tr><tr><td>DF360_Parts_Request_Approval</td><td>After Parts_Request Status = Pending Approval</td><td>Route to manager; auto-approve if below threshold; alert Parts Expeditor agent</td></tr><tr><td>DF360_Low_CSAT_Alert</td><td>After CSAT Rating ≤ 2</td><td>Alert Service Manager; schedule follow-up call task; flag technician profile</td></tr><tr><td>DF360_Low_Stock_Alert</td><td>After Parts_Stock Qty ≤ Reorder_Level</td><td>Chatter post to Depot Manager; create reorder Task</td></tr><tr><td>DF360_Repeat_Visit_Flag</td><td>After Service_Job insert</td><td>Count visits to same asset in last 30 days; flag RCA required if ≥ 3</td></tr></tbody></table>

11\. Implementation Roadmap
===========================

<table><tbody><tr><td><strong>Phase</strong></td><td><strong>Duration</strong></td><td><strong>Deliverables</strong></td></tr><tr><td>Phase 0 — Foundation</td><td>Weeks 1–2</td><td>Org setup, DF360__ namespace, 18 custom objects + fields, Permission Sets, Named Credentials</td></tr><tr><td>Phase 1 — Core Jobs</td><td>Weeks 3–5</td><td>Service_Job CRUD, Dispatch board LWC, SLA configuration, Flows for job status</td></tr><tr><td>Phase 2 — Mobile App</td><td>Weeks 6–9</td><td>Flutter app: job list, offline sync, GPS check-in, photo upload, activity log, signature</td></tr><tr><td>Phase 3 — Agentforce</td><td>Weeks 10–12</td><td>DF360-001 Dispatch AI, DF360-002 SLA Guardian, DF360-005 Customer Comms Agent</td></tr><tr><td>Phase 4 — Parts &amp; CSAT</td><td>Weeks 13–15</td><td>Parts catalogue, stock management, parts request workflow, CSAT collection and analytics</td></tr><tr><td>Phase 5 — Analytics</td><td>Weeks 16–17</td><td>Service Manager dashboard LWC, KPI rollups, DF360-004 Analytics Agent, Tableau integration</td></tr><tr><td>Phase 6 — QA &amp; Beta</td><td>Weeks 18–20</td><td>UAT with 2 pilot customers, bug fixes, performance testing, load testing</td></tr><tr><td>Private Beta GA</td><td>Q2 2027</td><td>Controlled release to early access programme customers</td></tr></tbody></table>

12\. Open Items and Decisions Required
======================================

<table><tbody><tr><td><strong>#</strong></td><td><strong>Open Item</strong></td><td><strong>Owner</strong></td><td><strong>Target Date</strong></td></tr><tr><td>OI-01</td><td>Confirm whether DF360_ERP Named Credential will support SAP BTP or generic REST only for v1.0</td><td>Product</td><td>Sep 2026</td></tr><tr><td>OI-02</td><td>Decide: CSAT via WhatsApp only, or also in-app rating (affects DF360__CSAT__c schema)</td><td>Product</td><td>Sep 2026</td></tr><tr><td>OI-03</td><td>Parts_Stock__c — confirm multi-depot architecture (one record per Part × Depot pair, or nested)</td><td>Architecture</td><td>Sep 2026</td></tr><tr><td>OI-04</td><td>UC-09 Warranty / AMC contracts — confirm whether to use Salesforce Contracts object or custom</td><td>Architecture</td><td>Oct 2026</td></tr><tr><td>OI-05</td><td>Pricing model for v1.0 private beta — per technician/month or per job credit</td><td>Commercial</td><td>Oct 2026</td></tr></tbody></table>

13\. Glossary
=============

<table><tbody><tr><td><strong>Term</strong></td><td><strong>Definition</strong></td></tr><tr><td>SLA</td><td>Service Level Agreement — the maximum allowable time from job creation to resolution</td></tr><tr><td>FTFR</td><td>First-Time Fix Rate — % of jobs resolved on the first technician visit</td></tr><tr><td>CSAT</td><td>Customer Satisfaction Score — per-job rating collected via WhatsApp</td></tr><tr><td>Dispatch AI</td><td>Agentforce Agent DF360-001 that assigns technicians to jobs automatically</td></tr><tr><td>RCA</td><td>Root Cause Analysis — investigation triggered on repeat visits or chronic failures</td></tr><tr><td>GPS Log</td><td>Periodic technician location snapshot stored in DF360__GPS_Log__c</td></tr><tr><td>Parts Stock</td><td>Inventory record in DF360__Parts_Stock__c tracking qty at each depot</td></tr><tr><td>AMC</td><td>Annual Maintenance Contract — a Service_Contract__c with SLA obligations</td></tr><tr><td>FSM</td><td>Field Service Management — the product category that digiField360 belongs to</td></tr><tr><td>DF360__</td><td>Salesforce managed package namespace for digiField360</td></tr><tr><td>dSFA__</td><td>Salesforce managed package namespace for digiSFA (separate product, same org)</td></tr></tbody></table>