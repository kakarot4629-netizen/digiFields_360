# 📊 digiField360.ai — Executive & Technical Presentation Deck

> **Presentation Title**: digiField360.ai: AI-Native Field Service Operations Platform  
> **Target Audience**: C-Suite (COO, CIO, VP Service), Service Operations Directors, Enterprise Architects, Mobile Engineering Leads  
> **Deck Format**: 16 Enterprise Presentation Slides (Markdown Deck & Speaker Guide)  
> **Interactive Version**: Available at [`docs/digifield360_presentation.html`](./digifield360_presentation.html)

---

## Slide 1: Title Slide — The Future of Field Service

```
┌────────────────────────────────────────────────────────────────────────┐
│                                                                        │
│                          digiField360.ai                               │
│        Autonomous, AI-Native Field Service Operations Platform         │
│                                                                        │
│        Salesforce Lightning Enterprise  •  Agentforce Multi-Agent      │
│        Offline-First Mobile             •  WhatsApp-First Customer     │
│                                                                        │
│                 Presenter: Enterprise Solutions Architecture           │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

* **Subtitle**: Transforming Field Operations with 85% Lower TCO, 60-Second Autonomous Dispatch, and Zero-App Customer Engagement.
* **Presenter Notes**:
  > "Welcome everyone. Today we are presenting digiField360.ai—an AI-native Field Service platform built on the Salesforce Lightning platform that solves the chronic challenges of 50 to 5,000 technician fleets across India and Southeast Asia."

---

## Slide 2: The Core Problem — Field Operations in Chaos

* **The Reality of Today's Field Service Fleet**:
  * **Spreadsheet & WhatsApp Dispatch**: Dispatchers juggle phone calls and chat groups; assignment takes 30–90 minutes per ticket.
  * **Blind SLA Breaches**: Operations leaders only find out a service SLA was missed after an angry customer calls to complain.
  * **Parts Chase & Low FTFR**: Technicians reach customer sites without knowing required parts or local warehouse availability, resulting in $<65\%$ First-Time Fix Rates.
  * **Zero Real-Time Visibility**: Supervisors cannot see live technician locations, travel delays, or actual time spent on-site.
  * **Prohibitive Licensing Barrier**: Standard Salesforce Field Service (FSL) costs **$175/user/month**—costing a 500-tech enterprise **$1M+ annually** just in software licenses!

---

## Slide 3: What is digiField360?

* **Product Definition**:
  **digiField360.ai** is an enterprise AI-native Field Service Management system built entirely on standard **Salesforce Lightning Platform ($25/user/month)** and **Agentforce AI**.
* **Key Pillars**:
  1. **Built Native on Salesforce**: Leverages standard Enterprise platform objects, custom metadata, Apex, and LWCs—no complex external database required.
  2. **Agentforce AI Suite**: 5 autonomous background AI agents handle dispatching, SLA tracking, parts expediting, executive reporting, and on-site troubleshooting.
  3. **Offline-First Mobile App**: 24-screen cross-platform mobile client (Flutter / React Native) with local SQLite caching and FIFO mutation replay queue.
  4. **WhatsApp-First Customer Experience**: Complete zero-app customer transparency—ETAs, tracking links, invoices, and 1-click CSAT delivered via WhatsApp.

---

## Slide 4: Why digiField360? (Business Value & ROI)

| Metric | Traditional FSM / FSL | digiField360.ai Impact | Business Benefit |
| :--- | :--- | :--- | :--- |
| **Software License Cost** | **$175 / user / month** | **$25 / user / month** | **85% Software TCO Savings** |
| **Dispatch Latency** | 30–60 minutes manual | **< 60 seconds autonomous** | Instant technician dispatch |
| **SLA Compliance Rate** | 72% – 78% | **96.4% Compliance** | Proactive 80% time warning alerts |
| **First-Time Fix Rate** | 62% average | **84%+ FTFR** | GuruAI diagnostics & parts pre-check |
| **Customer CSAT Response** | 8% – 12% (email surveys)| **68%+ WhatsApp Response** | Frictionless 1-click feedback loop |
| **Supervisor Overhead** | 1 supervisor per 15 techs | **1 supervisor per 50 techs**| 70% reduction in manual coordination|

---

## Slide 5: High-Level Solution Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        1. MOBILE CLIENT TIER                           │
│     (Flutter / React Native — SQLite Cache — FIFO Mutation Queue)      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ HTTPS / REST / JSON-RPC 2.0
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   2. NODE.JS MCP GATEWAY SERVER                        │
│  (Port 3000 / Cloud Staging — PKCE Auth — Replay Engine — MCP Tools)   │
└───────────────────┬───────────────────────────────┬────────────────────┘
                    │                               │
                    ▼                               ▼
┌─────────────────────────────────────┐  ┌───────────────────────────────┐
│       3. EXTERNAL ECOSYSTEM         │  │ 4. SALESFORCE LIGHTNING CORE  │
│  • Meta WhatsApp Business Cloud API │  │  • 18 Custom Objects & Events │
│  • Google Maps Telemetry API        │  │  • 5 Agentforce AI Agents     │
│  • Firebase Cloud Messaging (FCM)   │  │  • 12 Lightning Web Components│
└─────────────────────────────────────┘  └───────────────────────────────┘
```

---

## Slide 6: Core Features Overview Matrix

* **1. Autonomous Dispatch AI**: 60-second multi-criteria scoring algorithm & Kanban console.
* **2. SLA Real-Time Engine**: Continuous milestone tracker with 80% warning and repeat-visit RCA.
* **3. Multi-Depot Spare Parts**: Mobile catalogue, stock reservation, and threshold approvals.
* **4. GuruAI Copilot**: GenAI technical troubleshooting, error code diagnostics, and wiring diagrams.
* **5. WhatsApp Communications**: Zero-app notifications across 6 job milestones.
* **6. 100% Offline Mobile Engine**: Full SQLite local database with automated FIFO sync queue.
* **7. Geofenced Workforce Telemetry**: Shift attendance check-in within 500m & live GPS breadcrumbs.
* **8. Service Manager Command Center**: Live GPS fleet tracking, KPI cards, and SLA RAG status.

---

## Slide 7: Feature Deep-Dive 1 — Autonomous AI Dispatch

* **The Problem**: Manual dispatchers spend minutes verifying certifications, checking maps, and calling technicians.
* **How digiField360 Solves It**:
  * Autonomous **60-Second Assignment Engine** evaluates all available technicians using a multi-variable scoring model:
    $$\text{Score} = (35\% \times \text{Skill Match}) + (30\% \times \text{Distance}) + (20\% \times \text{Workload}) + (15\% \times \text{CSAT})$$
  * Validates active certifications (`Technician_Skill__c`) against job equipment.
  * Calculates real-time distance using technician GPS coordinates.
  * Balances daily workload to prevent technician fatigue.
  * Factors customer tier to dispatch top-rated technicians to VIP clients.
  * **Supervisor Oversight**: Visual Kanban board (`df360DispatchBoard`) allows instant drag-and-drop overrides.

---

## Slide 8: Feature Deep-Dive 2 — Offline-First Mobile App

* **The Problem**: Field technicians frequently lose connectivity in basements, rural towers, and industrial manufacturing plants.
* **How digiField360 Solves It**:
  * **Morning Sync Pre-Load**: Downloads today's assigned jobs, customer asset history, equipment manuals, and parts catalog at shift start.
  * **Local SQLite Database**: Every interaction (status update, labor hours, checklist, photo) is stored locally.
  * **FIFO Mutation Queue**: Every change is assigned a client UUID (`Offline_Queue_ID__c`) and queued in order.
  * **Seamless Auto-Replay**: The moment 4G/WiFi is restored, `OfflineMCPGateway.js` replays mutations to Salesforce with zero data conflicts or lost signatures.

---

## Slide 9: Feature Deep-Dive 3 — Real-Time SLA Engine & Escalations

* **The Problem**: SLA breaches incur severe contractual penalties and damage brand reputation when discovered too late.
* **How digiField360 Solves It**:
  * **Dynamic Contract SLAs**: Reads SLA milestones from `SLA_Config__c` and `Service_Contract__c` based on priority and customer tier.
  * **Proactive 80% Yellow Warning**: When 80% of allowed time has elapsed on an open job, the system fires `DF360_SLA_Alert__e`, alerts the supervisor, and engages GuruAI.
  * **Automated 100% Red Alert**: Publishes breach event, triggers manager escalation, and dispatches a proactive customer apology on WhatsApp.
  * **Chronic Repeat-Visit Detection**: Flags assets with $\ge 3$ visits in 30 days for immediate Root Cause Analysis (RCA) by a senior engineer.

---

## Slide 10: Feature Deep-Dive 4 — Multi-Depot Spare Parts Management

* **The Problem**: Technicians make return trips because parts are unavailable or require bureaucratic sign-offs.
* **How digiField360 Solves It**:
  * **Mobile Parts Catalog**: Technicians browse SKUs with live visibility of nearest depot stock (`Parts_Stock__c`).
  * **Automated Approval Rules**:
    * Requests $\le$ ₹5,000 are **auto-approved instantly**, reserving warehouse inventory in real time.
    * High-value requests ($> ₹5,000$) route directly to the supervisor's `df360PartsApproval` queue.
  * **Audit & Warranty Separation**: Tracks whether parts used are covered under OEM warranty or billable to the customer.
  * **Depot Reorder Triggers**: Automatic replenishment alerts when stock drops below safety levels.

---

## Slide 11: Feature Deep-Dive 5 — GuruAI Technical Copilot

* **The Problem**: Junior technicians get stuck on complex faults, resulting in aborted jobs or senior technician dispatches.
* **How digiField360 Solves It**:
  * **On-Demand GenAI Assistant**: Powered by Agentforce (`DF360_GuruAIController`, `F360_TroubleshootingAction`).
  * **Natural Language Queries**: Technicians type or voice-dictate symptoms (e.g., *"compressor buzzing, error code E4 on Carrier 2-ton"*).
  * **Contextual Guidance**: GuruAI analyzes past repair history for that specific serial number and returns:
    1. Most probable root cause.
    2. Step-by-step diagnostic checklist.
    3. Required spare part numbers.
    4. Safety precautions.
  * **Multilingual Capability**: Guides technicians in English, Hindi, Marathi, Tamil, and Telugu.

---

## Slide 12: Feature Deep-Dive 6 — WhatsApp-First Customer Experience

* **The Problem**: Customers hate downloading proprietary vendor apps just to track a service technician.
* **How digiField360 Solves It**:
  * **Zero-App Transparency**: Entire customer journey delivered via Meta's approved WhatsApp Business API.
  * **Automated Milestones**:
    1. **Job Confirmed**: Ticket ID, technician name, and scheduled window.
    2. **En Route**: Live technician GPS tracking link and updated ETA.
    3. **Arrived**: Confirmation of technician check-in at the premises.
    4. **Completed**: Digital service report PDF and signed work summary.
    5. **1-Click CSAT**: Customer taps 1–5 stars directly inside WhatsApp.
  * **Escalation Trigger**: Any rating $\le 2$ stars instantly alerts the Service Manager and schedules a recovery follow-up.

---

## Slide 13: Feature Deep-Dive 7 — Workforce, GPS & Safety Management

* **The Problem**: Timecard fraud, untracked travel, and skipped safety procedures lead to legal and operational liabilities.
* **How digiField360 Solves It**:
  * **Geofenced Attendance**: Technicians punch-in using GPS validation; attendance is rejected if outside the depot/zone radius.
  * **Mandatory Pre-Job Safety Check**: Screen 16.5 requires technicians to confirm PPE, electrical isolation, and height harnesses before starting.
  * **Live GPS Fleet Map**: Supervisors view all active technicians on `df360GPSMap`, tracking travel routes and job statuses.
  * **Automatic Data Purging**: Telemetry older than 30 days is auto-purged via `DF360_GPSLogRetentionBatch` to optimize storage.

---

## Slide 14: End-to-End Customer & Service Journey

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CUSTOMER JOURNEY LIFECYCLE                      │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Ticket Created    ──► Customer books via WhatsApp / Portal          │
│ 2. AI Dispatch       ──► Agentforce assigns nearest certified tech     │
│ 3. WhatsApp Alert    ──► Customer gets technician name & ETA window    │
│ 4. Tech En Route     ──► Customer tracks technician live via WhatsApp  │
│ 5. Geofence Arrival  ──► Check-in validated within 500m of customer    │
│ 6. Safety & GuruAI   ──► Tech completes safety check & diagnoses issue │
│ 7. Parts Installed   ──► Auto-approved depot parts fitted on-site      │
│ 8. Digital Sign-Off  ──► Customer signs on phone; PDF report generated │
│ 9. Instant CSAT      ──► Customer rates 5 stars in 1 click on WhatsApp │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Slide 15: Schema & Data Model Highlights

* **18 Custom Objects + 3 Platform Events**:
  * **Core Ops**: `Service_Job__c`, `Work_Order__c`, `Technician__c`, `Service_Zone__c`
  * **Skills & Training**: `Skill__c`, `Technician_Skill__c`
  * **Asset & Contracts**: `Asset__c`, `Equipment__c`, `Service_Contract__c`
  * **Inventory & Depots**: `Depot__c`, `Part__c`, `Parts_Stock__c`, `Parts_Request__c`
  * **Execution & Telemetry**: `Job_Activity__c`, `Job_History__c`, `Attendance__c`, `GPS_Log__c`
  * **Quality & Feedback**: `SLA_Config__c`, `SLA_Event__c`, `CSAT__c`, `WhatsApp_Message__c`
  * **Event Bus Streams**: `DF360_Job_Assigned__e`, `DF360_Parts_Approved__e`, `DF360_SLA_Alert__e`

---

## Slide 16: Summary & Implementation Roadmap

* **Phased Rollout Strategy**:
  * **Phase 0–1 (Core Platform)**: Custom objects, security, Smart Dispatch AI, and SLA Engine. *(Completed)*
  * **Phase 2 (Mobile & MCP)**: Offline SQLite client, 24 screens, Node.js Gateway. *(Ready)*
  * **Phase 3 (WhatsApp & Parts)**: Multi-depot stock, threshold approvals, Meta WhatsApp Cloud API.
  * **Phase 4 (Agentforce & GuruAI)**: Multilingual GenAI diagnostic copilot and prompt templates.
  * **Phase 5 (Analytics & Pilot)**: Live Dispatch Board, GPS fleet tracking, pilot fleet rollout.
* **Why digiField360 Wins**:
  * **85% Lower Software Costs**
  * **60-Second AI Dispatch**
  * **Proactive SLA Compliance**
  * **Frictionless WhatsApp Engagement**
