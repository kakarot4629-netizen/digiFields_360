/**
 * digiField360 Mobile Backend API & MCP Server
 * Zero-dependency Node.js HTTP Server exposing RESTful endpoints & JSON-RPC 2.0 MCP tools
 * for the digiField360 Mobile Application (React Native / iOS / Android / PWA).
 */
const http = require('http');
const url = require('url');

const PORT = process.env.PORT || 3000;
const DEFAULT_INSTANCE_URL = process.env.SF_INSTANCE_URL || 'https://orgfarm-4036b01401-dev-ed.develop.my.salesforce.com';

// ── Mock Data for Mobile Developer Sandbox / Offline Testing ────────────────
const MOCK_TECHNICIANS = [
  {
    id: 'TECH-001',
    name: 'Vikram Sharma',
    email: 'vikram.sharma@digifield360.com',
    skills: ['Generator', 'HVAC', 'Compressor', 'Electrical'],
    firstTimeFixRate: 92.5,
    isActive: true,
    preferredLanguage: 'en',
    currentLatitude: 18.52043,
    currentLongitude: 73.856743,
    jobsCompletedTotal: 148
  },
  {
    id: 'TECH-002',
    name: 'Ananya Roy',
    email: 'ananya.roy@digifield360.com',
    skills: ['HVAC', 'Solar Inverter', 'Substation', 'PLCs'],
    firstTimeFixRate: 96.0,
    isActive: true,
    preferredLanguage: 'en',
    currentLatitude: 19.07609,
    currentLongitude: 72.877426,
    jobsCompletedTotal: 210
  },
  {
    id: 'TECH-003',
    name: 'Rajesh Patel',
    email: 'rajesh.patel@digifield360.com',
    skills: ['Turbine', 'Electrical', 'Hydraulics', 'Generator'],
    firstTimeFixRate: 88.0,
    isActive: true,
    preferredLanguage: 'hi',
    currentLatitude: 12.971598,
    currentLongitude: 77.594566,
    jobsCompletedTotal: 95
  },
  {
    id: 'TECH-004',
    name: 'Sarah Jenkins',
    email: 'sarah.jenkins@digifield360.com',
    skills: ['Telematics', 'Robotics', 'HVAC', 'Compressor'],
    firstTimeFixRate: 98.2,
    isActive: true,
    preferredLanguage: 'en',
    currentLatitude: 28.613939,
    currentLongitude: 77.209021,
    jobsCompletedTotal: 312
  }
];

const MOCK_TECHNICIAN = MOCK_TECHNICIANS[0];

function resolveTechnicianProfile(inputUser, inputEmail, tokenStr) {
  let searchStr = (inputUser || inputEmail || '').trim().toLowerCase();

  if (!searchStr && tokenStr) {
    const tokenMatch = String(tokenStr).match(/mock_jwt_token_([A-Za-z0-9_\-\.]+)/i);
    if (tokenMatch && tokenMatch[1]) {
      searchStr = tokenMatch[1].toLowerCase();
    } else {
      searchStr = String(tokenStr).toLowerCase();
    }
  }

  if (searchStr) {
    const found = MOCK_TECHNICIANS.find(t =>
      t.id.toLowerCase() === searchStr ||
      t.email.toLowerCase() === searchStr ||
      t.name.toLowerCase().includes(searchStr) ||
      searchStr.includes(t.id.toLowerCase()) ||
      searchStr.includes(t.name.split(' ')[0].toLowerCase())
    );
    if (found) return found;

    // Generate dynamic profile on-the-fly for unknown email/username
    let displayName = searchStr.includes('@') ? searchStr.split('@')[0] : searchStr;
    displayName = displayName.replace(/[_\.\-]/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    const userEmail = inputEmail || (searchStr.includes('@') ? searchStr : `${searchStr.replace(/\s+/g, '.')}@digifield360.com`);
    const cleanId = 'TECH-' + (Math.abs(hashString(searchStr)) % 900 + 100);

    return {
      id: cleanId,
      name: displayName || 'Field Technician',
      email: userEmail,
      skills: ['General Field Operations', 'Diagnostics', 'Maintenance'],
      firstTimeFixRate: 95.0,
      isActive: true,
      preferredLanguage: 'en',
      currentLatitude: 18.52043,
      currentLongitude: 73.856743,
      jobsCompletedTotal: 50
    };
  }

  return MOCK_TECHNICIANS[0];
}

function hashString(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i);
    hash |= 0;
  }
  return hash;
}

const MOCK_WORK_ORDERS = [
  {
    Id: 'WO-001001',
    Name: 'WO-001001',
    Subject__c: 'Emergency Generator Overheating',
    Description__c: 'Primary backup generator overheating within 15 minutes of load test. Alarm code E-402.',
    Status__c: 'Assigned',
    Priority__c: 'Critical',
    Equipment_Type__c: 'Generator',
    Equipment_ID__c: 'EQ-GEN-9920',
    Site_Address__c: 'TechPark Sector 4, Hinjawadi Phase 2, Pune',
    Scheduled_Date__c: new Date(Date.now() + 3600000).toISOString(),
    AccountName: 'Serum BioTech Campus',
    AI_Pre_Job_Briefing__c: 'ALERT: Generator EQ-GEN-9920 overheated 3 weeks ago due to low coolant pressure. Required parts: Coolant Flush Kit, Temp Sensor TS-40. Recommended safety: High Voltage Lockout.',
    AI_Service_Report__c: null,
    Technician_Notes__c: '',
    Parts_Used__c: '',
    Time_Logged_Minutes__c: 0
  },
  {
    Id: 'WO-001002',
    Name: 'WO-001002',
    Subject__c: 'HVAC Chiller Unit Routine Servicing',
    Description__c: 'Scheduled quarterly preventive inspection, filter replacement, and refrigerant pressure test.',
    Status__c: 'In Progress',
    Priority__c: 'Medium',
    Equipment_Type__c: 'HVAC',
    Equipment_ID__c: 'EQ-HVAC-1044',
    Site_Address__c: 'DLF CyberCity Tower B, Pune',
    Scheduled_Date__c: new Date(Date.now() + 7200000).toISOString(),
    AccountName: 'DLF Commercial Properties',
    AI_Pre_Job_Briefing__c: 'Chiller operates at 85% capacity. Last service replaced air filters and lubricated blower bearings. Verify Freon R-410A pressure.',
    AI_Service_Report__c: null,
    Technician_Notes__c: 'Inspected coils and replaced pre-filters.',
    Parts_Used__c: 'Air Filter 24x24 (4x)',
    Time_Logged_Minutes__c: 45
  }
];

const MOCK_JOB_HISTORY = [
  {
    Id: 'JH-0091',
    Equipment_ID__c: 'EQ-GEN-9920',
    Equipment_Type__c: 'Generator',
    Service_Date__c: '2026-07-28',
    Technician_Name__c: 'Vikram Sharma',
    Resolution_Notes__c: 'Cleaned radiator fins, topped up coolant reservoir. Temp normalized to 82C.',
    Parts_Replaced__c: 'Coolant 5L'
  },
  {
    Id: 'JH-0082',
    Equipment_ID__c: 'EQ-HVAC-1044',
    Equipment_Type__c: 'HVAC',
    Service_Date__c: '2026-05-14',
    Technician_Name__c: 'Amit Verma',
    Resolution_Notes__c: 'Replaced condenser motor capacitor and cleaned drainage pipe.',
    Parts_Replaced__c: 'Capacitor 45MFD'
  }
];

const MOCK_KNOWLEDGE = [
  {
    Id: 'ka000000001',
    Title: 'Diesel Generator Overheating Diagnostics (E-402)',
    Summary: 'Step-by-step diagnostic guide for high temperature alarms on industrial backup generators.',
    Steps: [
      '1. Check coolant reservoir level and inspect for radiator leaks.',
      '2. Verify water pump belt tension and impeller rotation.',
      '3. Test thermostat opening temperature using infrared thermometer.',
      '4. If temperature exceeds 95C and coolant is full, check for airlock in cooling jacket.'
    ]
  },
  {
    Id: 'ka000000002',
    Title: 'HVAC Chiller Low Pressure & Refrigerant Leak Check',
    Summary: 'Troubleshooting steps for low suction pressure alarms on commercial chillers.',
    Steps: [
      '1. Measure suction and discharge pressures using digital manifold gauges.',
      '2. Inspect expansion valve thermal bulb contact and insulation.',
      '3. Perform electronic leak detector sweep across evaporator flare fittings.'
    ]
  }
];

const MOCK_ACCOUNTS = [
  { Id: '0010000001', Name: 'Serum BioTech Campus', Industry: 'Biotechnology', Type: 'Customer - Direct', BillingCity: 'Pune', Phone: '+91 20 2690 0000', AnnualRevenue: 85000000 },
  { Id: '0010000002', Name: 'DLF CyberCity Towers', Industry: 'Real Estate', Type: 'Customer - Direct', BillingCity: 'Gurugram', Phone: '+91 124 456 7890', AnnualRevenue: 120000000 },
  { Id: '0010000003', Name: 'Tata Motors Manufacturing Unit', Industry: 'Automotive', Type: 'Customer - Direct', BillingCity: 'Pune', Phone: '+91 20 6613 0000', AnnualRevenue: 450000000 },
  { Id: '0010000004', Name: 'Infosys Hinjawadi Campus', Industry: 'Technology', Type: 'Customer - Direct', BillingCity: 'Pune', Phone: '+91 20 2293 2800', AnnualRevenue: 300000000 },
  { Id: '0010000005', Name: 'Reliance Jio Data Center', Industry: 'Telecommunications', Type: 'Customer - Direct', BillingCity: 'Navi Mumbai', Phone: '+91 22 4477 0000', AnnualRevenue: 500000000 },
  { Id: '0010000006', Name: 'Apollo Hospitals Enterprise', Industry: 'Healthcare', Type: 'Customer - Direct', BillingCity: 'Chennai', Phone: '+91 44 2829 0200', AnnualRevenue: 95000000 },
  { Id: '0010000007', Name: 'Larsen & Toubro Heavy Eng', Industry: 'Engineering', Type: 'Customer - Direct', BillingCity: 'Mumbai', Phone: '+91 22 6752 5656', AnnualRevenue: 600000000 },
  { Id: '0010000008', Name: 'Bharat Petroleum Refinery', Industry: 'Energy', Type: 'Customer - Direct', BillingCity: 'Mumbai', Phone: '+91 22 2417 6000', AnnualRevenue: 750000000 },
  { Id: '0010000009', Name: 'Godrej Industries Agrovet', Industry: 'Manufacturing', Type: 'Customer - Direct', BillingCity: 'Mumbai', Phone: '+91 22 2518 8010', AnnualRevenue: 65000000 },
  { Id: '0010000010', Name: 'Wipro Sarjapur Innovation Hub', Industry: 'Technology', Type: 'Customer - Direct', BillingCity: 'Bengaluru', Phone: '+91 80 2844 0011', AnnualRevenue: 280000000 }
];

const MOCK_TECHNICIANS_SOBJECT = [
  { Id: 'TECH-001', Name: 'Vikram Sharma', Email__c: 'vikram.sharma@digifield360.com', Phone__c: '+91 98230 11223', Skills__c: 'Generator;HVAC;Compressor;Electrical', City__c: 'Pune', Status__c: 'Active', First_Time_Fix_Rate__c: 92.5 },
  { Id: 'TECH-002', Name: 'Amit Verma', Email__c: 'amit.verma@digifield360.com', Phone__c: '+91 98230 44556', Skills__c: 'HVAC;Chiller;Refrigeration', City__c: 'Mumbai', Status__c: 'Active', First_Time_Fix_Rate__c: 88.0 },
  { Id: 'TECH-003', Name: 'Pooja Patil', Email__c: 'pooja.patil@digifield360.com', Phone__c: '+91 98230 77889', Skills__c: 'Electrical;Solar;Battery Storage', City__c: 'Bengaluru', Status__c: 'Active', First_Time_Fix_Rate__c: 95.2 },
  { Id: 'TECH-004', Name: 'Rahul Deshmukh', Email__c: 'rahul.deshmukh@digifield360.com', Phone__c: '+91 98230 99001', Skills__c: 'Generator;Diesel Engine;Mechanical', City__c: 'Pune', Status__c: 'On Leave', First_Time_Fix_Rate__c: 89.4 }
];

const MOCK_MAINTENANCE_ALERTS = [
  { Id: 'ALT-001', Name: 'ALT-001', Severity__c: 'Critical', Equipment_ID__c: 'EQ-GEN-9920', Equipment_Type__c: 'Generator', AccountName: 'Serum BioTech Campus', Alert_Message__c: 'Coolant pressure dropped below 15 PSI. Thermal overload risk imminent.', Status__c: 'Open', CreatedDate: '2026-08-21T07:30:00Z' },
  { Id: 'ALT-002', Name: 'ALT-002', Severity__c: 'High', Equipment_ID__c: 'EQ-HVAC-3301', Equipment_Type__c: 'HVAC', AccountName: 'Infosys Hinjawadi Campus', Alert_Message__c: 'Chiller compressor cycle frequency exceeded threshold.', Status__c: 'Open', CreatedDate: '2026-08-21T08:15:00Z' },
  { Id: 'ALT-003', Name: 'ALT-003', Severity__c: 'Medium', Equipment_ID__c: 'EQ-BAT-1104', Equipment_Type__c: 'Battery Storage', AccountName: 'Reliance Jio Data Center', Alert_Message__c: 'Cell temperature variance exceeding 4 degrees.', Status__c: 'Investigating', CreatedDate: '2026-08-20T14:00:00Z' }
];

const MOCK_CONTACTS = [
  { Id: '0030000001', Name: 'Dr. Rajesh Mehta', Email: 'rajesh.mehta@serumbio.com', Phone: '+91 98220 12345', Title: 'Facility Director', AccountName: 'Serum BioTech Campus' },
  { Id: '0030000002', Name: 'Sunil Nair', Email: 'sunil.nair@dlfcyber.com', Phone: '+91 98110 54321', Title: 'Chief Operations Officer', AccountName: 'DLF CyberCity Towers' },
  { Id: '0030000003', Name: 'Kavita Joshi', Email: 'kavita.j@tatamotors.com', Phone: '+91 98230 67890', Title: 'Plant Maintenance Manager', AccountName: 'Tata Motors Manufacturing Unit' }
];

// ── Dynamic NL2SOQL Semantic Engine ──────────────────────────────────────────
function translateNLToSOQL(prompt, defaultLimit = 10) {
  const p = (prompt || '').toLowerCase().trim();
  
  // 1. Detect Numerical Limit
  let limit = defaultLimit;
  const limitMatch = p.match(/\b(?:top|first|limit|max)\s+(\d+)\b/) || p.match(/\b(\d+)\s+(?:accounts|jobs|work orders|techs|technicians|alerts|records|contacts)\b/);
  if (limitMatch && limitMatch[1]) {
    limit = parseInt(limitMatch[1], 10);
  }

  // 2. SObject Mapping & Schema Resolution
  let targetObject = 'Work_Order__c';
  let selectFields = ['Id', 'Name', 'Subject__c', 'Status__c', 'Priority__c', 'Equipment_Type__c', 'Equipment_ID__c', 'Site_Address__c', 'Scheduled_Date__c'];
  let whereClauses = [];
  let orderBy = 'CreatedDate DESC';

  if (/\b(account|accounts|client|clients|customer|customers|company|companies)\b/.test(p)) {
    targetObject = 'Account';
    selectFields = ['Id', 'Name', 'Type', 'Industry', 'BillingCity', 'Phone', 'AnnualRevenue'];
    orderBy = 'AnnualRevenue DESC NULLS LAST';
    
    if (p.includes('biotech')) whereClauses.push("Industry = 'Biotechnology'");
    if (p.includes('tech') && !p.includes('biotech')) whereClauses.push("Industry = 'Technology'");
    if (p.includes('real estate') || p.includes('property')) whereClauses.push("Industry = 'Real Estate'");
    if (p.includes('auto') || p.includes('automotive')) whereClauses.push("Industry = 'Automotive'");
    if (p.includes('telecom')) whereClauses.push("Industry = 'Telecommunications'");
    if (p.includes('health') || p.includes('hospital')) whereClauses.push("Industry = 'Healthcare'");
    if (p.includes('pune')) whereClauses.push("BillingCity = 'Pune'");
    if (p.includes('mumbai')) whereClauses.push("BillingCity = 'Mumbai'");
    if (p.includes('gurugram') || p.includes('gurgaon')) whereClauses.push("BillingCity = 'Gurugram'");
    if (p.includes('bengaluru') || p.includes('bangalore')) whereClauses.push("BillingCity = 'Bengaluru'");
  } 
  else if (/\b(technician|technicians|tech|techs|engineer|engineers|staff)\b/.test(p)) {
    targetObject = 'Technician__c';
    selectFields = ['Id', 'Name', 'Email__c', 'Phone__c', 'Skills__c', 'City__c', 'Status__c', 'First_Time_Fix_Rate__c'];
    orderBy = 'First_Time_Fix_Rate__c DESC NULLS LAST';

    if (p.includes('active')) whereClauses.push("Status__c = 'Active'");
    if (p.includes('generator')) whereClauses.push("Skills__c LIKE '%Generator%'");
    if (p.includes('hvac') || p.includes('chiller')) whereClauses.push("Skills__c LIKE '%HVAC%'");
    if (p.includes('electric') || p.includes('electrical')) whereClauses.push("Skills__c LIKE '%Electrical%'");
    if (p.includes('solar') || p.includes('battery')) whereClauses.push("Skills__c LIKE '%Solar%'");
    if (p.includes('pune')) whereClauses.push("City__c = 'Pune'");
    if (p.includes('mumbai')) whereClauses.push("City__c = 'Mumbai'");
  }
  else if (/\b(alert|alerts|warning|warnings|alarms|alarm|fault|faults)\b/.test(p)) {
    targetObject = 'Maintenance_Alert__c';
    selectFields = ['Id', 'Name', 'Severity__c', 'Equipment_ID__c', 'Equipment_Type__c', 'Alert_Message__c', 'Status__c', 'CreatedDate'];
    orderBy = 'CreatedDate DESC';

    if (p.includes('critical')) whereClauses.push("Severity__c = 'Critical'");
    if (p.includes('high')) whereClauses.push("Severity__c = 'High'");
    if (p.includes('open')) whereClauses.push("Status__c = 'Open'");
    if (p.includes('generator')) whereClauses.push("Equipment_Type__c = 'Generator'");
    if (p.includes('hvac')) whereClauses.push("Equipment_Type__c = 'HVAC'");
  }
  else if (/\b(history|job history|past service|log|logs)\b/.test(p)) {
    targetObject = 'Job_History__c';
    selectFields = ['Id', 'Equipment_ID__c', 'Service_Date__c', 'Technician_Name__c', 'Resolution_Notes__c', 'Parts_Replaced__c'];
    orderBy = 'Service_Date__c DESC';
  }
  else if (/\b(contact|contacts|person|people|manager|directors)\b/.test(p)) {
    targetObject = 'Contact';
    selectFields = ['Id', 'Name', 'Title', 'Email', 'Phone', 'Account.Name'];
    orderBy = 'Name ASC';
  }
  else {
    targetObject = 'Work_Order__c';
    selectFields = ['Id', 'Name', 'Subject__c', 'Status__c', 'Priority__c', 'Equipment_Type__c', 'Equipment_ID__c', 'Site_Address__c', 'Scheduled_Date__c', 'AI_Pre_Job_Briefing__c'];
    orderBy = 'Scheduled_Date__c ASC NULLS LAST';

    if (p.includes('open') || p.includes('pending') || p.includes('assigned')) whereClauses.push("Status__c IN ('Assigned', 'In Progress')");
    if (p.includes('in progress') || p.includes('ongoing')) whereClauses.push("Status__c = 'In Progress'");
    if (p.includes('completed') || p.includes('closed') || p.includes('done')) whereClauses.push("Status__c = 'Completed'");
    if (p.includes('critical')) whereClauses.push("Priority__c = 'Critical'");
    if (p.includes('high')) whereClauses.push("Priority__c = 'High'");
    if (p.includes('generator')) whereClauses.push("Equipment_Type__c = 'Generator'");
    if (p.includes('hvac') || p.includes('chiller')) whereClauses.push("Equipment_Type__c = 'HVAC'");
    if (p.includes('pune')) whereClauses.push("Site_Address__c LIKE '%Pune%'");
    if (p.includes('mumbai')) whereClauses.push("Site_Address__c LIKE '%Mumbai%'");
    if (p.includes('serum')) whereClauses.push("Account__r.Name LIKE '%Serum%'");
  }

  let whereStr = whereClauses.length > 0 ? ` WHERE ${whereClauses.join(' AND ')}` : '';
  const soql = `SELECT ${selectFields.join(', ')} FROM ${targetObject}${whereStr} ORDER BY ${orderBy} LIMIT ${limit}`;

  return {
    targetObject,
    selectFields,
    whereClauses,
    limit,
    soql
  };
}

function generateConversationalSummary(targetObject, records, prompt) {
  if (!records || records.length === 0) {
    return `No matching ${targetObject} records were found for your request: "${prompt}".`;
  }
  const count = records.length;
  if (targetObject === 'Account') {
    const topNames = records.slice(0, 3).map(r => r.Name).join(', ');
    return `Found ${count} account${count > 1 ? 's' : ''} matching your request. Top results: ${topNames}.`;
  } else if (targetObject === 'Work_Order__c') {
    const topSubjects = records.slice(0, 2).map(r => `${r.Name || r.Id} (${r.Subject__c || 'No subject'})`).join(', ');
    return `Found ${count} work order${count > 1 ? 's' : ''}. Key jobs: ${topSubjects}.`;
  } else if (targetObject === 'Technician__c') {
    const names = records.slice(0, 3).map(r => `${r.Name} (${r.Skills__c || 'General'})`).join(', ');
    return `Found ${count} technician${count > 1 ? 's' : ''}: ${names}.`;
  } else if (targetObject === 'Maintenance_Alert__c') {
    const alerts = records.slice(0, 2).map(r => `${r.Severity__c} on ${r.Equipment_ID__c || 'Equipment'}`).join('; ');
    return `Found ${count} maintenance alert${count > 1 ? 's' : ''}: ${alerts}.`;
  } else {
    return `Retrieved ${count} ${targetObject} record${count > 1 ? 's' : ''} successfully.`;
  }
}

function executeMockQuery(parsed, prompt) {
  let dataset = [];
  if (parsed.targetObject === 'Account') dataset = [...MOCK_ACCOUNTS];
  else if (parsed.targetObject === 'Technician__c') dataset = [...MOCK_TECHNICIANS_SOBJECT];
  else if (parsed.targetObject === 'Maintenance_Alert__c') dataset = [...MOCK_MAINTENANCE_ALERTS];
  else if (parsed.targetObject === 'Job_History__c') dataset = [...MOCK_JOB_HISTORY];
  else if (parsed.targetObject === 'Contact') dataset = [...MOCK_CONTACTS];
  else dataset = [...MOCK_WORK_ORDERS];

  const p = (prompt || '').toLowerCase();
  if (parsed.targetObject === 'Account') {
    if (p.includes('biotech')) dataset = dataset.filter(a => a.Industry === 'Biotechnology');
    if (p.includes('tech') && !p.includes('biotech')) dataset = dataset.filter(a => a.Industry === 'Technology');
    if (p.includes('real estate')) dataset = dataset.filter(a => a.Industry === 'Real Estate');
    if (p.includes('pune')) dataset = dataset.filter(a => a.BillingCity === 'Pune');
    dataset.sort((a, b) => (b.AnnualRevenue || 0) - (a.AnnualRevenue || 0));
  } else if (parsed.targetObject === 'Technician__c') {
    if (p.includes('generator')) dataset = dataset.filter(t => (t.Skills__c || '').includes('Generator'));
    if (p.includes('hvac')) dataset = dataset.filter(t => (t.Skills__c || '').includes('HVAC'));
    if (p.includes('pune')) dataset = dataset.filter(t => t.City__c === 'Pune');
    dataset.sort((a, b) => (b.First_Time_Fix_Rate__c || 0) - (a.First_Time_Fix_Rate__c || 0));
  } else if (parsed.targetObject === 'Maintenance_Alert__c') {
    if (p.includes('critical')) dataset = dataset.filter(a => a.Severity__c === 'Critical');
    if (p.includes('high')) dataset = dataset.filter(a => a.Severity__c === 'High' || a.Severity__c === 'Critical');
  } else if (parsed.targetObject === 'Work_Order__c') {
    if (p.includes('critical')) dataset = dataset.filter(w => w.Priority__c === 'Critical');
    if (p.includes('in progress')) dataset = dataset.filter(w => w.Status__c === 'In Progress');
    if (p.includes('assigned')) dataset = dataset.filter(w => w.Status__c === 'Assigned');
    if (p.includes('generator')) dataset = dataset.filter(w => w.Equipment_Type__c === 'Generator');
  }

  return dataset.slice(0, parsed.limit);
}

// ── MCP JSON-RPC Tools Spec ──────────────────────────────────────────────────
const MCP_TOOLS = [
  {
    name: 'sobject_query',
    description: 'Execute a SOQL query to fetch work orders, technician profiles, or job history.',
    inputSchema: {
      type: 'object',
      properties: { soql: { type: 'string', description: 'SOQL query string' } },
      required: ['soql']
    }
  },
  {
    name: 'execute_natural_language_query',
    description: 'Execute a natural language prompt to dynamically query any Salesforce object (Account, Work_Order__c, Technician__c, Maintenance_Alert__c, etc.) without hardcoding.',
    inputSchema: {
      type: 'object',
      properties: {
        prompt: { type: 'string', description: 'Natural language question (e.g., "Show top 10 accounts in Pune", "Find open work orders")' },
        maxRecords: { type: 'integer', description: 'Maximum number of records to return (default: 10)' }
      },
      required: ['prompt']
    }
  },
  {
    name: 'sobject_search',
    description: 'Execute a SOSL search or Knowledge article lookup for troubleshooting.',
    inputSchema: {
      type: 'object',
      properties: {
        searchTerm: { type: 'string', description: 'Search term or fault symptom' },
        sobjectName: { type: 'string', description: 'Optional target SObject (e.g. Knowledge__kav)' }
      },
      required: ['searchTerm']
    }
  },
  {
    name: 'sobject_update',
    description: 'Update fields on a Salesforce record (e.g. Work_Order__c status, notes).',
    inputSchema: {
      type: 'object',
      properties: {
        sobjectName: { type: 'string', description: 'SObject API Name' },
        recordId: { type: 'string', description: 'Salesforce Record ID' },
        fields: { type: 'object', description: 'Key-value map of fields to update' }
      },
      required: ['sobjectName', 'recordId', 'fields']
    }
  },
  {
    name: 'sobject_create',
    description: 'Create a record (e.g. Job_History__c, ContentVersion photo attachment).',
    inputSchema: {
      type: 'object',
      properties: {
        sobjectName: { type: 'string', description: 'SObject API Name' },
        fields: { type: 'object', description: 'Field values for the new record' }
      },
      required: ['sobjectName', 'fields']
    }
  },
  {
    name: 'sobject_describe',
    description: 'Fetch object metadata and field schema definitions for client validation.',
    inputSchema: {
      type: 'object',
      properties: { sobjectName: { type: 'string', description: 'SObject API Name' } },
      required: ['sobjectName']
    }
  },
  {
    name: 'get_account_summary',
    description: 'Fetch top customer Account records dynamically with optional limit and industry filters (e.g. top 10 accounts).',
    inputSchema: {
      type: 'object',
      properties: {
        limit: { type: 'integer', description: 'Number of accounts to return (default: 10)' },
        industry: { type: 'string', description: 'Optional industry filter (e.g. Technology, Healthcare)' }
      }
    }
  }
];

// ── HTTP Helper Functions ───────────────────────────────────────────────────
function sendJSON(res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-instance-url, x-mock-mode',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, PUT, DELETE, OPTIONS'
  });
  res.end(JSON.stringify(data, null, 2));
}

function parseRequestBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (err) {
        reject(new Error('Invalid JSON payload: ' + err.message));
      }
    });
  });
}

// ── Main Server Router ──────────────────────────────────────────────────────
const server = http.createServer(async (req, res) => {
  // CORS Pre-flight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-instance-url, x-mock-mode',
      'Access-Control-Allow-Methods': 'GET, POST, PATCH, PUT, DELETE, OPTIONS'
    });
    res.end();
    return;
  }

  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname.replace(/\/+$/, '') || '/';
  const query = parsedUrl.query;

  // Extract Auth & Headers
  const authHeader = req.headers['authorization'] || '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  const instanceUrl = req.headers['x-instance-url'] || DEFAULT_INSTANCE_URL;
  const isMockMode = req.headers['x-mock-mode'] === 'true' || query.mock === 'true' || !token;

  try {
    // ═════════════════════════════════════════════════════════════════════════
    // 1. HEALTH & ROOT ENDPOINT
    // ═════════════════════════════════════════════════════════════════════════
    if (req.method === 'GET' && (pathname === '/' || pathname === '/api' || pathname === '/health')) {
      return sendJSON(res, 200, {
        status: 'online',
        service: 'digiField360 Mobile API & MCP Server',
        version: '1.0.0',
        port: PORT,
        mode: isMockMode ? 'mock' : 'live_salesforce',
        instanceUrl: instanceUrl,
        documentation: '/docs/MOBILE_DEVELOPER_API_DOCS.md',
        endpoints: {
          auth: ['POST /api/auth/login', 'POST /api/auth/refresh', 'GET /api/technician/profile'],
          sync: ['GET /api/sync/morning-payload', 'POST /api/sync/offline-queue'],
          workOrders: ['GET /api/work-orders', 'GET /api/work-orders/:id', 'PATCH /api/work-orders/:id/status', 'POST /api/work-orders/:id/time-log', 'POST /api/work-orders/:id/complete'],
          ai: ['POST /api/ai/pre-job-briefing', 'POST /api/ai/troubleshoot', 'POST /api/ai/service-report'],
          telemetry: ['POST /api/technician/location', 'GET /api/schema/:sobject'],
          mcp: ['POST /mcp', 'GET /mcp']
        }
      });
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 2. AUTHENTICATION & PROFILE APIS
    // ═════════════════════════════════════════════════════════════════════════
    if (req.method === 'POST' && pathname === '/api/auth/login') {
      const body = await parseRequestBody(req);
      const { username, email, password, oauthCode, accessToken } = body;
      const targetUser = username || email || 'Vikram Sharma';
      const activeTech = resolveTechnicianProfile(targetUser, email, token);

      if (isMockMode) {
        return sendJSON(res, 200, {
          success: true,
          token: `mock_jwt_token_${activeTech.id.toLowerCase()}`,
          tokenType: 'Bearer',
          expiresIn: 7200,
          instanceUrl: DEFAULT_INSTANCE_URL,
          technician: activeTech
        });
      }

      // Live Salesforce OAuth / user identity verification
      try {
        let liveTechProfile = activeTech;
        if (token || accessToken) {
          const userRes = await fetch(`${instanceUrl}/services/data/v67.0/chatter/users/me`, {
            headers: { 'Authorization': `Bearer ${accessToken || token}` }
          });
          if (userRes.ok) {
            const sfUser = await userRes.json();
            liveTechProfile = {
              id: sfUser.id || activeTech.id,
              name: sfUser.displayName || sfUser.name || activeTech.name,
              email: sfUser.email || activeTech.email,
              skills: activeTech.skills,
              firstTimeFixRate: activeTech.firstTimeFixRate,
              isActive: true,
              preferredLanguage: 'en',
              currentLatitude: activeTech.currentLatitude,
              currentLongitude: activeTech.currentLongitude,
              jobsCompletedTotal: activeTech.jobsCompletedTotal
            };
          }
        }

        return sendJSON(res, 200, {
          success: true,
          token: accessToken || token || `sf_token_${activeTech.id}`,
          instanceUrl: instanceUrl,
          technician: liveTechProfile
        });
      } catch (err) {
        return sendJSON(res, 200, {
          success: true,
          token: accessToken || token || `sf_token_${activeTech.id}`,
          instanceUrl: instanceUrl,
          technician: activeTech
        });
      }
    }

    if (req.method === 'POST' && pathname === '/api/auth/refresh') {
      const body = await parseRequestBody(req);
      return sendJSON(res, 200, {
        success: true,
        accessToken: 'refreshed_mock_jwt_token_' + Date.now(),
        expiresIn: 7200,
        refreshedAt: new Date().toISOString()
      });
    }

    if (req.method === 'GET' && pathname === '/api/technician/profile') {
      const targetUser = query.username || query.email || query.technicianId;
      const activeTech = resolveTechnicianProfile(targetUser, query.email, token);

      return sendJSON(res, 200, {
        success: true,
        technician: activeTech
      });
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 3. MORNING PRE-LOAD & BATCH SYNC APIS
    // ═════════════════════════════════════════════════════════════════════════
    if (req.method === 'GET' && pathname === '/api/sync/morning-payload') {
      const technicianId = query.technicianId || query.username || token;
      const activeTech = resolveTechnicianProfile(technicianId, query.email, token);

      if (isMockMode) {
        return sendJSON(res, 200, {
          success: true,
          syncTimestamp: new Date().toISOString(),
          technician: activeTech,
          workOrders: MOCK_WORK_ORDERS,
          equipmentHistory: MOCK_JOB_HISTORY,
          knowledgeArticles: MOCK_KNOWLEDGE,
          schemas: {
            Work_Order__c: {
              statuses: ['New', 'Assigned', 'In Progress', 'Completed', 'Cancelled'],
              priorities: ['Critical', 'High', 'Medium', 'Low']
            }
          }
        });
      }

      // Live Salesforce SOQL batch queries
      try {
        const soql = `SELECT Id, Name, Subject__c, Description__c, Status__c, Priority__c, Equipment_Type__c, Equipment_ID__c, Site_Address__c, Scheduled_Date__c, AI_Pre_Job_Briefing__c FROM Work_Order__c WHERE Status__c IN ('Assigned', 'In Progress')`;
        const sfRes = await fetch(`${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(soql)}`, {
          headers: { 'Authorization': `Bearer ${token}` }
        });
        const sfData = await sfRes.json();

        return sendJSON(res, 200, {
          success: true,
          syncTimestamp: new Date().toISOString(),
          technician: activeTech,
          workOrders: sfData.records || MOCK_WORK_ORDERS,
          equipmentHistory: MOCK_JOB_HISTORY,
          knowledgeArticles: MOCK_KNOWLEDGE
        });
      } catch (err) {
        return sendJSON(res, 500, { success: false, error: err.message });
      }
    }

    // GET /api/accounts (Top Customer Accounts)
    if (req.method === 'GET' && pathname === '/api/accounts') {
      const limit = parseInt(query.limit) || 10;
      const industry = query.industry;

      if (isMockMode) {
        let results = MOCK_ACCOUNTS;
        if (industry) {
          results = results.filter(acc => acc.Industry.toLowerCase() === industry.toLowerCase());
        }
        return sendJSON(res, 200, {
          success: true,
          count: Math.min(results.length, limit),
          accounts: results.slice(0, limit)
        });
      }

      try {
        let whereClause = industry ? `WHERE Industry = '${industry}'` : '';
        const soql = `SELECT Id, Name, Type, Industry, BillingCity, Phone, AnnualRevenue FROM Account ${whereClause} ORDER BY AnnualRevenue DESC NULLS LAST LIMIT ${limit}`;
        const sfRes = await fetch(`${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(soql)}`, {
          headers: { 'Authorization': `Bearer ${token}` }
        });
        const sfData = await sfRes.json();
        return sendJSON(res, 200, {
          success: true,
          count: sfData.records?.length || 0,
          accounts: sfData.records || []
        });
      } catch (err) {
        return sendJSON(res, 500, { success: false, error: err.message });
      }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 4. WORK ORDER LIFECYCLE APIS
    // ═════════════════════════════════════════════════════════════════════════
    if (req.method === 'GET' && pathname === '/api/work-orders') {
      const statusFilter = query.status;
      let results = MOCK_WORK_ORDERS;
      if (statusFilter) {
        results = results.filter(wo => wo.Status__c.toLowerCase() === statusFilter.toLowerCase());
      }
      return sendJSON(res, 200, {
        success: true,
        count: results.length,
        workOrders: results
      });
    }

    // GET /api/work-orders/:id
    if (req.method === 'GET' && pathname.startsWith('/api/work-orders/')) {
      const woId = pathname.replace('/api/work-orders/', '');
      const found = MOCK_WORK_ORDERS.find(wo => wo.Id === woId || wo.Name === woId) || MOCK_WORK_ORDERS[0];
      return sendJSON(res, 200, {
        success: true,
        workOrder: {
          ...found,
          recentHistory: MOCK_JOB_HISTORY.filter(jh => jh.Equipment_ID__c === found.Equipment_ID__c)
        }
      });
    }

    // PATCH /api/work-orders/:id/status
    if (req.method === 'PATCH' && pathname.includes('/api/work-orders/') && pathname.endsWith('/status')) {
      const woId = pathname.replace('/api/work-orders/', '').replace('/status', '');
      const body = await parseRequestBody(req);
      const { status } = body;

      if (!status) {
        return sendJSON(res, 400, { success: false, error: 'Missing status in request body' });
      }

      return sendJSON(res, 200, {
        success: true,
        workOrderId: woId,
        newStatus: status,
        updatedAt: new Date().toISOString(),
        message: `Work Order ${woId} status updated to '${status}'.`
      });
    }

    // POST /api/work-orders/:id/time-log
    if (req.method === 'POST' && pathname.includes('/api/work-orders/') && pathname.endsWith('/time-log')) {
      const woId = pathname.replace('/api/work-orders/', '').replace('/time-log', '');
      const body = await parseRequestBody(req);
      const { hoursWorked, minutesWorked, notes } = body;
      const totalMinutes = minutesWorked || Math.round((hoursWorked || 1) * 60);

      return sendJSON(res, 200, {
        success: true,
        workOrderId: woId,
        timeLoggedMinutes: totalMinutes,
        notes: notes || 'Field labor logged',
        loggedAt: new Date().toISOString()
      });
    }

    // POST /api/work-orders/:id/complete
    if (req.method === 'POST' && pathname.includes('/api/work-orders/') && pathname.endsWith('/complete')) {
      const woId = pathname.replace('/api/work-orders/', '').replace('/complete', '');
      const body = await parseRequestBody(req);
      const { technicianNotes, partsUsed, timeLoggedMinutes, photosBase64, sendToCustomer } = body;

      const generatedReport = `========================================
FIELD360 SERVICE COMPLETION REPORT
========================================
Work Order: ${woId}
Equipment: Generator EQ-GEN-9920
Technician: ${MOCK_TECHNICIAN.name} (${MOCK_TECHNICIAN.id})
Date Completed: ${new Date().toLocaleDateString('en-IN')}

WORK PERFORMED:
${technicianNotes || 'Replaced thermal sensor and completed full load testing. Voltage and temperature within standard tolerances.'}

PARTS REPLACED:
${partsUsed || 'Thermal Sensor TS-40 (1x), Coolant 5L'}

TIME LOGGED: ${timeLoggedMinutes || 90} minutes
PHOTOS ATTACHED: ${photosBase64?.length || 0} image(s)
STATUS: Verified Operable. Passed Quality Checks.
========================================`;

      return sendJSON(res, 200, {
        success: true,
        workOrderId: woId,
        status: 'Completed',
        completedAt: new Date().toISOString(),
        serviceReport: generatedReport,
        photosUploadedCount: photosBase64?.length || 0,
        contentVersionCreated: true,
        jobHistoryCreated: true,
        sentToCustomer: !!sendToCustomer
      });
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 5. AI MOBILE SERVICES APIS
    // ═════════════════════════════════════════════════════════════════════════
    // POST /api/ai/query (Dynamic Natural Language to Salesforce Query / NL2SOQL)
    if (req.method === 'POST' && pathname === '/api/ai/query') {
      const body = await parseRequestBody(req);
      const { prompt, maxRecords } = body;

      if (!prompt) {
        return sendJSON(res, 400, { success: false, error: 'prompt is required (e.g. "Show me top 10 accounts in Pune", "Find open work orders")' });
      }

      const parsed = translateNLToSOQL(prompt, maxRecords || 10);

      if (isMockMode) {
        const records = executeMockQuery(parsed, prompt);
        const aiSummary = generateConversationalSummary(parsed.targetObject, records, prompt);
        return sendJSON(res, 200, {
          success: true,
          prompt: prompt,
          targetObject: parsed.targetObject,
          soqlGenerated: parsed.soql,
          count: records.length,
          records: records,
          aiSummary: aiSummary
        });
      }

      // Live Salesforce SOQL execution
      try {
        const sfRes = await fetch(`${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(parsed.soql)}`, {
          headers: { 'Authorization': `Bearer ${token}` }
        });
        const sfData = await sfRes.json();
        const records = sfData.records || [];
        const aiSummary = generateConversationalSummary(parsed.targetObject, records, prompt);
        return sendJSON(res, 200, {
          success: true,
          prompt: prompt,
          targetObject: parsed.targetObject,
          soqlGenerated: parsed.soql,
          count: records.length,
          records: records,
          aiSummary: aiSummary
        });
      } catch (err) {
        return sendJSON(res, 500, { success: false, error: err.message, soqlGenerated: parsed.soql });
      }
    }

    // POST /api/query/soql (Direct Dynamic SOQL Query Execution)
    if (req.method === 'POST' && pathname === '/api/query/soql') {
      const body = await parseRequestBody(req);
      const { soql } = body;

      if (!soql) {
        return sendJSON(res, 400, { success: false, error: 'soql string is required' });
      }

      if (isMockMode) {
        const matchObj = soql.match(/FROM\s+([a-zA-Z0-9_]+)/i);
        const targetObj = matchObj ? matchObj[1] : 'Work_Order__c';
        const parsed = { targetObject: targetObj, limit: 10 };
        const records = executeMockQuery(parsed, soql);
        return sendJSON(res, 200, {
          success: true,
          totalSize: records.length,
          done: true,
          records: records
        });
      }

      try {
        const sfRes = await fetch(`${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(soql)}`, {
          headers: { 'Authorization': `Bearer ${token}` }
        });
        const sfData = await sfRes.json();
        return sendJSON(res, 200, {
          success: true,
          totalSize: sfData.totalSize || (sfData.records ? sfData.records.length : 0),
          done: true,
          records: sfData.records || []
        });
      } catch (err) {
        return sendJSON(res, 500, { success: false, error: err.message });
      }
    }

    // POST /api/ai/pre-job-briefing
    if (req.method === 'POST' && pathname === '/api/ai/pre-job-briefing') {
      const body = await parseRequestBody(req);
      const { workOrderId, languageCode } = body;

      return sendJSON(res, 200, {
        success: true,
        workOrderId: workOrderId || 'WO-001001',
        language: languageCode || 'en',
        briefing: 'EQUIPMENT BRIEFING (AI Generated): Equipment EQ-GEN-9920 has an overheating history. Previous technician noted low coolant flow. Bring Coolant Flush Kit and multimeter. Follow high-pressure coolant safety protocols.'
      });
    }

    // POST /api/ai/troubleshoot
    if (req.method === 'POST' && pathname === '/api/ai/troubleshoot') {
      const body = await parseRequestBody(req);
      const { problemDescription, equipmentType, languageCode } = body;

      if (!problemDescription) {
        return sendJSON(res, 400, { success: false, error: 'problemDescription is required' });
      }

      const isSeniorNeeded = /smoke|fire|burst|crack|high\s*voltage|explosion|dangerous/i.test(problemDescription);

      return sendJSON(res, 200, {
        success: true,
        query: problemDescription,
        equipmentType: equipmentType || 'General',
        language: languageCode || 'en',
        escalateToSenior: isSeniorNeeded,
        escalationReason: isSeniorNeeded ? 'Safety hazard / critical component failure detected.' : null,
        diagnosisSteps: [
          'Step 1: Perform visual inspection of primary drive belt and radiator fin clearance.',
          'Step 2: Measure thermal sensor resistance using multimeter.',
          'Step 3: Inspect coolant fluid level and check for airlocks in water pump inlet.'
        ],
        knowledgeArticles: MOCK_KNOWLEDGE
      });
    }

    // POST /api/ai/service-report
    if (req.method === 'POST' && pathname === '/api/ai/service-report') {
      const body = await parseRequestBody(req);
      const { workOrderId, technicianNotes, partsUsed } = body;

      return sendJSON(res, 200, {
        success: true,
        workOrderId: workOrderId || 'WO-001001',
        generatedAt: new Date().toISOString(),
        serviceReport: `AI Generated Service Report for ${workOrderId || 'WO-001001'}:\n\nTechnician Notes: ${technicianNotes || 'Inspected and repaired'}\nParts: ${partsUsed || 'None'}\n\nEquipment operational and returned to service.`
      });
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 6. OFFLINE QUEUE REPLAY & TELEMETRY APIS
    // ═════════════════════════════════════════════════════════════════════════
    // POST /api/sync/offline-queue (Batch Replay)
    if (req.method === 'POST' && pathname === '/api/sync/offline-queue') {
      const body = await parseRequestBody(req);
      const { technicianId, mutations } = body;

      if (!Array.isArray(mutations)) {
        return sendJSON(res, 400, { success: false, error: 'mutations array is required' });
      }

      const results = mutations.map((mutation, idx) => ({
        queueId: mutation.queueId || `UUID-${idx + 1}`,
        action: mutation.action || 'update',
        sobjectName: mutation.sobjectName || 'Work_Order__c',
        recordId: mutation.recordId,
        status: 'synced',
        syncedAt: new Date().toISOString(),
        error: null
      }));

      return sendJSON(res, 200, {
        success: true,
        technicianId: technicianId || 'TECH-001',
        totalProcessed: mutations.length,
        syncedCount: mutations.length,
        failedCount: 0,
        results: results
      });
    }

    // POST /api/technician/location (GPS Telemetry)
    if (req.method === 'POST' && pathname === '/api/technician/location') {
      const body = await parseRequestBody(req);
      const { latitude, longitude, technicianId, speed, timestamp } = body;

      if (latitude === undefined || longitude === undefined) {
        return sendJSON(res, 400, { success: false, error: 'latitude and longitude are required' });
      }

      return sendJSON(res, 200, {
        success: true,
        technicianId: technicianId || 'TECH-001',
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        updatedAt: timestamp || new Date().toISOString(),
        message: 'GPS coordinates recorded.'
      });
    }

    // GET /api/schema/:sobject
    if (req.method === 'GET' && pathname.startsWith('/api/schema/')) {
      const sobjectName = pathname.replace('/api/schema/', '');
      return sendJSON(res, 200, {
        success: true,
        sobjectName: sobjectName,
        label: sobjectName.replace(/__c$/, '').replace(/_/g, ' '),
        fieldsCount: 18,
        keyFields: ['Id', 'Name', 'Status__c', 'Priority__c', 'Subject__c', 'Equipment_ID__c']
      });
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 7. MODEL CONTEXT PROTOCOL (MCP) JSON-RPC 2.0 ENDPOINT
    // ═════════════════════════════════════════════════════════════════════════
    if (pathname === '/mcp' || pathname === '/services/mcp/v1' || pathname === '/services/mcp/platform/sobject-reads') {
      if (req.method === 'GET') {
        return sendJSON(res, 200, {
          status: 'Salesforce digiField360 MCP Server Running',
          endpoint: `http://localhost:${PORT}/mcp`,
          toolsCount: MCP_TOOLS.length
        });
      }

      if (req.method === 'POST') {
        const payload = await parseRequestBody(req);
        const { jsonrpc, id, method, params } = payload;

        if (jsonrpc !== '2.0') {
          return sendJSON(res, 400, { jsonrpc: '2.0', id, error: { code: -32600, message: 'Invalid Request: Must be JSON-RPC 2.0' } });
        }

        // tools/list
        if (method === 'tools/list') {
          return sendJSON(res, 200, {
            jsonrpc: '2.0',
            id,
            result: { tools: MCP_TOOLS }
          });
        }

        // tools/call
        if (method === 'tools/call') {
          const toolName = params?.name;
          const args = params?.arguments || {};
          let toolOutput = '';

          if (toolName === 'sobject_query') {
            toolOutput = JSON.stringify({
              totalSize: MOCK_WORK_ORDERS.length,
              done: true,
              records: MOCK_WORK_ORDERS
            }, null, 2);
          } else if (toolName === 'sobject_search') {
            toolOutput = JSON.stringify({ searchRecords: MOCK_KNOWLEDGE }, null, 2);
          } else if (toolName === 'sobject_update') {
            toolOutput = JSON.stringify({ success: true, id: args.recordId, updatedFields: Object.keys(args.fields || {}) }, null, 2);
          } else if (toolName === 'sobject_create') {
            toolOutput = JSON.stringify({ success: true, id: 'a01000000MockCreatedId', errors: [] }, null, 2);
          } else if (toolName === 'sobject_describe') {
            toolOutput = JSON.stringify({
              name: args.sobjectName,
              label: args.sobjectName.replace(/__c$/, '').replace(/_/g, ' '),
              fieldsCount: 15
            }, null, 2);
          } else if (toolName === 'get_account_summary') {
            const limit = args.limit || 10;
            let results = MOCK_ACCOUNTS;
            if (args.industry) {
              results = results.filter(acc => acc.Industry.toLowerCase() === args.industry.toLowerCase());
            }
            toolOutput = JSON.stringify(results.slice(0, limit), null, 2);
          } else if (toolName === 'execute_natural_language_query') {
            const prompt = args.prompt || '';
            const maxRecords = args.maxRecords || 10;
            const parsed = translateNLToSOQL(prompt, maxRecords);
            const records = executeMockQuery(parsed, prompt);
            const aiSummary = generateConversationalSummary(parsed.targetObject, records, prompt);
            toolOutput = JSON.stringify({
              prompt: prompt,
              targetObject: parsed.targetObject,
              soqlGenerated: parsed.soql,
              count: records.length,
              records: records,
              aiSummary: aiSummary
            }, null, 2);
          } else {
            return sendJSON(res, 404, { jsonrpc: '2.0', id, error: { code: -32601, message: `Tool not found: ${toolName}` } });
          }

          return sendJSON(res, 200, {
            jsonrpc: '2.0',
            id,
            result: {
              content: [{ type: 'text', text: toolOutput }]
            }
          });
        }

        return sendJSON(res, 200, {
          jsonrpc: '2.0',
          id,
          result: { message: `Method ${method} processed.` }
        });
      }
    }

    // 404 Handler
    return sendJSON(res, 404, {
      success: false,
      error: `Endpoint '${req.method} ${pathname}' not found. Visit GET /health for documentation.`
    });

  } catch (error) {
    return sendJSON(res, 500, {
      success: false,
      error: error.message
    });
  }
});

server.listen(PORT, () => {
  console.log(`🚀 digiField360 Mobile API & MCP Server running on port ${PORT}`);
  console.log(`📡 Health & API Discovery: http://localhost:${PORT}/health`);
  console.log(`🤖 MCP JSON-RPC Endpoint:  http://localhost:${PORT}/mcp`);
});
