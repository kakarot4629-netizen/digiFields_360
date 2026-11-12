# digiField360 AI — Master Business & Technical Requirements Specification

> **Document Type**: Comprehensive Master Requirements Document (MRD / BRD / Technical Specification)  
> **Product Name**: digiField360.ai — Salesforce Edition  
> **Target Version**: v1.0 (Commercial Edition)  
> **Platform Stack**: Salesforce Enterprise (API v61.0/v67.0) | Agentforce | Node.js MCP Gateway | Flutter / Cross-Platform Mobile  
> **Repository Root**: `c:\digiField 360\digiFields_360`  
> **Last Updated**: August 2026  

---

## 📋 Table of Contents

1. [Executive Summary & Problem Statement](#1-executive-summary--problem-statement)
2. [Stakeholders, Personas & User Roles](#2-stakeholders-personas--user-roles)
3. [End-to-End System Architecture](#3-end-to-end-system-architecture)
4. [Functional Requirements by Module](#4-functional-requirements-by-module)
   - [4.1 Job Lifecycle & Dispatch AI Module](#41-job-lifecycle--dispatch-ai-module)
   - [4.2 SLA Engine & Escalation Module](#42-sla-engine--escalation-module)
   - [4.3 Spare Parts & Multi-Depot Inventory Module](#43-spare-parts--multi-depot-inventory-module)
   - [4.4 Customer Communication & WhatsApp Integration](#44-customer-communication--whatsapp-integration)
   - [4.5 CSAT Collection & Quality Management](#45-csat-collection--quality-management)
   - [4.6 Technician Workforce & Geofenced Attendance](#46-technician-workforce--geofenced-attendance)
   - [4.7 Asset Management & AMC/Warranty Contracts](#47-asset-management--amcwarranty-contracts)
   - [4.8 Agentforce Multi-Agent AI Suite](#48-agentforce-multi-agent-ai-suite)
5. [Complete Data Model (18 Custom Objects + 3 Platform Events)](#5-complete-data-model-18-custom-objects--3-platform-events)
6. [Apex Backend, Triggers & Batch Architecture](#6-apex-backend-triggers--batch-architecture)
7. [Salesforce Declarative Automation (8 Flows)](#7-salesforce-declarative-automation-8-flows)
8. [Lightning Web Components Suite (12 Components)](#8-lightning-web-components-suite-12-components)
9. [Mobile App & MCP Server Gateway Specification](#9-mobile-app--mcp-server-gateway-specification)
10. [External Integrations & Named Credentials](#10-external-integrations--named-credentials)
11. [Security, Roles & Permission Sets](#11-security-roles--permission-sets)
12. [Non-Functional Requirements & Platform Guardrails](#12-non-functional-requirements--platform-guardrails)
13. [Traceability Matrix & Implementation Roadmap (Phases 0–6)](#13-traceability-matrix--implementation-roadmap-phases-06)

---

## 1. Executive Summary & Problem Statement

### 1.1 Business Problem
Field service companies across India and South-East Asia (Telecom OEMs, Consumer Electronics, Industrial Equipment, HVAC, Power) manage between 50 and 5,000 field technicians using disjointed tools: spreadsheets, WhatsApp groups, and manual phone dispatches.

This results in:
* **Undetected SLA Breaches**: Escalations happen only after customer complaints.
* **Parts Chase & Misrouting**: Technicians travel to customer sites without knowing required parts or nearest depot availability.
* **Lack of Real-Time Visibility**: Supervisors cannot see real-time technician GPS locations or job statuses.
* **Inconsistent Customer Communication**: Customers receive sporadic or zero automated status updates.
* **Delayed CSAT**: Customer satisfaction is captured via monthly surveys instead of per-job feedback.
* **FSL Licensing Overhead**: Standard Salesforce Field Service (FSL) costs **$175/user/month**, which is prohibitive for large technician fleets.

### 1.2 The digiField360 Solution
**digiField360.ai** is an AI-native Field Service Management solution built on standard **Salesforce Lightning Platform (Enterprise Edition)** and **Agentforce**, operating on standard Salesforce Platform User licenses ($25/user/month) to save up to **85% in licensing costs**:
* **AI-Powered Autonomous Dispatch**: 60-second automated technician assignment considering skills, location, workload, and SLA priority.
* **Real-Time SLA Engine**: Proactive 80% and 100% breach monitoring with immutable audit logging.
* **Multi-Depot Parts Inventory & Approval**: Streamlined request workflow, stock reservations, and depot reorder alerts.
* **WhatsApp-First Customer Experience**: Milestone notifications (`job_confirmation`, `tech_enroute`, `tech_arrived`, `job_completed`) and post-job CSAT surveys via Meta WhatsApp Business API.
* **Offline-First Mobile Architecture**: Flutter / React Native client with local SQLite cache, FIFO mutation replay queue, GPS breadcrumbs, and digital signature capture.
* **5 Dedicated Agentforce Agents**: Replacing 80% of supervisor manual coordination.

---

## 2. Stakeholders, Personas & User Roles

| Persona | Primary Interface | Key Needs & Responsibilities |
| :--- | :--- | :--- |
| **Field Service Technician** | Offline Mobile App | Receive today's assigned jobs, view equipment history, GPS check-in, request parts, upload photos, capture customer signatures, get AI troubleshooting help. |
| **Service Manager / Supervisor** | Desktop Lightning Console & Dispatch Board | Monitor live technician GPS map, view Kanban dispatch board, override AI assignments, approve high-value parts requests (>₹5,000), handle low-CSAT escalations. |
| **Depot / Inventory Admin** | Desktop Parts Inventory LWC | Manage depot stock levels, fulfill parts requisitions, track reorder thresholds, reconcile returned parts. |
| **Service Director / Head of Service** | Manager Analytics Dashboard | Track First-Time Fix Rate (FTFR), SLA compliance RAG scorecards, CSAT trends, regional technician efficiency. |
| **Customer (B2B / B2C)** | WhatsApp Messaging (Zero App Download) | Receive transparent ETA updates, technician contact & photo, delay apologies, and rate service via 1–5 star WhatsApp survey. |
| **Agentforce AI Agents** | Autonomous Background System Users | Execute dispatch scoring, SLA monitoring, parts expediting, daily analytics rollups, and WhatsApp communications. |

---

## 3. End-to-End System Architecture

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               1. MOBILE CLIENT TIER                                    │
│                    (Flutter 3.x / React Native Offline-First)                          │
│                                                                                        │
│   ┌─────────────────────┐    ┌───────────────────────────┐    ┌────────────────────┐   │
│   │  UI Screens & Views │    │   Local SQLite Database   │    │ FIFO Mutation Queue│   │
│   │  (Jobs, Parts, GPS) │    │  (Offline Cache Engine)   │    │  (Replay on Sync)  │   │
│   └──────────┬──────────┘    └─────────────┬─────────────┘    └─────────┬──────────┘   │
│              └─────────────────────────────┼────────────────────────────┘              │
│                                            ▼                                           │
│                              ┌───────────────────────────┐                             │
│                              │   OfflineMCPGateway.js    │                             │
│                              └─────────────┬─────────────┘                             │
└────────────────────────────────────────────┼───────────────────────────────────────────┘
                                             │ HTTPS / REST / JSON-RPC 2.0
                                             ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                           2. BACKEND & INTEGRATION TIER                                │
│                                                                                        │
│   ┌─────────────────────────────────────────┐   ┌──────────────────────────────────┐   │
│   │    Node.js MCP Gateway Server           │   │    Meta WhatsApp Business API    │   │
│   │    (scripts/mcp-server.js)              │   │    (Customer Milestone Comms)    │   │
│   └────────────────────┬────────────────────┘   └──────────────────┬───────────────┘   │
│                        │                                           │                   │
│                        └─────────────────────┬─────────────────────┘                   │
│                                              ▼                                         │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │         Salesforce Platform Enterprise Edition (Apex REST / Invocable)         │   │
│   │         Named Credentials: dSFA_MetaWhatsApp | dSFA_GoogleMaps | dSFA_Firebase │   │
│   └──────────────────────────────────────────┬─────────────────────────────────────┘   │
└──────────────────────────────────────────────┼─────────────────────────────────────────┘
                                               │
                                               ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        3. CORE SALESFORCE PLATFORM TIER                                │
│                                                                                        │
│  ┌───────────────────────┐  ┌───────────────────────┐  ┌───────────────────────────┐   │
│  │   18 Custom Objects   │  │   14 Apex Controllers │  │  8 Declarative Flows      │   │
│  │   3 Platform Events   │  │   4 Triggers + 5 Batch│  │  Status, SLA & Alerts     │   │
│  └───────────┬───────────┘  └───────────┬───────────┘  └─────────────┬─────────────┘   │
│              │                          │                            │                 │
│              └──────────────────────────┼────────────────────────────┘                 │
│                                         ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                        5 Autonomous Agentforce Agents                           │   │
│  │    DF360-001 (Dispatch) | DF360-002 (SLA) | DF360-003 (Parts)                   │   │
│  │    DF360-004 (Analytics) | DF360-005 (Customer Comms)                           │   │
│  └──────────────────────────────────────┬──────────────────────────────────────────┘   │
│                                         ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                   12 Lightning Web Components (Desktop UI)                      │   │
│  │    Dispatch Board | Manager Dashboard | Live GPS Map | Parts Approval | CSAT    │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Functional Requirements by Module

### 4.1 Job Lifecycle & Dispatch AI Module
* **FR-D01 (Auto-Dispatch SLA)**: When a `Service_Job__c` is created, Dispatch AI (`DF360-001`) must score and assign an eligible technician within **60 seconds**.
* **FR-D02 (Dispatch Scoring Algorithm)**:
  $$\text{Score} = (\text{Skill Match} \times 0.40) + (\text{Proximity Score} \times 0.30) + (\text{FTFR \%} \times 0.20) + (\text{Workload Inverted} \times 0.10)$$
* **FR-D03 (Supervisor Override)**: Service Managers can manually override any AI job assignment without restriction.
* **FR-D04 (Unassigned Queue Alert)**: Jobs remaining unassigned for $> 15\text{ minutes}$ trigger high-priority alerts to the zone supervisor.
* **FR-D05 (Kanban Dispatch Board)**: Interactive drag-and-drop board (`df360CDispatchBoard`) displaying jobs categorized by status: `New`, `Assigned`, `En Route`, `On Site`, `In Progress`, `Parts Awaited`, `Completed`.

### 4.2 SLA Engine & Escalation Module
* **FR-S01 (Tiered SLA Calculation)**: SLA deadlines (`Ack_SLA_Mins__c`, `Response_SLA_Hrs__c`, `Resolution_SLA_Hrs__c`) are automatically calculated from `SLA_Config__c` based on `Customer_Tier__c`, `Product_Category__c`, and `Priority__c`.
* **FR-S02 (Proactive Escalations)**:
  - **80% Elapsed Time**: Generates yellow alert to supervisor and publishes `DF360_SLA_Alert__e` with severity `Warning`.
  - **100% SLA Breach**: Generates red alert, creates immutable `SLA_Event__c` record, triggers auto-apology WhatsApp message, and escalates to Service Manager.
* **FR-S03 (SLA Pausing)**: SLA clock can be placed on hold when job status is `Parts Awaited` upon manager approval.
* **FR-S04 (Repeat Visit Detection & RCA)**: When an asset receives $\ge 3\text{ service visits in } 30\text{ days}$, the system automatically flags `Is_Repeat_Visit__c = true` and creates a Root Cause Analysis (RCA) task for the Technical Lead.

### 4.3 Spare Parts & Multi-Depot Inventory Module
* **FR-P01 (Catalogue Search)**: Technicians can search parts catalogue (`Part__c`) by SKU, name, or compatible asset category on mobile.
* **FR-P02 (Approval Threshold)**: Parts requests with total value $> \text{₹}5,000$ route to the Service Manager for approval; requests below threshold are auto-approved.
* **FR-P03 (Inventory Reservation & Stock Decrement)**: Approving a `Parts_Request__c` reserves quantity in `Parts_Stock__c` and decrements `Quantity_Available__c` at the assigned `Depot__c`.
* **FR-P04 (Low Stock Alerts)**: When `Parts_Stock__c.Quantity_Available__c <= Reorder_Level__c`, automated notification is sent to the Depot Manager.
* **FR-P05 (Warranty vs. Billable)**: System flags whether a part is covered under active warranty (`Is_Warranty_Item__c`) or is billable to the customer.

### 4.4 Customer Communication & WhatsApp Integration
* **FR-C01 (Milestone WhatsApp Notifications)**: Outbound WhatsApp messages using approved Meta templates triggered via `DF360_WhatsAppService`:
  1. `job_confirmation`: Sent immediately on job creation with Job ID and ETA window.
  2. `tech_enroute`: Sent when technician starts journey, including technician name, phone, and live arrival ETA.
  3. `tech_arrived`: Sent on GPS-verified on-site check-in.
  4. `parts_delay`: Sent when job enters `Parts Awaited` status with revised ETA.
  5. `sla_apology`: Sent if job breaches SLA deadline.
  6. `job_completed`: Sent upon completion with executive summary and CSAT rating link.
* **FR-C02 (Immutable Message Audit)**: Every outbound/inbound WhatsApp interaction is logged in `WhatsApp_Message__c` with timestamp and delivery status (`Sent`, `Delivered`, `Read`, `Failed`).

### 4.5 CSAT Collection & Quality Management
* **FR-CS01 (15-Minute Delayed CSAT Dispatch)**: WhatsApp survey sent exactly 15 minutes after job status is updated to `Completed`.
* **FR-CS02 (Rating Ingestion)**: Captures 1–5 star rating and optional customer text comment into `CSAT__c`.
* **FR-CS03 (Low CSAT Immediate Alert)**: Rating $\le 2$ stars triggers an immediate alert to the Service Manager and schedules a priority follow-up call task.
* **FR-CS04 (Nightly Metric Rollup)**: `DF360_CSATRollupBatch` calculates rolling 30-day average CSAT (`CSAT_Avg_30d__c`) and First-Time Fix Rate (`FTFR_Pct__c`) on `Technician__c`.

### 4.6 Technician Workforce & Geofenced Attendance
* **FR-W01 (GPS Shift Check-In/Out)**: Technicians log daily attendance (`Attendance__c`) with GPS coordinates verified against depot/zone geofence.
* **FR-W02 (Periodic GPS Breadcrumb Stream)**: Mobile app streams GPS snapshots every 5 minutes into `GPS_Log__c` (retained for 365 days).
* **FR-W03 (Mandatory On-Site Check-In)**: Status cannot change to `On Site` or `In Progress` unless GPS coordinates match customer asset location within $200\text{ meters}$ (or supervisor PIN override).
* **FR-W04 (Digital Signature & Photo Capture)**: Mandatory customer signature URL and before/after photos uploaded to `ContentVersion` before a job can be marked `Completed`.

### 4.7 Asset Management & AMC/Warranty Contracts
* **FR-A01 (Asset Registry)**: Centralized equipment registry (`Asset__c`) tracking serial number, model, installation date, warranty expiry date, and site GPS location.
* **FR-A02 (Service Contracts & AMC)**: Tracks contract coverage (`Service_Contract__c`), annual visit caps, and response/resolution SLAs.
* **FR-A03 (Contract Expiration Warnings)**: `DF360_ContractExpiryBatch` alerts Account Managers 30 days prior to contract expiry.

### 4.8 Agentforce Multi-Agent AI Suite
* **DF360-001 (Dispatch AI Agent)**: Evaluates jobs, technicians, proximity, and skills; assigns in < 60s.
* **DF360-002 (SLA Guardian Agent)**: Proactive SLA monitor; sends 80%/100% alerts and triggers customer delay communications.
* **DF360-003 (Parts Expeditor Agent)**: Monitors pending requests $> 2\text{ hours}$; suggests alternative depots/SKUs.
* **DF360-004 (Service Analytics Agent)**: Daily 07:00 AM KPI summaries and natural-language query responses for managers.
* **DF360-005 (Customer Comms Agent)**: Autonomous WhatsApp messaging and CSAT survey management.

---

## 5. Complete Data Model (18 Custom Objects + 3 Platform Events)

| # | Object API Name | Type | Key Fields & Relationships | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **1** | `Service_Job__c` | Master Transaction | `Account__c` (Lookup), `Asset__c` (Lookup), `Technician__c` (Lookup), `Zone__c` (Lookup), `Status__c`, `Priority__c`, `Job_Type__c`, `SLA_Deadline__c`, `SLA_Status__c`, `Check_In_Time__c`, `Completed_Time__c`, `Resolution_Time_Min__c`, `Is_First_Time_Fix__c`, `Customer_Signature_URL__c`, `Product_Category__c` | Master service job ticket. |
| **2** | `Job_Activity__c` | Master-Detail Child | `Service_Job__c` (Lookup), `Technician__c` (Lookup), `Activity_Type__c`, `Description__c`, `Duration_Min__c`, `Photo_URL__c`, `Part__c` (Lookup), `Quantity_Used__c` | Granular work log entries, parts consumed, time spent, photos. |
| **3** | `Technician__c` | Workforce Master | `User__c` (Lookup), `Name__c`, `Zone__c` (Lookup), `Availability_Status__c`, `CSAT_Avg_30d__c`, `FTFR_Pct__c`, `Active_Job_Count__c`, `Current_GPS_Latitude__c`, `Current_GPS_Longitude__c`, `Mobile__c`, `FCM_Token__c`, `Employee_Code__c` | Technician master profile linked 1:1 with Salesforce User. |
| **4** | `Service_Zone__c` | Territory Config | `Zone_Name__c`, `Manager__c` (Lookup User), `Pin_Codes__c`, `Technician_Count__c`, `Is_Active__c` | Geographic service zones and postal code coverage. |
| **5** | `Skill__c` | Master Config | `Skill_Name__c`, `Category__c`, `Cert_Required__c`, `Description__c` | Master skills and technical certification catalogue. |
| **6** | `Technician_Skill__c` | Junction Object | `Technician__c` (Lookup), `Skill__c` (Lookup), `Proficiency__c`, `Cert_Expiry__c`, `Is_Active__c` | Maps technician capabilities, skill levels, and certification expiry. |
| **7** | `Asset__c` | Equipment Master | `Account__c` (Lookup), `Serial_Number__c`, `Product_Name__c`, `Product_Category__c`, `Install_Date__c`, `Warranty_Expiry__c`, `Is_Under_Warranty__c`, `Location_Address__c`, `GPS_Location__c`, `Visit_Count_30d__c`, `Zone__c` | Customer equipment installed on site. |
| **8** | `Service_Contract__c` | Contract Master | `Account__c` (Lookup), `Contract_Type__c`, `Start_Date__c`, `End_Date__c`, `SLA_Ack_Mins__c`, `SLA_Response_Hrs__c`, `SLA_Resolution_Hrs__c`, `Max_Visits_Per_Year__c`, `Status__c` | AMC / Warranty contracts governing SLA obligations. |
| **9** | `SLA_Config__c` | SLA Matrix Config | `Product_Category__c`, `Customer_Tier__c`, `Priority__c`, `Ack_SLA_Mins__c`, `Response_SLA_Hrs__c`, `Resolution_SLA_Hrs__c`, `Is_Active__c` | Matrix templates defining SLA resolution windows. |
| **10** | `Part__c` | Catalogue Master | `Part_Code__c`, `Category__c`, `Unit_Cost__c`, `Compatible_Products__c`, `Is_Warranty_Item__c`, `Lead_Time_Days__c`, `ERP_SKU__c`, `Is_Active__c` | Master spare parts catalogue and SKUs. |
| **11** | `Parts_Request__c` | Requisition Master | `Service_Job__c` (Lookup), `Technician__c` (Lookup), `Part__c` (Lookup), `Depot__c` (Lookup), `Quantity__c`, `Status__c`, `Approved_By__c`, `Approved_At__c`, `Dispatched_At__c`, `Delivered_At__c`, `Is_Warranty__c`, `Rejection_Reason__c` | Parts ordering and supervisor approval workflow. |
| **12** | `Parts_Stock__c` | Inventory Junction | `Part__c` (Lookup), `Depot__c` (Lookup), `Quantity_Available__c`, `Quantity_Reserved__c`, `Reorder_Level__c`, `Last_Updated__c` | Live inventory balance per part per warehouse. |
| **13** | `Depot__c` | Warehouse Master | `Address__c`, `Zone__c` (Lookup), `Manager__c` (Lookup User), `GPS_Location__c`, `Is_Active__c` | Regional depots and warehouse distribution centers. |
| **14** | `CSAT__c` | Survey Feedback | `Service_Job__c` (Lookup), `Rating__c` (1–5), `Comment__c`, `Customer_Mobile__c`, `Response_Date__c`, `Via_WhatsApp__c`, `Is_Responded__c`, `Alert_Sent__c` | Per-job customer satisfaction ratings. |
| **15** | `SLA_Event__c` | Audit Log | `Service_Job__c` (Lookup), `Event_Type__c`, `Event_Timestamp__c`, `SLA_Remaining_Hrs__c`, `Notes__c` | Immutable milestone log for SLA audits and forensics. |
| **16** | `GPS_Log__c` | Telemetry Log | `Technician__c` (Lookup), `Latitude__c`, `Longitude__c`, `Accuracy_M__c`, `Battery_Pct__c`, `Active_Job__c` (Lookup), `Log_Timestamp__c` | 5-minute periodic technician GPS snapshots (365-day retention). |
| **17** | `WhatsApp_Message__c` | Comms Log | `Service_Job__c` (Lookup), `Customer_Mobile__c`, `Template__c`, `Message_Body__c`, `Status__c`, `Sent_At__c`, `Delivered_At__c`, `Error_Code__c` | Outbound/inbound WhatsApp communication ledger. |
| **18** | `Attendance__c` | Workforce Shift | `Technician__c` (Lookup), `Attendance_Date__c`, `Check_In_Time__c`, `Check_Out_Time__c`, `Check_In_Latitude__c`, `Check_In_Longitude__c`, `Status__c`, `Leave_Type__c`, `Hours_Worked__c`, `Notes__c` | Daily technician attendance with GPS verification. |

### Platform Event Definitions
1. **`DF360_Job_Assigned__e`**: Fields: `Job_Id__c`, `Technician_Id__c`, `SLA_Deadline__c`, `Zone_Id__c` (Fires instant push notification to mobile).
2. **`DF360_SLA_Alert__e`**: Fields: `Job_Id__c`, `Severity__c`, `Remaining_Minutes__c`, `Escalation_Level__c` (Streaming updates to manager dashboard).
3. **`DF360_Parts_Approved__e`**: Fields: `Request_Id__c`, `Job_Id__c`, `Depot_Id__c`, `Part_Code__c` (Notifies technician when parts are ready).

---

## 6. Apex Backend, Triggers & Batch Architecture

### 6.1 Service Controllers (14 Classes)
1. **`DF360_ServiceJobController`**: Full CRUD, status transitions, check-in GPS validation, job completion, and dynamic dispatch board query.
2. **`DF360_TechnicianController`**: Shift availability toggle, morning job payload retrieval, live GPS coordinate caching.
3. **`DF360_DispatchController`**: AI technician scoring engine (Skill certification match + Proximity + FTFR + Workload).
4. **`DF360_SLAController`**: SLA deadline calculation against `SLA_Config__c` and immutable `SLA_Event__c` logging.
5. **`DF360_PartsController`**: Catalogue search, approval routing (>₹5,000), stock reservation, and dispatch management.
6. **`DF360_CSATController`**: WhatsApp survey delivery and rating response ingestion.
7. **`DF360_WhatsAppService`**: Meta API callout client formatting approved templates.
8. **`DF360_GPSController`**: Mobile REST telemetry ingestion and manager map coordinate feed.
9. **`DF360_AttendanceController`**: Geofenced shift check-in/out and leave tracking.
10. **`DF360_AssetController`**: Asset history timeline, warranty validation, and repeat visit tracking.
11. **`DF360_AnalyticsController`**: Service KPI rollups (FTFR %, SLA RAG compliance %, CSAT trends).
12. **`DF360_GuruAIController`**: Mobile AI troubleshooting context provider.
13. **`DF360_MobileAPIController`**: Unified `@RestResource` endpoint for offline mobile sync.
14. **`DF360_ConfigService`**: Global configuration settings and approval thresholds.

### 6.2 Apex Triggers & Helpers (4 Triggers + 2 Helpers)
* **`DF360_ServiceJobTrigger`**: Auto-computes SLA deadline on insert; fires `DF360_Job_Assigned__e` and logs SLA creation events.
* **`DF360_PartsRequestTrigger`**: Validates stock availability, checks approval threshold, and fires `DF360_Parts_Approved__e`.
* **`DF360_CSATTrigger`**: Triggers immediate manager alert on rating $\le 2$.
* **`DF360_GPSLogTrigger`**: Updates `Technician__c.Current_GPS_Latitude__c` / `Longitude__c` on each snapshot.
* **Trigger Helpers**: `DF360_ServiceJobTriggerHelper`, `DF360_CSATTriggerHelper` (Asynchronous `@future` callouts avoiding mixed DML).

### 6.3 Batch & Scheduled Apex (5 Classes)
* **`DF360_SLAMonitorBatch`** *(Scheduled every 5 minutes)*: Scans open jobs, evaluates elapsed SLA, triggers 80%/100% warnings, publishes `DF360_SLA_Alert__e`.
* **`DF360_CSATRollupBatch`** *(Nightly at 00:30)*: Recalculates 30-day average CSAT and FTFR % for all active technicians.
* **`DF360_GPSLogRetentionBatch`** *(Daily at 01:00)*: Deletes GPS logs older than 365 days.
* **`DF360_ContractExpiryBatch`** *(Daily at 07:00)*: Flags contracts expiring in 30 days.
* **`DF360_CertExpiryBatch`** *(Daily at 07:30)*: Flags technician certifications expiring in 30 days.

---

## 7. Salesforce Declarative Automation (8 Flows)

1. **`DF360_Job_Created_Dispatch`**: Record-triggered on `Service_Job__c` insert; invokes Dispatch AI agent and triggers `job_confirmation` WhatsApp.
2. **`DF360_Job_Status_Changed`**: Record-triggered on Status update; sends milestone WhatsApp messages (`tech_enroute`, `tech_arrived`, `parts_delay`) and logs `SLA_Event__c`.
3. **`DF360_SLA_Monitor_Scheduled`**: Scheduled flow invoking `DF360_SLAMonitorBatch`.
4. **`DF360_Job_Completed_CSAT`**: Scheduled path flow triggering CSAT WhatsApp survey 15 minutes after completion.
5. **`DF360_Parts_Request_Approval`**: Approval routing for requests with total value $> \text{₹}5,000$.
6. **`DF360_Low_CSAT_Alert`**: Record-triggered on `CSAT__c` rating $\le 2$; creates urgent follow-up task and alerts manager.
7. **`DF360_Low_Stock_Alert`**: Record-triggered on `Parts_Stock__c` when stock $\le$ reorder level; alerts Depot Manager.
8. **`DF360_Repeat_Visit_Flag`**: Record-triggered on `Service_Job__c` insert; counts visits in last 30 days and flags RCA task if $\ge 3$.

---

## 8. Lightning Web Components Suite (12 Components)

| Component Name | Primary User | Core Features & Architecture |
| :--- | :--- | :--- |
| **`df360CManagerDashboard`** | Service Manager / Director | Executive KPI tiles (Open Jobs, SLA Compliance %, FTFR %, CSAT Avg), real-time platform event listener, date range picker. |
| **`df360CGPSMap`** | Service Manager | Google Maps embed with live technician markers color-coded by availability (`Available`, `On Job`, `On Break`, `Off Shift`). |
| **`df360CDispatchBoard`** | Service Manager / Dispatcher | Kanban board categorized by status, drag-and-drop reassignment, live SLA countdown timer chips. |
| **`df360CPartsApproval`** | Service Manager | Supervisor approval inbox for pending parts requests with one-click approve/reject actions. |
| **`df360CSLAReport`** | Service Manager / Director | SLA compliance matrix and breach breakdown by zone, technician, and job priority with Excel export. |
| **`df360CCSATScorecard`** | Service Manager / Director | Rolling CSAT trends, technician leaderboards, and low-score drill-down view. |
| **`df360CPartsInventory`** | Depot Admin | Multi-depot stock level monitor with low-stock red alerts and reorder triggers. |
| **`df360CTechnicianProfile`** | Service Manager | 360° technician profile showing skill certs, CSAT, FTFR, active job, and GPS telemetry. |
| **`df360CAssetHistory`** | Service Manager / Lead | Equipment service history timeline, repeat visit badges, and RCA links. |
| **`df360CGuruAIChat`** | Service Manager | Natural language conversational interface for supervisor analytics and technician guidance. |
| **`df360CJobCreator`** | Admin / Dispatcher | Rapid job creation modal with asset serial lookup, contract SLA preview, and technician recommendation. |
| **`df360CServiceJobDetail`** | Service Manager | 360° job record page displaying timeline, activities, parts consumed, SLA audit trail, and signature. |

---

## 9. Mobile App & MCP Server Gateway Specification

### 9.1 Offline Synchronization Architecture
* **Local SQLite Cache**: Stores today's job assignments, parts catalogue, customer asset details, and knowledge articles.
* **FIFO Mutation Queue (`OfflineMCPGateway.js`)**: All offline actions (status updates, parts consumed, hours logged, signatures) are assigned a client UUID and stored in local queue.
* **Replay Sync Protocol**: When internet connectivity is restored, the queue replays sequentially against `/api/sync/offline-queue` with last-write-wins conflict resolution.

### 9.2 Mobile REST API Endpoints (`scripts/mcp-server.js`)
* `GET /api/sync/morning-payload`: Downloads today's assigned jobs, technician profile, and parts catalogue in $< 5\text{ seconds}$.
* `POST /api/sync/offline-queue`: Ingests queued offline mutation batches.
* `POST /api/technician/location`: Ingests 5-minute GPS coordinate snapshots.
* `POST /api/work-orders/:id/complete`: Submits digital signature, photo attachments, resolution duration, and marks job completed.
* `POST /api/ai/troubleshoot`: Multi-lingual on-site AI diagnostic assistant (English, Hindi, Marathi, Tamil, Telugu).

---

## 10. External Integrations & Named Credentials

| Named Credential | External Service | Usage & Payload |
| :--- | :--- | :--- |
| **`DF360_MetaWhatsApp`** | Meta WhatsApp Business API | Customer milestone messages and CSAT rating links. |
| **`DF360_GoogleMaps`** | Google Maps Distance Matrix API | Technician travel time and distance calculation for dispatch scoring. |
| **`DF360_AIService`** | Salesforce Agentforce / Einstein LLM | AI troubleshooting context and GuruAI natural language chat. |
| **`DF360_Firebase`** | Firebase Cloud Messaging (FCM) | Real-time push notifications of new job assignments to mobile app. |
| **`DF360_GoogleVision`** | Google Cloud Vision API | Automated classification of uploaded job activity photos and damage detection. |
| **`DF360_ERP`** | Customer ERP (SAP / Oracle / Tally) | Daily parts cost synchronization, inventory adjustments, and warranty verification. |

---

## 11. Security, Roles & Permission Sets

| Permission Set | Target Persona | Object & Field Permissions |
| :--- | :--- | :--- |
| **`DF360_Technician`** | Field Technician | Read/Write own `Service_Job__c`, `Job_Activity__c`, `Parts_Request__c`, `Attendance__c`, `GPS_Log__c`. Read-only access to `Part__c` catalogue. Cost fields hidden. |
| **`DF360_ServiceManager`** | Zone Manager / Supervisor | Full Read/Write access to all `DF360` objects within their assigned `Service_Zone__c`. Parts approval authority. Cannot delete `SLA_Event__c` or `GPS_Log__c`. |
| **`DF360_PartsAdmin`** | Depot / Warehouse Admin | Full Read/Write access to `Part__c`, `Parts_Stock__c`, `Depot__c`, `Parts_Request__c`. No access to `CSAT__c` or `GPS_Log__c`. |
| **`DF360_Analytics`** | Service Director / Executive | Read-only access to all `DF360` objects across all zones. Access to manager dashboards and reports. |
| **`DF360_CustomerPortal`** | Experience Cloud Customer | Read-only access to own `Service_Job__c` and `CSAT__c`. Internal notes, technician GPS, and parts costs hidden. |
| **`DF360_AgentRuntime`** | Agentforce AI System User | Read/Write access to assign technicians, update job statuses, create `SLA_Event__c`, and log `WhatsApp_Message__c`. Delete access prohibited. |

---

## 12. Non-Functional Requirements & Platform Guardrails

* **Performance**: AI dispatch assignment completed in $< 60\text{ seconds}$ for 95th percentile jobs.
* **Offline Resilience**: Mobile app operates continuously for $\ge 8\text{ hours}$ without cellular connectivity.
* **Data Retention Policy**:
  - `Service_Job__c` & `CSAT__c`: Retained for 5 years.
  - `GPS_Log__c`: Retained for 365 days; daily purge batch runs at 01:00 AM.
* **Governor Limit Protections**:
  - All SOQL queries use indexed fields (`Status__c`, `SLA_Deadline__c`, `Technician__c`).
  - Batch jobs process records in chunk sizes of 200.
  - WhatsApp and push notifications run via `@future(callout=true)` or Queueable Apex to avoid mixed DML and transaction blocking.

---

## 13. Traceability Matrix & Implementation Roadmap (Phases 0–6)

| Phase | Description | Key Deliverables | Status |
| :--- | :--- | :--- | :--- |
| **Phase 0** | **Schema & Security Foundation** | 18 Custom Objects + 3 Platform Events + 6 Permission Sets | **Available in `digiField360_Phase0_Phase1`** |
| **Phase 1** | **Core Apex Backend & Triggers** | 14 Controllers + 4 Triggers + 2 Helpers + 5 Batch Classes | **Available in `digiField360_Phase0_Phase1`** |
| **Phase 2** | **Flows & Automation Activation** | 8 Automated Record-Triggered & Scheduled Flows + 5-min SLA Batch Schedule | **Flow metadata provided; Activation Pending** |
| **Phase 3** | **Agentforce Multi-Agent Suite** | 5 Autonomous Agents (Dispatch, SLA, Parts, Analytics, Comms) | **In Roadmap (Next)** |
| **Phase 4** | **Lightning Web Components Suite** | 12 Desktop/Manager LWCs (Dashboard, GPS Map, Kanban, etc.) | **In Roadmap (Next)** |
| **Phase 5** | **Mobile Gateway & Integrations** | MCP Gateway Server expansion, WhatsApp API, Maps, Firebase | **In Roadmap (Next)** |
| **Phase 6** | **Test Suite, Seed Data & Quality Gate** | >85% Apex Test Coverage, Realistic Demo Seed Data, UAT | **In Roadmap (Next)** |

---

### **Document Approval & Governance**
* **Prepared By**: digiCloud Solutions Product & Solution Architecture Team  
* **Approved By**: Lead Architect / Engineering Lead  
* **Repository**: [`c:\digiField 360\digiFields_360`](file:///c:/digiField%20360/digiFields_360)
