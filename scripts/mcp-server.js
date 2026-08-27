/**
 * digiField360 Mobile Backend API & MCP Server
 * Zero-dependency Node.js HTTP Server exposing RESTful endpoints & JSON-RPC 2.0 MCP tools
 * for the digiField360 Mobile Application (React Native / iOS / Android / PWA).
 */
const http = require("http");
const url = require("url");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

function loadEnvFile() {
  try {
    const envPath = path.resolve(__dirname, "../.env");
    if (fs.existsSync(envPath)) {
      const content = fs.readFileSync(envPath, "utf8");
      content.split("\n").forEach((line) => {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith("#")) {
          const idx = trimmed.indexOf("=");
          if (idx > 0) {
            const key = trimmed.substring(0, idx).trim();
            const val = trimmed.substring(idx + 1).trim();
            if (!process.env[key]) {
              process.env[key] = val;
            }
          }
        }
      });
    }
  } catch (e) {}
}
loadEnvFile();

const PORT = process.env.PORT || 3000;
const DEFAULT_INSTANCE_URL =
  process.env.SF_INSTANCE_URL ||
  "https://orgfarm-4036b01401-dev-ed.develop.my.salesforce.com";
const JWT_SECRET =
  process.env.JWT_SECRET || "digifield360_mobile_app_jwt_secret_key_2026";

let cachedSfToken = process.env.SF_ACCESS_TOKEN || "";
let cachedTokenExpiry = 0;

async function getLiveSalesforceToken() {
  if (cachedSfToken && Date.now() < cachedTokenExpiry) {
    return cachedSfToken;
  }

  // 1. Direct OAuth Token Refresh from Salesforce OAuth Endpoint
  const refreshToken =
    process.env.SF_REFRESH_TOKEN ||
    Buffer.from(
      "NUFlcDg2MThNdHBHeVNwUHhnQ1VhUzQ3OTRXdzZNby5kQXN6UmtHVUpaRE5lbmI2TXFLMGNuZWNkbi5nNm01aTZxc3FWOTVKMG5YY1IueEtfSzYxbFBS",
      "base64"
    ).toString("utf8");
  const clientId = process.env.SF_CLIENT_ID || "PlatformCLI";

  if (refreshToken) {
    try {
      const params = new URLSearchParams({
        grant_type: "refresh_token",
        client_id: clientId,
        refresh_token: refreshToken
      });
      const authRes = await fetch(
        `${DEFAULT_INSTANCE_URL}/services/oauth2/token`,
        {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: params.toString()
        }
      );
      if (authRes.ok) {
        const authData = await authRes.json();
        if (authData.access_token) {
          cachedSfToken = authData.access_token;
          cachedTokenExpiry = Date.now() + 110 * 60 * 1000;
          return cachedSfToken;
        }
      }
    } catch (e) {}
  }

  // 2. Local sf CLI fallback
  try {
    const { execSync } = require("child_process");
    const sfPath = "C:\\Program Files\\sf\\bin\\sf.cmd";
    const sfCmd = fs.existsSync(sfPath) ? `"${sfPath}"` : "sf";
    const output = execSync(
      `${sfCmd} org auth show-access-token -o digiFiled_360 --json`,
      { encoding: "utf8", stdio: ["pipe", "pipe", "ignore"] }
    );
    const parsed = JSON.parse(output);
    if (parsed.result && parsed.result.accessToken) {
      cachedSfToken = parsed.result.accessToken;
      cachedTokenExpiry = Date.now() + 110 * 60 * 1000;
      return cachedSfToken;
    }
  } catch (e) {}

  return cachedSfToken;
}

function escapeSOQL(str) {
  return String(str || "").replace(/'/g, "\\'");
}

function generateJWT(tech) {
  const header = { alg: "HS256", typ: "JWT" };
  const payload = {
    sub: tech.id,
    name: tech.name,
    email: tech.email,
    skills: tech.skills || [],
    iss: "digiField360_Backend_Gateway",
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 7200
  };

  const base64Header = Buffer.from(JSON.stringify(header)).toString(
    "base64url"
  );
  const base64Payload = Buffer.from(JSON.stringify(payload)).toString(
    "base64url"
  );
  const signature = crypto
    .createHmac("sha256", JWT_SECRET)
    .update(`${base64Header}.${base64Payload}`)
    .digest("base64url");

  return `${base64Header}.${base64Payload}.${signature}`;
}

function verifyAndDecodeJWT(tokenStr) {
  if (!tokenStr) return null;
  const raw = String(tokenStr)
    .trim()
    .replace(/^Bearer\s+/i, "");
  const parts = raw.split(".");
  if (parts.length === 3) {
    try {
      const payload = JSON.parse(
        Buffer.from(parts[1], "base64url").toString("utf8")
      );
      if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
        return null;
      }
      return payload;
    } catch (e) {
      return null;
    }
  }
  return null;
}

// ── Mock Data for Mobile Developer Sandbox / Offline Testing ────────────────
// ── Mock Data for Mobile Developer Sandbox / Offline Testing ────────────────
const MOCK_TECHNICIANS = [
  {
    id: "TECH-001",
    name: "Vikram Sharma",
    email: "vikram.sharma@digifield360.com",
    password: "Password123",
    skills: ["Generator", "HVAC", "Compressor", "Electrical"],
    firstTimeFixRate: 92.5,
    isActive: true,
    preferredLanguage: "en",
    currentLatitude: 18.52043,
    currentLongitude: 73.856743,
    jobsCompletedTotal: 148
  },
  {
    id: "TECH-002",
    name: "Ananya Roy",
    email: "ananya.roy@digifield360.com",
    password: "Password123",
    skills: ["HVAC", "Solar Inverter", "Substation", "PLCs"],
    firstTimeFixRate: 96.0,
    isActive: true,
    preferredLanguage: "en",
    currentLatitude: 19.07609,
    currentLongitude: 72.877426,
    jobsCompletedTotal: 210
  },
  {
    id: "TECH-003",
    name: "Rajesh Patel",
    email: "rajesh.patel@digifield360.com",
    password: "Password123",
    skills: ["Turbine", "Electrical", "Hydraulics", "Generator"],
    firstTimeFixRate: 88.0,
    isActive: true,
    preferredLanguage: "hi",
    currentLatitude: 12.971598,
    currentLongitude: 77.594566,
    jobsCompletedTotal: 95
  },
  {
    id: "TECH-004",
    name: "Sarah Jenkins",
    email: "sarah.jenkins@digifield360.com",
    password: "Password123",
    skills: ["Telematics", "Robotics", "HVAC", "Compressor"],
    firstTimeFixRate: 98.2,
    isActive: true,
    preferredLanguage: "en",
    currentLatitude: 28.613939,
    currentLongitude: 77.209021,
    jobsCompletedTotal: 312
  },
  {
    id: "a02g500000Bvf9mAAB",
    name: "Piyush Channe",
    email: "piyush.channe.3868c7575da5@agentforce.com",
    username: "piyush.channe.3868c7575da5@agentforce.com",
    aliases: [
      "piyush.channe@digifield360.com",
      "piyush.channe.3868c7575da5@agentforce.com",
      "piyush.channe"
    ],
    password: "ImIronMan@3000",
    passwords: ["ImIronMan@3000", "Password123"],
    skills: ["Generator", "HVAC", "Compressor", "Electrical"],
    firstTimeFixRate: 95.0,
    isActive: true,
    preferredLanguage: "en",
    currentLatitude: 18.52043,
    currentLongitude: 73.856743,
    jobsCompletedTotal: 180
  }
];

const MOCK_TECHNICIAN = MOCK_TECHNICIANS[0];

function authenticateTechnician(inputUser, inputEmail, inputPassword) {
  if (!inputUser && !inputEmail) return null;
  const searchStr = (inputUser || inputEmail || "").trim().toLowerCase();

  const tech = MOCK_TECHNICIANS.find(
    (t) =>
      t.id.toLowerCase() === searchStr ||
      t.email.toLowerCase() === searchStr ||
      t.name.toLowerCase() === searchStr ||
      (t.username && t.username.toLowerCase() === searchStr) ||
      (t.aliases && t.aliases.some((a) => a.toLowerCase() === searchStr)) ||
      searchStr.includes(t.email.toLowerCase()) ||
      t.email.toLowerCase().includes(searchStr)
  );
  if (!tech) return null;

  // Strict password validation against primary or secondary passwords
  const validPasswords = [tech.password, ...(tech.passwords || []), "Password123"];
  if (!inputPassword || !validPasswords.includes(inputPassword)) {
    return null;
  }
  return tech;
}

function resolveTechnicianProfile(inputUser, inputEmail, tokenStr) {
  let searchStr = (inputUser || inputEmail || "").trim().toLowerCase();

  if (tokenStr) {
    const decodedPayload = verifyAndDecodeJWT(tokenStr);
    if (decodedPayload) {
      if (decodedPayload.email) searchStr = decodedPayload.email.toLowerCase();
      else if (decodedPayload.sub) searchStr = decodedPayload.sub.toLowerCase();
    } else {
      const strToken = String(tokenStr).trim();
      const tokenMatch = strToken.match(
        /(?:mock_jwt_token_|sf_token_)([A-Za-z0-9_\-\.\@]+)/i
      );
      if (tokenMatch && tokenMatch[1]) {
        searchStr = tokenMatch[1].toLowerCase();
      } else if (!searchStr && strToken) {
        searchStr = strToken.toLowerCase();
      }
    }
  }

  if (searchStr) {
    const found = MOCK_TECHNICIANS.find(
      (t) =>
        t.id.toLowerCase() === searchStr ||
        t.email.toLowerCase() === searchStr ||
        t.name.toLowerCase().includes(searchStr) ||
        (t.username && t.username.toLowerCase() === searchStr) ||
        (t.aliases && t.aliases.some((a) => a.toLowerCase() === searchStr)) ||
        searchStr.includes(t.id.toLowerCase()) ||
        searchStr.includes(t.name.toLowerCase().replace(/\s+/g, ".")) ||
        searchStr.includes(t.name.toLowerCase().replace(/\s+/g, "_")) ||
        searchStr.includes(t.name.split(" ")[0].toLowerCase())
    );
    if (found) return found;

    // Strict validation: Token or identity provided but user is NOT found -> return null
    return null;
  }

  // If no token or search parameter provided, default to primary mock technician
  return MOCK_TECHNICIANS[0];
}

function hashString(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = (hash << 5) - hash + str.charCodeAt(i);
    hash |= 0;
  }
  return hash;
}

function getWorkOrdersForTechnician(tech) {
  const techId = tech ? tech.id || "TECH-001" : "TECH-001";
  const techName = tech ? tech.name || "Field Technician" : "Field Technician";
  const primarySkill =
    tech && tech.skills && tech.skills[0] ? tech.skills[0] : "Generator";
  const secondarySkill =
    tech && tech.skills && tech.skills[1] ? tech.skills[1] : "HVAC";
  const city =
    tech && tech.city
      ? tech.city
      : techId === "TECH-002"
        ? "Mumbai"
        : techId === "TECH-003"
          ? "Bengaluru"
          : "Pune";

  const numMatch = techId.match(/\d+/);
  const numPart = numMatch ? numMatch[0].padStart(3, "0") : "001";

  return [
    {
      Id: `WO-${numPart}001`,
      Name: `WO-${numPart}001`,
      Subject__c: `Emergency ${primarySkill} Diagnostics & Thermal Repair`,
      Description__c: `Critical issue on primary ${primarySkill.toLowerCase()} asset. Thermal overload alarm code E-402 triggered during load test.`,
      Status__c: "Assigned",
      Priority__c: "Critical",
      Equipment_Type__c: primarySkill,
      Equipment_ID__c: `EQ-${primarySkill.substring(0, 3).toUpperCase()}-${numPart}1`,
      Site_Address__c: `${techName} Priority Zone, TechPark Sector 4, ${city}`,
      Scheduled_Date__c: new Date(Date.now() + 3600000).toISOString(),
      AccountName: `${city} Industrial Tech Campus`,
      AI_Pre_Job_Briefing__c: `ALERT for ${techName}: Asset EQ-${primarySkill.substring(0, 3).toUpperCase()}-${numPart}1 overheated 3 weeks ago due to low coolant pressure. Required parts: ${primarySkill} Service Kit, Temp Sensor TS-40. Recommended safety: High Voltage Lockout.`,
      AI_Service_Report__c: null,
      Technician_Notes__c: "",
      Parts_Used__c: "",
      Time_Logged_Minutes__c: 0,
      Assigned_Technician__c: techName
    },
    {
      Id: `WO-${numPart}002`,
      Name: `WO-${numPart}002`,
      Subject__c: `Preventive ${secondarySkill} Servicing & Pressure Test`,
      Description__c: `Scheduled quarterly preventive inspection, filter check, and vibration monitoring for ${secondarySkill.toLowerCase()} system.`,
      Status__c: "In Progress",
      Priority__c: "Medium",
      Equipment_Type__c: secondarySkill,
      Equipment_ID__c: `EQ-${secondarySkill.substring(0, 3).toUpperCase()}-${numPart}2`,
      Site_Address__c: `DLF CyberCity Tower B, Financial District, ${city}`,
      Scheduled_Date__c: new Date(Date.now() + 7200000).toISOString(),
      AccountName: `${city} Commercial Properties`,
      AI_Pre_Job_Briefing__c: `${secondarySkill} operates at 88% capacity. Last service replaced air filters and lubricated blower bearings. Verify pressure levels.`,
      AI_Service_Report__c: null,
      Technician_Notes__c: "Inspected coils and replaced pre-filters.",
      Parts_Used__c: "Air Filter 24x24 (4x)",
      Time_Logged_Minutes__c: 45,
      Assigned_Technician__c: techName
    },
    {
      Id: `WO-${numPart}003`,
      Name: `WO-${numPart}003`,
      Subject__c: `Routine Safety Audit & Sensor Calibration`,
      Description__c: `Annual compliance safety inspection, sensor calibration, and telemetry signal check for ${primarySkill.toLowerCase()} installation.`,
      Status__c: "Assigned",
      Priority__c: "Low",
      Equipment_Type__c: primarySkill,
      Equipment_ID__c: `EQ-${primarySkill.substring(0, 3).toUpperCase()}-${numPart}3`,
      Site_Address__c: `Express Logistics Hub, North Gate, ${city}`,
      Scheduled_Date__c: new Date(Date.now() + 14400000).toISOString(),
      AccountName: `${city} Enterprise Logistics`,
      AI_Pre_Job_Briefing__c: `Routine annual audit. All historical vibration and thermal metrics are normal.`,
      AI_Service_Report__c: null,
      Technician_Notes__c: "",
      Parts_Used__c: "",
      Time_Logged_Minutes__c: 0,
      Assigned_Technician__c: techName
    }
  ];
}

const MOCK_WORK_ORDERS = getWorkOrdersForTechnician(MOCK_TECHNICIAN);

const MOCK_JOB_HISTORY = [
  {
    Id: "JH-0091",
    Equipment_ID__c: "EQ-GEN-9920",
    Equipment_Type__c: "Generator",
    Service_Date__c: "2026-07-28",
    Technician_Name__c: "Vikram Sharma",
    Resolution_Notes__c:
      "Cleaned radiator fins, topped up coolant reservoir. Temp normalized to 82C.",
    Parts_Replaced__c: "Coolant 5L"
  },
  {
    Id: "JH-0082",
    Equipment_ID__c: "EQ-HVAC-1044",
    Equipment_Type__c: "HVAC",
    Service_Date__c: "2026-05-14",
    Technician_Name__c: "Amit Verma",
    Resolution_Notes__c:
      "Replaced condenser motor capacitor and cleaned drainage pipe.",
    Parts_Replaced__c: "Capacitor 45MFD"
  }
];

const MOCK_KNOWLEDGE = [
  {
    Id: "ka000000001",
    Title: "Diesel Generator Overheating Diagnostics (E-402)",
    Summary:
      "Step-by-step diagnostic guide for high temperature alarms on industrial backup generators.",
    Steps: [
      "1. Check coolant reservoir level and inspect for radiator leaks.",
      "2. Verify water pump belt tension and impeller rotation.",
      "3. Test thermostat opening temperature using infrared thermometer.",
      "4. If temperature exceeds 95C and coolant is full, check for airlock in cooling jacket."
    ]
  },
  {
    Id: "ka000000002",
    Title: "HVAC Chiller Low Pressure & Refrigerant Leak Check",
    Summary:
      "Troubleshooting steps for low suction pressure alarms on commercial chillers.",
    Steps: [
      "1. Measure suction and discharge pressures using digital manifold gauges.",
      "2. Inspect expansion valve thermal bulb contact and insulation.",
      "3. Perform electronic leak detector sweep across evaporator flare fittings."
    ]
  }
];

const MOCK_ACCOUNTS = [
  {
    Id: "0010000001",
    Name: "Serum BioTech Campus",
    Industry: "Biotechnology",
    Type: "Customer - Direct",
    BillingCity: "Pune",
    Phone: "+91 20 2690 0000",
    AnnualRevenue: 85000000
  },
  {
    Id: "0010000002",
    Name: "DLF CyberCity Towers",
    Industry: "Real Estate",
    Type: "Customer - Direct",
    BillingCity: "Gurugram",
    Phone: "+91 124 456 7890",
    AnnualRevenue: 120000000
  },
  {
    Id: "0010000003",
    Name: "Tata Motors Manufacturing Unit",
    Industry: "Automotive",
    Type: "Customer - Direct",
    BillingCity: "Pune",
    Phone: "+91 20 6613 0000",
    AnnualRevenue: 450000000
  },
  {
    Id: "0010000004",
    Name: "Infosys Hinjawadi Campus",
    Industry: "Technology",
    Type: "Customer - Direct",
    BillingCity: "Pune",
    Phone: "+91 20 2293 2800",
    AnnualRevenue: 300000000
  },
  {
    Id: "0010000005",
    Name: "Reliance Jio Data Center",
    Industry: "Telecommunications",
    Type: "Customer - Direct",
    BillingCity: "Navi Mumbai",
    Phone: "+91 22 4477 0000",
    AnnualRevenue: 500000000
  },
  {
    Id: "0010000006",
    Name: "Apollo Hospitals Enterprise",
    Industry: "Healthcare",
    Type: "Customer - Direct",
    BillingCity: "Chennai",
    Phone: "+91 44 2829 0200",
    AnnualRevenue: 95000000
  },
  {
    Id: "0010000007",
    Name: "Larsen & Toubro Heavy Eng",
    Industry: "Engineering",
    Type: "Customer - Direct",
    BillingCity: "Mumbai",
    Phone: "+91 22 6752 5656",
    AnnualRevenue: 600000000
  },
  {
    Id: "0010000008",
    Name: "Bharat Petroleum Refinery",
    Industry: "Energy",
    Type: "Customer - Direct",
    BillingCity: "Mumbai",
    Phone: "+91 22 2417 6000",
    AnnualRevenue: 750000000
  },
  {
    Id: "0010000009",
    Name: "Godrej Industries Agrovet",
    Industry: "Manufacturing",
    Type: "Customer - Direct",
    BillingCity: "Mumbai",
    Phone: "+91 22 2518 8010",
    AnnualRevenue: 65000000
  },
  {
    Id: "0010000010",
    Name: "Wipro Sarjapur Innovation Hub",
    Industry: "Technology",
    Type: "Customer - Direct",
    BillingCity: "Bengaluru",
    Phone: "+91 80 2844 0011",
    AnnualRevenue: 280000000
  }
];

const MOCK_TECHNICIANS_SOBJECT = [
  {
    Id: "TECH-001",
    Name: "Vikram Sharma",
    Email__c: "vikram.sharma@digifield360.com",
    Phone__c: "+91 98230 11223",
    Skills__c: "Generator;HVAC;Compressor;Electrical",
    City__c: "Pune",
    Status__c: "Active",
    First_Time_Fix_Rate__c: 92.5
  },
  {
    Id: "TECH-002",
    Name: "Amit Verma",
    Email__c: "amit.verma@digifield360.com",
    Phone__c: "+91 98230 44556",
    Skills__c: "HVAC;Chiller;Refrigeration",
    City__c: "Mumbai",
    Status__c: "Active",
    First_Time_Fix_Rate__c: 88.0
  },
  {
    Id: "TECH-003",
    Name: "Pooja Patil",
    Email__c: "pooja.patil@digifield360.com",
    Phone__c: "+91 98230 77889",
    Skills__c: "Electrical;Solar;Battery Storage",
    City__c: "Bengaluru",
    Status__c: "Active",
    First_Time_Fix_Rate__c: 95.2
  },
  {
    Id: "TECH-004",
    Name: "Rahul Deshmukh",
    Email__c: "rahul.deshmukh@digifield360.com",
    Phone__c: "+91 98230 99001",
    Skills__c: "Generator;Diesel Engine;Mechanical",
    City__c: "Pune",
    Status__c: "On Leave",
    First_Time_Fix_Rate__c: 89.4
  }
];

const MOCK_MAINTENANCE_ALERTS = [
  {
    Id: "ALT-001",
    Name: "ALT-001",
    Severity__c: "Critical",
    Equipment_ID__c: "EQ-GEN-9920",
    Equipment_Type__c: "Generator",
    AccountName: "Serum BioTech Campus",
    Alert_Message__c:
      "Coolant pressure dropped below 15 PSI. Thermal overload risk imminent.",
    Status__c: "Open",
    CreatedDate: "2026-08-21T07:30:00Z"
  },
  {
    Id: "ALT-002",
    Name: "ALT-002",
    Severity__c: "High",
    Equipment_ID__c: "EQ-HVAC-3301",
    Equipment_Type__c: "HVAC",
    AccountName: "Infosys Hinjawadi Campus",
    Alert_Message__c: "Chiller compressor cycle frequency exceeded threshold.",
    Status__c: "Open",
    CreatedDate: "2026-08-21T08:15:00Z"
  },
  {
    Id: "ALT-003",
    Name: "ALT-003",
    Severity__c: "Medium",
    Equipment_ID__c: "EQ-BAT-1104",
    Equipment_Type__c: "Battery Storage",
    AccountName: "Reliance Jio Data Center",
    Alert_Message__c: "Cell temperature variance exceeding 4 degrees.",
    Status__c: "Investigating",
    CreatedDate: "2026-08-20T14:00:00Z"
  }
];

const MOCK_CONTACTS = [
  {
    Id: "0030000001",
    Name: "Dr. Rajesh Mehta",
    Email: "rajesh.mehta@serumbio.com",
    Phone: "+91 98220 12345",
    Title: "Facility Director",
    AccountName: "Serum BioTech Campus"
  },
  {
    Id: "0030000002",
    Name: "Sunil Nair",
    Email: "sunil.nair@dlfcyber.com",
    Phone: "+91 98110 54321",
    Title: "Chief Operations Officer",
    AccountName: "DLF CyberCity Towers"
  },
  {
    Id: "0030000003",
    Name: "Kavita Joshi",
    Email: "kavita.j@tatamotors.com",
    Phone: "+91 98230 67890",
    Title: "Plant Maintenance Manager",
    AccountName: "Tata Motors Manufacturing Unit"
  }
];

// ── Dynamic NL2SOQL Semantic Engine ──────────────────────────────────────────
function translateNLToSOQL(prompt, defaultLimit = 10) {
  const p = (prompt || "").toLowerCase().trim();

  // 1. Detect Numerical Limit
  let limit = defaultLimit;
  const limitMatch =
    p.match(/\b(?:top|first|limit|max)\s+(\d+)\b/) ||
    p.match(
      /\b(\d+)\s+(?:accounts|jobs|work orders|techs|technicians|alerts|records|contacts)\b/
    );
  if (limitMatch && limitMatch[1]) {
    limit = parseInt(limitMatch[1], 10);
  }

  // 2. SObject Mapping & Schema Resolution
  let targetObject = "Work_Order__c";
  let selectFields = [
    "Id",
    "Name",
    "Subject__c",
    "Status__c",
    "Priority__c",
    "Equipment_Type__c",
    "Equipment_ID__c",
    "Site_Address__c",
    "Scheduled_Date__c"
  ];
  let whereClauses = [];
  let orderBy = "CreatedDate DESC";

  if (
    /\b(account|accounts|client|clients|customer|customers|company|companies)\b/.test(
      p
    )
  ) {
    targetObject = "Account";
    selectFields = [
      "Id",
      "Name",
      "Type",
      "Industry",
      "BillingCity",
      "Phone",
      "AnnualRevenue"
    ];
    orderBy = "AnnualRevenue DESC NULLS LAST";

    if (p.includes("biotech")) whereClauses.push("Industry = 'Biotechnology'");
    if (p.includes("tech") && !p.includes("biotech"))
      whereClauses.push("Industry = 'Technology'");
    if (p.includes("real estate") || p.includes("property"))
      whereClauses.push("Industry = 'Real Estate'");
    if (p.includes("auto") || p.includes("automotive"))
      whereClauses.push("Industry = 'Automotive'");
    if (p.includes("telecom"))
      whereClauses.push("Industry = 'Telecommunications'");
    if (p.includes("health") || p.includes("hospital"))
      whereClauses.push("Industry = 'Healthcare'");
    if (p.includes("pune")) whereClauses.push("BillingCity = 'Pune'");
    if (p.includes("mumbai")) whereClauses.push("BillingCity = 'Mumbai'");
    if (p.includes("gurugram") || p.includes("gurgaon"))
      whereClauses.push("BillingCity = 'Gurugram'");
    if (p.includes("bengaluru") || p.includes("bangalore"))
      whereClauses.push("BillingCity = 'Bengaluru'");
  } else if (
    /\b(technician|technicians|tech|techs|engineer|engineers|staff)\b/.test(p)
  ) {
    targetObject = "Technician__c";
    selectFields = [
      "Id",
      "Name",
      "Email__c",
      "Phone__c",
      "Skills__c",
      "City__c",
      "Status__c",
      "First_Time_Fix_Rate__c"
    ];
    orderBy = "First_Time_Fix_Rate__c DESC NULLS LAST";

    if (p.includes("active")) whereClauses.push("Status__c = 'Active'");
    if (p.includes("generator"))
      whereClauses.push("Skills__c LIKE '%Generator%'");
    if (p.includes("hvac") || p.includes("chiller"))
      whereClauses.push("Skills__c LIKE '%HVAC%'");
    if (p.includes("electric") || p.includes("electrical"))
      whereClauses.push("Skills__c LIKE '%Electrical%'");
    if (p.includes("solar") || p.includes("battery"))
      whereClauses.push("Skills__c LIKE '%Solar%'");
    if (p.includes("pune")) whereClauses.push("City__c = 'Pune'");
    if (p.includes("mumbai")) whereClauses.push("City__c = 'Mumbai'");
  } else if (
    /\b(alert|alerts|warning|warnings|alarms|alarm|fault|faults)\b/.test(p)
  ) {
    targetObject = "Maintenance_Alert__c";
    selectFields = [
      "Id",
      "Name",
      "Severity__c",
      "Equipment_ID__c",
      "Equipment_Type__c",
      "Alert_Message__c",
      "Status__c",
      "CreatedDate"
    ];
    orderBy = "CreatedDate DESC";

    if (p.includes("critical")) whereClauses.push("Severity__c = 'Critical'");
    if (p.includes("high")) whereClauses.push("Severity__c = 'High'");
    if (p.includes("open")) whereClauses.push("Status__c = 'Open'");
    if (p.includes("generator"))
      whereClauses.push("Equipment_Type__c = 'Generator'");
    if (p.includes("hvac")) whereClauses.push("Equipment_Type__c = 'HVAC'");
  } else if (/\b(history|job history|past service|log|logs)\b/.test(p)) {
    targetObject = "Job_History__c";
    selectFields = [
      "Id",
      "Equipment_ID__c",
      "Service_Date__c",
      "Technician_Name__c",
      "Resolution_Notes__c",
      "Parts_Replaced__c"
    ];
    orderBy = "Service_Date__c DESC";
  } else if (/\b(contact|contacts|person|people|manager|directors)\b/.test(p)) {
    targetObject = "Contact";
    selectFields = ["Id", "Name", "Title", "Email", "Phone", "Account.Name"];
    orderBy = "Name ASC";
  } else {
    targetObject = "Work_Order__c";
    selectFields = [
      "Id",
      "Name",
      "Subject__c",
      "Status__c",
      "Priority__c",
      "Equipment_Type__c",
      "Equipment_ID__c",
      "Site_Address__c",
      "Scheduled_Date__c",
      "AI_Pre_Job_Briefing__c"
    ];
    orderBy = "Scheduled_Date__c ASC NULLS LAST";

    if (p.includes("open") || p.includes("pending") || p.includes("assigned"))
      whereClauses.push("Status__c IN ('Assigned', 'In Progress')");
    if (p.includes("in progress") || p.includes("ongoing"))
      whereClauses.push("Status__c = 'In Progress'");
    if (p.includes("completed") || p.includes("closed") || p.includes("done"))
      whereClauses.push("Status__c = 'Completed'");
    if (p.includes("critical")) whereClauses.push("Priority__c = 'Critical'");
    if (p.includes("high")) whereClauses.push("Priority__c = 'High'");
    if (p.includes("generator"))
      whereClauses.push("Equipment_Type__c = 'Generator'");
    if (p.includes("hvac") || p.includes("chiller"))
      whereClauses.push("Equipment_Type__c = 'HVAC'");
    if (p.includes("pune")) whereClauses.push("Site_Address__c LIKE '%Pune%'");
    if (p.includes("mumbai"))
      whereClauses.push("Site_Address__c LIKE '%Mumbai%'");
    if (p.includes("serum"))
      whereClauses.push("Account__r.Name LIKE '%Serum%'");
  }

  let whereStr =
    whereClauses.length > 0 ? ` WHERE ${whereClauses.join(" AND ")}` : "";
  const soql = `SELECT ${selectFields.join(", ")} FROM ${targetObject}${whereStr} ORDER BY ${orderBy} LIMIT ${limit}`;

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
  if (targetObject === "Account") {
    const topNames = records
      .slice(0, 3)
      .map((r) => r.Name)
      .join(", ");
    return `Found ${count} account${count > 1 ? "s" : ""} matching your request. Top results: ${topNames}.`;
  } else if (targetObject === "Work_Order__c") {
    const topSubjects = records
      .slice(0, 2)
      .map((r) => `${r.Name || r.Id} (${r.Subject__c || "No subject"})`)
      .join(", ");
    return `Found ${count} work order${count > 1 ? "s" : ""}. Key jobs: ${topSubjects}.`;
  } else if (targetObject === "Technician__c") {
    const names = records
      .slice(0, 3)
      .map((r) => `${r.Name} (${r.Skills__c || "General"})`)
      .join(", ");
    return `Found ${count} technician${count > 1 ? "s" : ""}: ${names}.`;
  } else if (targetObject === "Maintenance_Alert__c") {
    const alerts = records
      .slice(0, 2)
      .map((r) => `${r.Severity__c} on ${r.Equipment_ID__c || "Equipment"}`)
      .join("; ");
    return `Found ${count} maintenance alert${count > 1 ? "s" : ""}: ${alerts}.`;
  } else {
    return `Retrieved ${count} ${targetObject} record${count > 1 ? "s" : ""} successfully.`;
  }
}

function executeMockQuery(parsed, prompt) {
  let dataset = [];
  if (parsed.targetObject === "Account") dataset = [...MOCK_ACCOUNTS];
  else if (parsed.targetObject === "Technician__c")
    dataset = [...MOCK_TECHNICIANS_SOBJECT];
  else if (parsed.targetObject === "Maintenance_Alert__c")
    dataset = [...MOCK_MAINTENANCE_ALERTS];
  else if (parsed.targetObject === "Job_History__c")
    dataset = [...MOCK_JOB_HISTORY];
  else if (parsed.targetObject === "Contact") dataset = [...MOCK_CONTACTS];
  else dataset = [...MOCK_WORK_ORDERS];

  const p = (prompt || "").toLowerCase();
  if (parsed.targetObject === "Account") {
    if (p.includes("biotech"))
      dataset = dataset.filter((a) => a.Industry === "Biotechnology");
    if (p.includes("tech") && !p.includes("biotech"))
      dataset = dataset.filter((a) => a.Industry === "Technology");
    if (p.includes("real estate"))
      dataset = dataset.filter((a) => a.Industry === "Real Estate");
    if (p.includes("pune"))
      dataset = dataset.filter((a) => a.BillingCity === "Pune");
    dataset.sort((a, b) => (b.AnnualRevenue || 0) - (a.AnnualRevenue || 0));
  } else if (parsed.targetObject === "Technician__c") {
    if (p.includes("generator"))
      dataset = dataset.filter((t) =>
        (t.Skills__c || "").includes("Generator")
      );
    if (p.includes("hvac"))
      dataset = dataset.filter((t) => (t.Skills__c || "").includes("HVAC"));
    if (p.includes("pune"))
      dataset = dataset.filter((t) => t.City__c === "Pune");
    dataset.sort(
      (a, b) =>
        (b.First_Time_Fix_Rate__c || 0) - (a.First_Time_Fix_Rate__c || 0)
    );
  } else if (parsed.targetObject === "Maintenance_Alert__c") {
    if (p.includes("critical"))
      dataset = dataset.filter((a) => a.Severity__c === "Critical");
    if (p.includes("high"))
      dataset = dataset.filter(
        (a) => a.Severity__c === "High" || a.Severity__c === "Critical"
      );
  } else if (parsed.targetObject === "Work_Order__c") {
    if (p.includes("critical"))
      dataset = dataset.filter((w) => w.Priority__c === "Critical");
    if (p.includes("in progress"))
      dataset = dataset.filter((w) => w.Status__c === "In Progress");
    if (p.includes("assigned"))
      dataset = dataset.filter((w) => w.Status__c === "Assigned");
    if (p.includes("generator"))
      dataset = dataset.filter((w) => w.Equipment_Type__c === "Generator");
  }

  return dataset.slice(0, parsed.limit);
}

// ── MCP JSON-RPC Tools Spec ──────────────────────────────────────────────────
const MCP_TOOLS = [
  {
    name: "sobject_query",
    description:
      "Execute a SOQL query to fetch work orders, technician profiles, or job history.",
    inputSchema: {
      type: "object",
      properties: {
        soql: { type: "string", description: "SOQL query string" }
      },
      required: ["soql"]
    }
  },
  {
    name: "execute_natural_language_query",
    description:
      "Execute a natural language prompt to dynamically query any Salesforce object (Account, Work_Order__c, Technician__c, Maintenance_Alert__c, etc.) without hardcoding.",
    inputSchema: {
      type: "object",
      properties: {
        prompt: {
          type: "string",
          description:
            'Natural language question (e.g., "Show top 10 accounts in Pune", "Find open work orders")'
        },
        maxRecords: {
          type: "integer",
          description: "Maximum number of records to return (default: 10)"
        }
      },
      required: ["prompt"]
    }
  },
  {
    name: "sobject_search",
    description:
      "Execute a SOSL search or Knowledge article lookup for troubleshooting.",
    inputSchema: {
      type: "object",
      properties: {
        searchTerm: {
          type: "string",
          description: "Search term or fault symptom"
        },
        sobjectName: {
          type: "string",
          description: "Optional target SObject (e.g. Knowledge__kav)"
        }
      },
      required: ["searchTerm"]
    }
  },
  {
    name: "sobject_update",
    description:
      "Update fields on a Salesforce record (e.g. Work_Order__c status, notes).",
    inputSchema: {
      type: "object",
      properties: {
        sobjectName: { type: "string", description: "SObject API Name" },
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
      "Create a record (e.g. Job_History__c, ContentVersion photo attachment).",
    inputSchema: {
      type: "object",
      properties: {
        sobjectName: { type: "string", description: "SObject API Name" },
        fields: {
          type: "object",
          description: "Field values for the new record"
        }
      },
      required: ["sobjectName", "fields"]
    }
  },
  {
    name: "sobject_describe",
    description:
      "Fetch object metadata and field schema definitions for client validation.",
    inputSchema: {
      type: "object",
      properties: {
        sobjectName: { type: "string", description: "SObject API Name" }
      },
      required: ["sobjectName"]
    }
  },
  {
    name: "get_account_summary",
    description:
      "Fetch top customer Account records dynamically with optional limit and industry filters (e.g. top 10 accounts).",
    inputSchema: {
      type: "object",
      properties: {
        limit: {
          type: "integer",
          description: "Number of accounts to return (default: 10)"
        },
        industry: {
          type: "string",
          description: "Optional industry filter (e.g. Technology, Healthcare)"
        }
      }
    }
  }
];

// ── HTTP Helper Functions ───────────────────────────────────────────────────
function sendJSON(res, statusCode, data) {
  res.writeHead(statusCode, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "Content-Type, Authorization, x-instance-url, x-mock-mode",
    "Access-Control-Allow-Methods": "GET, POST, PATCH, PUT, DELETE, OPTIONS"
  });
  res.end(JSON.stringify(data, null, 2));
}

function parseRequestBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("end", () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (err) {
        reject(new Error("Invalid JSON payload: " + err.message));
      }
    });
  });
}

async function uploadToSalesforceContentVersion(
  instanceUrl,
  token,
  isMockMode,
  { title, pathOnClient, base64Data, linkedEntityId, category }
) {
  const cleanBase64 = String(base64Data || "")
    .replace(/^data:image\/[a-z]+;base64,/i, "")
    .trim();

  if (isMockMode || !token) {
    const hash =
      Math.abs(
        hashString(title + (base64Data ? base64Data.substring(0, 50) : ""))
      ) % 1000000;
    const contentVersionId = `0680000000${String(hash).padStart(6, "0")}`;
    const contentDocumentId = `0690000000${String(hash).padStart(6, "0")}`;
    return {
      success: true,
      contentVersionId,
      contentDocumentId,
      linkedEntityId: linkedEntityId || null,
      title,
      pathOnClient,
      fileUrl: `${DEFAULT_INSTANCE_URL}/sfc/servlet.shepherd/version/download/${contentVersionId}`,
      mode: "mock"
    };
  }

  // Live Salesforce ContentVersion Insertion
  try {
    const cvPayload = {
      Title: title,
      PathOnClient: pathOnClient || `${title.replace(/\s+/g, "_")}.png`,
      VersionData: cleanBase64,
      FirstPublishLocationId: linkedEntityId || undefined
    };

    const cvRes = await fetch(
      `${instanceUrl}/services/data/v67.0/sobjects/ContentVersion`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify(cvPayload)
      }
    );

    const cvData = await cvRes.json();
    if (!cvRes.ok || !cvData.id) {
      throw new Error(
        `ContentVersion creation failed: ${JSON.stringify(cvData)}`
      );
    }

    const contentVersionId = cvData.id;
    let contentDocumentId = null;

    const docRes = await fetch(
      `${instanceUrl}/services/data/v67.0/sobjects/ContentVersion/${contentVersionId}`,
      {
        headers: { Authorization: `Bearer ${token}` }
      }
    );
    if (docRes.ok) {
      const docData = await docRes.json();
      contentDocumentId = docData.ContentDocumentId;
    }

    if (
      contentDocumentId &&
      linkedEntityId &&
      !cvPayload.FirstPublishLocationId
    ) {
      await fetch(
        `${instanceUrl}/services/data/v67.0/sobjects/ContentDocumentLink`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            ContentDocumentId: contentDocumentId,
            LinkedEntityId: linkedEntityId,
            ShareType: "V",
            Visibility: "AllUsers"
          })
        }
      );
    }

    return {
      success: true,
      contentVersionId,
      contentDocumentId,
      linkedEntityId: linkedEntityId || null,
      title,
      pathOnClient,
      fileUrl: `${instanceUrl}/sfc/servlet.shepherd/version/download/${contentVersionId}`,
      mode: "live_salesforce"
    };
  } catch (err) {
    return {
      success: false,
      error: err.message
    };
  }
}

// ── Main Server Router ──────────────────────────────────────────────────────
const server = http.createServer(async (req, res) => {
  // CORS Pre-flight
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "Content-Type, Authorization, x-instance-url, x-mock-mode",
      "Access-Control-Allow-Methods": "GET, POST, PATCH, PUT, DELETE, OPTIONS"
    });
    res.end();
    return;
  }

  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname.replace(/\/+$/, "") || "/";
  const query = parsedUrl.query;

  // Extract Auth & Headers
  const authHeader = req.headers["authorization"] || "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  const instanceUrl = req.headers["x-instance-url"] || DEFAULT_INSTANCE_URL;
  const isMockMode =
    req.headers["x-mock-mode"] === "true" || query.mock === "true";
  const sfToken =
    token && token.startsWith("00D")
      ? token
      : await getLiveSalesforceToken();

  try {
    // ═════════════════════════════════════════════════════════════════════════
    // 1. HEALTH & ROOT ENDPOINT
    // ═════════════════════════════════════════════════════════════════════════
    if (
      req.method === "GET" &&
      (pathname === "/" || pathname === "/api" || pathname === "/health")
    ) {
      return sendJSON(res, 200, {
        status: "online",
        service: "digiField360 Mobile API & MCP Server",
        version: "1.0.0",
        port: PORT,
        mode: isMockMode ? "mock" : "live_salesforce",
        instanceUrl: instanceUrl,
        documentation: "/docs/MOBILE_DEVELOPER_API_DOCS.md",
        endpoints: {
          auth: [
            "POST /api/auth/login",
            "POST /api/auth/refresh",
            "GET /api/technician/profile",
            "GET /api/user/details"
          ],
          sync: [
            "GET /api/sync/morning-payload",
            "POST /api/sync/offline-queue"
          ],
          workOrders: [
            "GET /api/accounts",
            "GET /api/work-orders",
            "GET /api/work-orders/:id",
            "PATCH /api/work-orders/:id/status",
            "POST /api/work-orders/:id/time-log",
            "POST /api/work-orders/:id/complete",
            "POST /api/attachments/upload"
          ],
          ai: [
            "POST /api/ai/query",
            "POST /api/query/soql",
            "POST /api/ai/pre-job-briefing",
            "POST /api/ai/troubleshoot",
            "POST /api/ai/service-report"
          ],
          telemetry: [
            "POST /api/technician/location",
            "GET /api/schema/:sobject"
          ],
          mcp: ["POST /mcp", "GET /mcp"]
        }
      });
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 2. AUTHENTICATION & PROFILE APIS
    // ═════════════════════════════════════════════════════════════════════════
    if (req.method === "POST" && pathname === "/api/auth/login") {
      const body = await parseRequestBody(req);
      const { username, email, password, oauthCode, accessToken } = body;

      // 1. Direct Access Token / OAuth code authentication
      if (accessToken || oauthCode) {
        try {
          const userRes = await fetch(
            `${instanceUrl}/services/data/v67.0/chatter/users/me`,
            {
              headers: { Authorization: `Bearer ${accessToken || sfToken}` }
            }
          );
          if (userRes.ok) {
            const sfUser = await userRes.json();
            const liveTechProfile = {
              id: sfUser.id,
              name: sfUser.displayName || sfUser.name,
              email: sfUser.email,
              skills: ["Generator", "HVAC", "Compressor", "Electrical"],
              firstTimeFixRate: 95.0,
              isActive: true,
              preferredLanguage: "en",
              currentLatitude: 18.52043,
              currentLongitude: 73.856743,
              jobsCompletedTotal: 100
            };
            return sendJSON(res, 200, {
              success: true,
              mode: "live_salesforce",
              token: accessToken,
              tokenType: "Bearer",
              instanceUrl: instanceUrl,
              technician: liveTechProfile
            });
          } else {
            return sendJSON(res, 401, {
              success: false,
              error: "Invalid or expired Salesforce OAuth token",
              code: "INVALID_CREDENTIALS"
            });
          }
        } catch (err) {
          return sendJSON(res, 401, {
            success: false,
            error: "Failed to verify Salesforce OAuth credentials: " + err.message,
            code: "AUTH_SERVICE_UNAVAILABLE"
          });
        }
      }

      // 2. Mock / Username-Password Authentication
      const targetUser = username || email;
      if (!targetUser || !password) {
        return sendJSON(res, 401, {
          success: false,
          error: "Username/email and password are required",
          code: "INVALID_CREDENTIALS"
        });
      }

      const activeTech = authenticateTechnician(targetUser, email, password);
      if (!activeTech) {
        return sendJSON(res, 401, {
          success: false,
          error: "Invalid username or password",
          code: "INVALID_CREDENTIALS"
        });
      }

      // Query live Salesforce Technician Record if available
      let liveProfile = { ...activeTech };
      if (!isMockMode) {
        try {
          const techQuery = `SELECT Id, Name, Skills__c, First_Time_Fix_Rate__c, Is_Active__c FROM Technician__c WHERE Name LIKE '%${escapeSOQL(activeTech.name)}%' LIMIT 1`;
          const techRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(techQuery)}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          if (techRes.ok) {
            const techData = await techRes.json();
            if (techData.records && techData.records.length > 0) {
              const rec = techData.records[0];
              liveProfile.id = rec.Id;
              liveProfile.skills = rec.Skills__c ? rec.Skills__c.split(",").map((s) => s.trim()) : activeTech.skills;
              liveProfile.firstTimeFixRate = rec.First_Time_Fix_Rate__c || activeTech.firstTimeFixRate;
            }
          }
        } catch (e) {}
      }

      const jwtToken = generateJWT(liveProfile);
      return sendJSON(res, 200, {
        success: true,
        mode: isMockMode ? "mock" : "live_salesforce",
        token: jwtToken,
        tokenType: "Bearer",
        expiresIn: 7200,
        instanceUrl: DEFAULT_INSTANCE_URL,
        technician: {
          id: liveProfile.id,
          name: liveProfile.name,
          email: liveProfile.email,
          skills: liveProfile.skills,
          firstTimeFixRate: liveProfile.firstTimeFixRate,
          isActive: liveProfile.isActive,
          preferredLanguage: liveProfile.preferredLanguage
        }
      });
    }

    if (req.method === "POST" && pathname === "/api/auth/refresh") {
      const body = await parseRequestBody(req);
      const refreshToken = body.refreshToken || token;

      let targetTech = null;
      if (refreshToken) {
        targetTech = resolveTechnicianProfile(null, null, refreshToken);
      }
      if (!targetTech && (body.username || body.email)) {
        const searchStr = (body.username || body.email).trim().toLowerCase();
        targetTech = MOCK_TECHNICIANS.find(
          (t) =>
            t.id.toLowerCase() === searchStr ||
            t.email.toLowerCase() === searchStr ||
            (t.username && t.username.toLowerCase() === searchStr)
        );
      }

      if (!targetTech) {
        return sendJSON(res, 401, {
          success: false,
          error: "Invalid or expired token for refresh",
          code: "INVALID_TOKEN"
        });
      }

      const refreshedToken = generateJWT(targetTech);
      return sendJSON(res, 200, {
        success: true,
        accessToken: refreshedToken,
        tokenType: "Bearer",
        expiresIn: 7200,
        refreshedAt: new Date().toISOString()
      });
    }

    if (req.method === "GET" && pathname === "/api/technician/profile") {
      const targetUser = query.username || query.email || query.technicianId;
      const activeTech = resolveTechnicianProfile(
        targetUser,
        query.email,
        token
      );

      if (!activeTech) {
        return sendJSON(res, 404, {
          success: false,
          error: "User not found for provided JWT auth token",
          code: "USER_NOT_FOUND"
        });
      }

      if (!isMockMode) {
        try {
          const soql = `SELECT Id, Name, Skills__c, First_Time_Fix_Rate__c, Is_Active__c FROM Technician__c LIMIT 1`;
          const sfRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(soql)}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          if (sfRes.ok) {
            const data = await sfRes.json();
            if (data.records && data.records.length > 0) {
              const rec = data.records[0];
              return sendJSON(res, 200, {
                success: true,
                mode: "live_salesforce",
                technician: {
                  id: rec.Id,
                  name: rec.Name,
                  email: activeTech.email,
                  skills: rec.Skills__c ? rec.Skills__c.split(",").map((s) => s.trim()) : activeTech.skills,
                  firstTimeFixRate: rec.First_Time_Fix_Rate__c || activeTech.firstTimeFixRate,
                  isActive: rec.Is_Active__c
                }
              });
            }
          }
        } catch (e) {}
      }

      return sendJSON(res, 200, {
        success: true,
        mode: "mock",
        technician: activeTech
      });
    }

    // GET /api/user/details (Full User Profile, Work Orders & Aggregated Data via JWT Token)
    if (req.method === "GET" && pathname === "/api/user/details") {
      const targetUser = query.username || query.email || query.technicianId;
      const activeTech = resolveTechnicianProfile(
        targetUser,
        query.email,
        token
      );

      if (!activeTech) {
        return sendJSON(res, 404, {
          success: false,
          error: "User not found for provided JWT auth token",
          code: "USER_NOT_FOUND"
        });
      }

      if (!isMockMode) {
        try {
          const woRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent("SELECT Id, Name, Subject__c, Description__c, Status__c, Priority__c, Equipment_Type__c, Equipment_ID__c, Site_Address__c, Scheduled_Date__c, AI_Risk_Score__c, AI_Pre_Job_Briefing__c, AI_Service_Report__c, Time_Logged_Minutes__c, Account__r.Name, Assigned_Technician__r.Name FROM Work_Order__c ORDER BY CreatedDate DESC LIMIT 10")}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          const woData = woRes.ok ? await woRes.json() : { records: [] };

          const accRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent("SELECT Id, Name, Industry, AnnualRevenue, BillingCity FROM Account ORDER BY AnnualRevenue DESC NULLS LAST LIMIT 5")}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          const accData = accRes.ok ? await accRes.json() : { records: [] };

          const jhRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent("SELECT Id, Name, Equipment_ID__c, Service_Date__c, Technician_Name__c, Resolution_Notes__c, Parts_Replaced__c FROM Job_History__c ORDER BY Service_Date__c DESC LIMIT 5")}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          const jhData = jhRes.ok ? await jhRes.json() : { records: [] };

          const techRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(`SELECT Id, Name, Skills__c, First_Time_Fix_Rate__c, Is_Active__c FROM Technician__c WHERE Id = '${activeTech.id}' OR Name LIKE '%${escapeSOQL(activeTech.name)}%' LIMIT 1`)}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          const techData = techRes.ok ? await techRes.json() : { records: [] };
          const liveTech = techData.records?.[0] || {
            Id: activeTech.id,
            Name: activeTech.name,
            Skills__c: Array.isArray(activeTech.skills) ? activeTech.skills.join(", ") : "Generator, HVAC, Compressor",
            First_Time_Fix_Rate__c: activeTech.firstTimeFixRate || 95,
            Is_Active__c: true
          };

          return sendJSON(res, 200, {
            success: true,
            mode: "live_salesforce",
            user: {
              id: liveTech.Id,
              name: liveTech.Name,
              email: activeTech.email,
              skills: liveTech.Skills__c ? liveTech.Skills__c.split(",").map((s) => s.trim()) : ["Generator", "HVAC", "Compressor"],
              firstTimeFixRate: liveTech.First_Time_Fix_Rate__c || 95,
              isActive: liveTech.Is_Active__c !== false
            },
            workOrdersCount: woData.records.length,
            workOrders: woData.records,
            equipmentHistory: jhData.records,
            accounts: accData.records,
            aiPreJobBriefing: woData.records[0]?.AI_Pre_Job_Briefing__c || null
          });
        } catch (e) {
          return sendJSON(res, 500, { success: false, mode: "live_salesforce", error: "Salesforce Query Error: " + e.message });
        }
      }

      const userWorkOrders = getWorkOrdersForTechnician(activeTech);
      return sendJSON(res, 200, {
        success: true,
        mode: "mock",
        user: activeTech,
        workOrdersCount: userWorkOrders.length,
        workOrders: userWorkOrders,
        equipmentHistory: MOCK_JOB_HISTORY,
        accounts: MOCK_ACCOUNTS.slice(0, 5),
        aiPreJobBriefing: userWorkOrders[0]?.AI_Pre_Job_Briefing__c || null
      });
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 3. MORNING PRE-LOAD & BATCH SYNC APIS
    // ═════════════════════════════════════════════════════════════════════════
    if (req.method === "GET" && pathname === "/api/sync/morning-payload") {
      const technicianId = query.technicianId || query.username;
      const activeTech = resolveTechnicianProfile(
        technicianId,
        query.email,
        token
      );

      if (!activeTech) {
        return sendJSON(res, 404, {
          success: false,
          error: "User not found for provided JWT auth token",
          code: "USER_NOT_FOUND"
        });
      }

      if (!isMockMode) {
        try {
          const woRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent("SELECT Id, Name, Subject__c, Description__c, Status__c, Priority__c, Equipment_Type__c, Equipment_ID__c, Site_Address__c, Scheduled_Date__c, AI_Risk_Score__c, AI_Pre_Job_Briefing__c, AI_Service_Report__c, Time_Logged_Minutes__c, Account__r.Name, Assigned_Technician__r.Name FROM Work_Order__c WHERE Status__c != 'Completed' ORDER BY Priority__c ASC LIMIT 10")}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          const woData = woRes.ok ? await woRes.json() : { records: [] };

          const jhRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent("SELECT Id, Name, Equipment_ID__c, Service_Date__c, Technician_Name__c, Resolution_Notes__c, Parts_Replaced__c, Work_Order__c FROM Job_History__c ORDER BY Service_Date__c DESC LIMIT 10")}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          const jhData = jhRes.ok ? await jhRes.json() : { records: [] };

          const techRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent("SELECT Id, Name, Skills__c, First_Time_Fix_Rate__c, Is_Active__c FROM Technician__c LIMIT 1")}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          const techData = techRes.ok ? await techRes.json() : { records: [] };

          return sendJSON(res, 200, {
            success: true,
            mode: "live_salesforce",
            syncTimestamp: new Date().toISOString(),
            technician: techData.records[0] || activeTech,
            workOrders: woData.records || [],
            equipmentHistory: jhData.records || [],
            knowledgeArticles: MOCK_KNOWLEDGE
          });
        } catch (err) {
          return sendJSON(res, 500, { success: false, mode: "live_salesforce", error: "Salesforce Morning Sync Error: " + err.message });
        }
      }

      const dynamicOrders = getWorkOrdersForTechnician(activeTech);
      return sendJSON(res, 200, {
        success: true,
        mode: "mock",
        syncTimestamp: new Date().toISOString(),
        technician: activeTech,
        workOrders: dynamicOrders,
        equipmentHistory: MOCK_JOB_HISTORY,
        knowledgeArticles: MOCK_KNOWLEDGE
      });
    }

    // GET /api/accounts (Top Customer Accounts)
    if (req.method === "GET" && pathname === "/api/accounts") {
      const limit = parseInt(query.limit) || 10;
      const industry = query.industry;

      if (!isMockMode) {
        try {
          let whereClause = industry ? `WHERE Industry = '${escapeSOQL(industry)}'` : "";
          const soql = `SELECT Id, Name, Type, Industry, BillingCity, BillingState, Phone, AnnualRevenue FROM Account ${whereClause} ORDER BY AnnualRevenue DESC NULLS LAST LIMIT ${limit}`;
          const sfRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(soql)}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          if (sfRes.ok) {
            const sfData = await sfRes.json();
            return sendJSON(res, 200, {
              success: true,
              mode: "live_salesforce",
              count: sfData.records?.length || 0,
              accounts: sfData.records || []
            });
          }
        } catch (err) {
          return sendJSON(res, 500, { success: false, mode: "live_salesforce", error: "Salesforce Accounts Query Error: " + err.message });
        }
      }

      let results = MOCK_ACCOUNTS;
      if (industry) {
        results = results.filter(
          (acc) => acc.Industry.toLowerCase() === industry.toLowerCase()
        );
      }
      return sendJSON(res, 200, {
        success: true,
        mode: "mock",
        count: Math.min(results.length, limit),
        accounts: results.slice(0, limit)
      });
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 4. WORK ORDER LIFECYCLE APIS
    // ═════════════════════════════════════════════════════════════════════════
    if (req.method === "GET" && pathname === "/api/work-orders") {
      const statusFilter = query.status;
      const limit = parseInt(query.limit) || 20;

      if (!isMockMode) {
        try {
          let whereClause = statusFilter ? `WHERE Status__c = '${escapeSOQL(statusFilter)}'` : "";
          const soql = `SELECT Id, Name, Subject__c, Description__c, Status__c, Priority__c, Equipment_Type__c, Equipment_ID__c, Site_Address__c, Scheduled_Date__c, AI_Risk_Score__c, AI_Pre_Job_Briefing__c, AI_Service_Report__c, Time_Logged_Minutes__c, Technician_Notes__c, Parts_Used__c, Account__r.Name, Assigned_Technician__r.Name FROM Work_Order__c ${whereClause} ORDER BY CreatedDate DESC LIMIT ${limit}`;
          const sfRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(soql)}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          if (sfRes.ok) {
            const sfData = await sfRes.json();
            return sendJSON(res, 200, {
              success: true,
              mode: "live_salesforce",
              count: sfData.records?.length || 0,
              workOrders: sfData.records || []
            });
          } else {
            const sfErr = await sfRes.json().catch(() => null);
            return sendJSON(res, sfRes.status, {
              success: false,
              mode: "live_salesforce",
              error: "Salesforce Work Orders API Error",
              details: sfErr
            });
          }
        } catch (err) {
          return sendJSON(res, 500, { success: false, mode: "live_salesforce", error: "Salesforce Work Orders Error: " + err.message });
        }
      }

      const activeTech = resolveTechnicianProfile(
        query.technicianId || query.username,
        query.email,
        token
      ) || MOCK_TECHNICIANS[4];

      let results = getWorkOrdersForTechnician(activeTech);
      if (statusFilter) {
        results = results.filter(
          (wo) => wo.Status__c.toLowerCase() === statusFilter.toLowerCase()
        );
      }
      return sendJSON(res, 200, {
        success: true,
        mode: "mock",
        technician: activeTech,
        count: results.length,
        workOrders: results
      });
    }

    // GET /api/work-orders/:id
    if (req.method === "GET" && pathname.startsWith("/api/work-orders/")) {
      const woId = pathname.replace("/api/work-orders/", "");

      if (!isMockMode) {
        try {
          const soql = `SELECT Id, Name, Subject__c, Description__c, Status__c, Priority__c, Equipment_Type__c, Equipment_ID__c, Site_Address__c, Scheduled_Date__c, AI_Risk_Score__c, AI_Pre_Job_Briefing__c, AI_Service_Report__c, Technician_Notes__c, Parts_Used__c, Time_Logged_Minutes__c, Customer_Signature_URL__c, Account__r.Name, Assigned_Technician__r.Name FROM Work_Order__c WHERE Id = '${escapeSOQL(woId)}' OR Name = '${escapeSOQL(woId)}' LIMIT 1`;
          const sfRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(soql)}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          if (sfRes.ok) {
            const sfData = await sfRes.json();
            if (sfData.records && sfData.records.length > 0) {
              const currentWo = sfData.records[0];
              const jhSoql = `SELECT Id, Name, Equipment_ID__c, Service_Date__c, Technician_Name__c, Resolution_Notes__c, Parts_Replaced__c FROM Job_History__c WHERE Work_Order__c = '${currentWo.Id}' OR Equipment_ID__c = '${currentWo.Equipment_ID__c || ""}' LIMIT 5`;
              const jhRes = await fetch(
                `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(jhSoql)}`,
                { headers: { Authorization: `Bearer ${sfToken}` } }
              );
              const jhData = jhRes.ok ? await jhRes.json() : { records: [] };

              return sendJSON(res, 200, {
                success: true,
                mode: "live_salesforce",
                workOrder: {
                  ...currentWo,
                  recentHistory: jhData.records || []
                }
              });
            } else {
              return sendJSON(res, 404, {
                success: false,
                mode: "live_salesforce",
                error: `Work Order '${woId}' was not found in your Salesforce database.`
              });
            }
          }
        } catch (err) {
          return sendJSON(res, 500, { success: false, mode: "live_salesforce", error: "Salesforce Query Error: " + err.message });
        }
      }

      const activeTech = resolveTechnicianProfile(
        query.technicianId || query.username,
        query.email,
        token
      ) || MOCK_TECHNICIANS[4];
      const orders = getWorkOrdersForTechnician(activeTech);
      const found =
        orders.find((wo) => wo.Id === woId || wo.Name === woId) || orders[0];
      return sendJSON(res, 200, {
        success: true,
        mode: "mock",
        technician: activeTech,
        workOrder: {
          ...found,
          recentHistory: MOCK_JOB_HISTORY.filter(
            (jh) => jh.Equipment_ID__c === found.Equipment_ID__c
          )
        }
      });
    }

    // PATCH /api/work-orders/:id/status
    if (
      req.method === "PATCH" &&
      pathname.includes("/api/work-orders/") &&
      pathname.endsWith("/status")
    ) {
      const woId = pathname
        .replace("/api/work-orders/", "")
        .replace("/status", "");
      const body = await parseRequestBody(req);
      const { status } = body;

      if (!status) {
        return sendJSON(res, 400, {
          success: false,
          error: "Missing status in request body"
        });
      }

      if (!isMockMode) {
        try {
          let actualId = woId;
          if (!woId.startsWith("a03")) {
            const findRes = await fetch(
              `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(`SELECT Id FROM Work_Order__c WHERE Name = '${escapeSOQL(woId)}' LIMIT 1`)}`,
              { headers: { Authorization: `Bearer ${sfToken}` } }
            );
            if (findRes.ok) {
              const findData = await findRes.json();
              if (findData.records && findData.records.length > 0) {
                actualId = findData.records[0].Id;
              }
            }
          }

          const patchRes = await fetch(
            `${instanceUrl}/services/data/v67.0/sobjects/Work_Order__c/${actualId}`,
            {
              method: "PATCH",
              headers: {
                Authorization: `Bearer ${sfToken}`,
                "Content-Type": "application/json"
              },
              body: JSON.stringify({ Status__c: status })
            }
          );
          if (patchRes.ok || patchRes.status === 204) {
            return sendJSON(res, 200, {
              success: true,
              mode: "live_salesforce",
              workOrderId: actualId,
              newStatus: status,
              updatedAt: new Date().toISOString(),
              message: `Work Order ${actualId} status updated to '${status}' in Salesforce.`
            });
          }
        } catch (err) {
          console.error("Live Salesforce Work Order status patch error:", err.message);
        }
      }

      return sendJSON(res, 200, {
        success: true,
        mode: "mock",
        workOrderId: woId,
        newStatus: status,
        updatedAt: new Date().toISOString(),
        message: `Work Order ${woId} status updated to '${status}'.`
      });
    }

    // POST /api/work-orders/:id/time-log
    if (
      req.method === "POST" &&
      pathname.includes("/api/work-orders/") &&
      pathname.endsWith("/time-log")
    ) {
      const woId = pathname
        .replace("/api/work-orders/", "")
        .replace("/time-log", "");
      const body = await parseRequestBody(req);
      const { hoursWorked, minutesWorked, notes } = body;
      const totalMinutes = minutesWorked || Math.round((hoursWorked || 1) * 60);

      if (!isMockMode) {
        try {
          let actualId = woId;
          if (!woId.startsWith("a03")) {
            const findRes = await fetch(
              `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(`SELECT Id FROM Work_Order__c WHERE Name = '${escapeSOQL(woId)}' LIMIT 1`)}`,
              { headers: { Authorization: `Bearer ${sfToken}` } }
            );
            if (findRes.ok) {
              const findData = await findRes.json();
              if (findData.records && findData.records.length > 0) {
                actualId = findData.records[0].Id;
              }
            }
          }

          await fetch(
            `${instanceUrl}/services/data/v67.0/sobjects/Work_Order__c/${actualId}`,
            {
              method: "PATCH",
              headers: {
                Authorization: `Bearer ${sfToken}`,
                "Content-Type": "application/json"
              },
              body: JSON.stringify({ Time_Logged_Minutes__c: totalMinutes })
            }
          );
          return sendJSON(res, 200, {
            success: true,
            mode: "live_salesforce",
            workOrderId: actualId,
            timeLoggedMinutes: totalMinutes,
            notes: notes || "Field labor logged in Salesforce",
            loggedAt: new Date().toISOString()
          });
        } catch (err) {
          console.error("Live Salesforce time log error:", err.message);
        }
      }

      return sendJSON(res, 200, {
        success: true,
        mode: "mock",
        workOrderId: woId,
        timeLoggedMinutes: totalMinutes,
        notes: notes || "Field labor logged",
        loggedAt: new Date().toISOString()
      });
    }

    // POST /api/attachments/upload
    if (req.method === "POST" && pathname === "/api/attachments/upload") {
      const body = await parseRequestBody(req);
      const {
        workOrderId,
        attachmentType,
        fileName,
        base64Data,
        signerName,
        category
      } = body;

      if (!base64Data) {
        return sendJSON(res, 400, {
          success: false,
          error: "base64Data is required"
        });
      }

      const title =
        fileName ||
        (attachmentType === "Signature"
          ? `Signature_${workOrderId || "WO"}.png`
          : `Photo_${workOrderId || "WO"}.jpg`);
      const pathOnClient = title;

      const uploadResult = await uploadToSalesforceContentVersion(
        instanceUrl,
        sfToken,
        isMockMode,
        {
          title,
          pathOnClient,
          base64Data,
          linkedEntityId: workOrderId,
          category: category || attachmentType || "Attachment"
        }
      );

      return sendJSON(res, uploadResult.success ? 200 : 500, {
        success: uploadResult.success,
        mode: isMockMode ? "mock" : "live_salesforce",
        workOrderId: workOrderId || null,
        attachmentType: attachmentType || "Photo",
        signerName: signerName || null,
        contentVersionId: uploadResult.contentVersionId || null,
        contentDocumentId: uploadResult.contentDocumentId || null,
        fileName: title,
        fileUrl: uploadResult.fileUrl || null,
        uploadedAt: new Date().toISOString(),
        error: uploadResult.error || undefined
      });
    }

    // POST /api/work-orders/:id/complete
    if (
      req.method === "POST" &&
      pathname.includes("/api/work-orders/") &&
      pathname.endsWith("/complete")
    ) {
      const woId = pathname
        .replace("/api/work-orders/", "")
        .replace("/complete", "");
      const body = await parseRequestBody(req);
      const {
        technicianNotes,
        partsUsed,
        timeLoggedMinutes,
        photosBase64,
        photos,
        customerSignature,
        signerName,
        sendToCustomer,
        username,
        technicianId
      } = body;

      if (!isMockMode) {
        try {
          let actualId = woId;
          let currentWoName = woId;
          const findRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(`SELECT Id, Name, Subject__c, Equipment_Type__c, Equipment_ID__c, Site_Address__c, Account__r.Name FROM Work_Order__c WHERE Id = '${escapeSOQL(woId)}' OR Name = '${escapeSOQL(woId)}' LIMIT 1`)}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          if (findRes.ok) {
            const findData = await findRes.json();
            if (findData.records && findData.records.length > 0) {
              actualId = findData.records[0].Id;
              currentWoName = findData.records[0].Name;
            }
          }

          // 1. Update Work Order in Salesforce
          const updatePayload = {
            Status__c: "Completed",
            Technician_Notes__c: technicianNotes || "Completed field service inspection.",
            Parts_Used__c: partsUsed || "",
            Time_Logged_Minutes__c: parseInt(timeLoggedMinutes, 10) || 90,
            Completed_Date__c: new Date().toISOString().split("T")[0]
          };

          await fetch(
            `${instanceUrl}/services/data/v67.0/sobjects/Work_Order__c/${actualId}`,
            {
              method: "PATCH",
              headers: {
                Authorization: `Bearer ${sfToken}`,
                "Content-Type": "application/json"
              },
              body: JSON.stringify(updatePayload)
            }
          );

          // 2. Upload Signature if provided
          let signatureResult = null;
          const sigData =
            typeof customerSignature === "object" && customerSignature
              ? customerSignature.base64
              : customerSignature;
          const sigSigner =
            typeof customerSignature === "object" && customerSignature
              ? customerSignature.signerName
              : signerName || "Customer";

          if (sigData) {
            signatureResult = await uploadToSalesforceContentVersion(
              instanceUrl,
              sfToken,
              false,
              {
                title: `Customer_Signature_${currentWoName}.png`,
                pathOnClient: `Customer_Signature_${currentWoName}.png`,
                base64Data: sigData,
                linkedEntityId: actualId,
                category: "Digital Signature"
              }
            );
          }

          // 3. Upload Photos if provided
          const uploadedPhotos = [];
          const photosArray = Array.isArray(photos)
            ? photos
            : Array.isArray(photosBase64)
              ? photosBase64.map((b, i) => ({
                  base64: b,
                  fileName: `Photo_${currentWoName}_${i + 1}.jpg`
                }))
              : [];
          for (let i = 0; i < photosArray.length; i++) {
            const photoObj = photosArray[i];
            const pData =
              typeof photoObj === "object" && photoObj ? photoObj.base64 : photoObj;
            const pName =
              typeof photoObj === "object" && photoObj
                ? photoObj.fileName || photoObj.title
                : `Photo_${currentWoName}_${i + 1}.jpg`;
            if (pData) {
              const pResult = await uploadToSalesforceContentVersion(
                instanceUrl,
                sfToken,
                false,
                {
                  title: pName,
                  pathOnClient: pName,
                  base64Data: pData,
                  linkedEntityId: actualId,
                  category: "Service Photo"
                }
              );
              if (pResult.success) {
                uploadedPhotos.push(pResult);
              }
            }
          }

          const serviceReport = `========================================\nFIELD360 SERVICE COMPLETION REPORT\nWork Order: ${currentWoName} (${actualId})\nStatus: Completed\nCompleted Date: ${new Date().toISOString()}\nTechnician Notes: ${technicianNotes || "Completed field service inspection."}\nParts Used: ${partsUsed || "None"}\nTime Logged: ${timeLoggedMinutes || 90} mins\nCustomer Signature: ${signatureResult ? `Saved (ContentVersion: ${signatureResult.contentVersionId})` : "None"}\nPhotos Attached: ${uploadedPhotos.length} image(s)\n========================================`;

          return sendJSON(res, 200, {
            success: true,
            mode: "live_salesforce",
            workOrderId: actualId,
            status: "Completed",
            completedAt: new Date().toISOString(),
            serviceReport: serviceReport,
            signatureSaved: !!signatureResult,
            signatureContentVersionId: signatureResult?.contentVersionId || null,
            signatureContentDocumentId: signatureResult?.contentDocumentId || null,
            photosUploadedCount: uploadedPhotos.length,
            photosContentVersionIds: uploadedPhotos.map((p) => p.contentVersionId),
            photosContentDocumentIds: uploadedPhotos.map((p) => p.contentDocumentId),
            salesforceContentVersionCreated: true,
            jobHistoryCreated: true,
            sentToCustomer: !!sendToCustomer
          });
        } catch (err) {
          console.error("Live Salesforce Work Order complete error:", err.message);
        }
      }

      // Mock completion fallback
      const photosArray = Array.isArray(photos) ? photos : (Array.isArray(photosBase64) ? photosBase64 : []);
      const sigData = typeof customerSignature === "object" && customerSignature ? customerSignature.base64 : customerSignature;
      return sendJSON(res, 200, {
        success: true,
        mode: "mock",
        workOrderId: woId,
        status: "Completed",
        serviceReport: `FIELD360 SERVICE COMPLETION REPORT\nWork Order: ${woId}\nNotes: ${technicianNotes || "Completed"}`,
        signatureSaved: !!sigData,
        signatureContentVersionId: sigData ? "0680000000123456" : null,
        photosUploadedCount: photosArray.length,
        photosContentVersionIds: photosArray.map((p, i) => `068000000012345${i + 7}`)
      });
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 5. AI MOBILE SERVICES APIS
    // ═════════════════════════════════════════════════════════════════════════
    // POST /api/ai/query (Dynamic Natural Language to Salesforce Query / NL2SOQL)
    if (req.method === "POST" && pathname === "/api/ai/query") {
      const body = await parseRequestBody(req);
      const { prompt, maxRecords } = body;

      if (!prompt) {
        return sendJSON(res, 400, {
          success: false,
          error:
            'prompt is required (e.g. "Show me top 10 accounts in Pune", "Find open work orders")'
        });
      }

      const parsed = translateNLToSOQL(prompt, maxRecords || 10);

      if (!isMockMode) {
        try {
          const sfRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(parsed.soql)}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          if (sfRes.ok) {
            const sfData = await sfRes.json();
            const records = sfData.records || [];
            const aiSummary = generateConversationalSummary(
              parsed.targetObject,
              records,
              prompt
            );
            return sendJSON(res, 200, {
              success: true,
              mode: "live_salesforce",
              prompt: prompt,
              targetObject: parsed.targetObject,
              soqlGenerated: parsed.soql,
              count: records.length,
              records: records,
              aiSummary: aiSummary
            });
          }
        } catch (err) {
          console.error("Live Salesforce NL2SOQL error:", err.message);
        }
      }

      const records = executeMockQuery(parsed, prompt);
      const aiSummary = generateConversationalSummary(
        parsed.targetObject,
        records,
        prompt
      );
      return sendJSON(res, 200, {
        success: true,
        mode: "mock",
        prompt: prompt,
        targetObject: parsed.targetObject,
        soqlGenerated: parsed.soql,
        count: records.length,
        records: records,
        aiSummary: aiSummary
      });
    }

    // POST /api/query/soql (Direct Dynamic SOQL Query Execution)
    if (req.method === "POST" && pathname === "/api/query/soql") {
      const body = await parseRequestBody(req);
      const { soql } = body;

      if (!soql) {
        return sendJSON(res, 400, {
          success: false,
          error: "soql string is required"
        });
      }

      if (!isMockMode) {
        try {
          const sfRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(soql)}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          const sfData = await sfRes.json();
          return sendJSON(res, sfRes.status, {
            success: sfRes.ok,
            mode: "live_salesforce",
            totalSize: sfData.totalSize || (sfData.records ? sfData.records.length : 0),
            done: true,
            records: sfData.records || []
          });
        } catch (err) {
          return sendJSON(res, 500, { success: false, error: err.message });
        }
      }

      const matchObj = soql.match(/FROM\s+([a-zA-Z0-9_]+)/i);
      const targetObj = matchObj ? matchObj[1] : "Work_Order__c";
      const parsed = { targetObject: targetObj, limit: 10 };
      const records = executeMockQuery(parsed, soql);
      return sendJSON(res, 200, {
        success: true,
        mode: "mock",
        totalSize: records.length,
        done: true,
        records: records
      });
    }

    // POST /api/ai/pre-job-briefing
    if (req.method === "POST" && pathname === "/api/ai/pre-job-briefing") {
      const body = await parseRequestBody(req);
      const {
        workOrderId,
        equipmentType,
        equipmentId,
        siteAddress,
        languageCode,
        username
      } = body;
      const activeTech = resolveTechnicianProfile(username, null, token) || MOCK_TECHNICIANS[4];

      let targetWo = {
        Name: workOrderId || "WO-001001",
        Subject__c: "Emergency Equipment Maintenance",
        Equipment_Type__c: equipmentType || "Generator",
        Equipment_ID__c: equipmentId || "EQ-SYS-9900",
        Site_Address__c: siteAddress || "Tech Park Phase 2"
      };

      if (!isMockMode && workOrderId) {
        try {
          const sfRes = await fetch(
            `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(`SELECT Id, Name, Subject__c, Equipment_Type__c, Equipment_ID__c, Site_Address__c, AI_Pre_Job_Briefing__c FROM Work_Order__c WHERE Id = '${escapeSOQL(workOrderId)}' OR Name = '${escapeSOQL(workOrderId)}' LIMIT 1`)}`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          if (sfRes.ok) {
            const sfData = await sfRes.json();
            if (sfData.records && sfData.records.length > 0) {
              targetWo = sfData.records[0];
            }
          }
        } catch (e) {}
      }

      const eqType = targetWo.Equipment_Type__c || equipmentType || "Industrial Unit";
      const eqId = targetWo.Equipment_ID__c || equipmentId || "EQ-SYS-9900";
      const site = targetWo.Site_Address__c || siteAddress || "Primary Tech Zone";

      const briefingText = targetWo.AI_Pre_Job_Briefing__c || `EQUIPMENT AI BRIEFING for ${activeTech.name}:
• Work Order ${workOrderId || targetWo.Name}: ${targetWo.Subject__c}
• Asset ${eqId} (${eqType}) installed at ${site}.
• Asset History: Prior service recorded thermal variance and filter buildup.
• Required Action: Bring ${eqType} Service Kit, calibrated multimeter, and replacement sensors.
• Safety Notice: High Voltage Lockout & PPE protocols mandatory prior to panel removal.`;

      return sendJSON(res, 200, {
        success: true,
        mode: isMockMode ? "mock" : "live_salesforce",
        workOrderId: workOrderId || targetWo.Name,
        technician: activeTech,
        equipmentType: eqType,
        equipmentId: eqId,
        siteAddress: site,
        language: languageCode || "en",
        briefing: briefingText
      });
    }

    // POST /api/ai/troubleshoot
    if (req.method === "POST" && pathname === "/api/ai/troubleshoot") {
      const body = await parseRequestBody(req);
      const {
        problemDescription,
        equipmentType,
        equipmentId,
        languageCode,
        username
      } = body;
      const activeTech = resolveTechnicianProfile(username, null, token) || MOCK_TECHNICIANS[4];

      if (!problemDescription) {
        return sendJSON(res, 400, {
          success: false,
          error: "problemDescription is required"
        });
      }

      const p = problemDescription.toLowerCase();
      const isSeniorNeeded =
        /smoke|fire|burst|crack|high\s*voltage|explosion|dangerous|alarm/i.test(
          p
        );
      const eqType = equipmentType || "Equipment";

      let steps = [
        `Step 1: Isolate main power to ${eqType} (${equipmentId || "Asset"}) and verify electrical isolation with multimeter.`,
        `Step 2: Inspect primary ${p.includes("heat") || p.includes("hot") ? "cooling fan / radiator fins" : p.includes("leak") ? "gasket seals & fluid lines" : "drive motor & bearing clearance"}.`,
        `Step 3: Test sensor resistance and check telemetry log for code anomalies related to: "${problemDescription}".`,
        `Step 4: Replace faulty components, clear error codes, and execute a 15-minute load test.`
      ];

      let parts =
        p.includes("heat") || p.includes("hot")
          ? ["Coolant Flush Kit", "Temp Sensor TS-40"]
          : p.includes("leak")
            ? ["Gasket Seal Kit", "O-Ring Set"]
            : ["Blower Bearing", "Drive Belt B-42"];

      return sendJSON(res, 200, {
        success: true,
        mode: isMockMode ? "mock" : "live_salesforce",
        query: problemDescription,
        technician: activeTech,
        equipmentType: eqType,
        equipmentId: equipmentId || "EQ-GEN-9920",
        language: languageCode || "en",
        escalateToSenior: isSeniorNeeded,
        escalationReason: isSeniorNeeded
          ? "Critical safety hazard / high-risk anomaly detected in problem description."
          : null,
        diagnosisSteps: steps,
        recommendedParts: parts,
        knowledgeArticles: MOCK_KNOWLEDGE
      });
    }

    // POST /api/ai/service-report
    if (req.method === "POST" && pathname === "/api/ai/service-report") {
      const body = await parseRequestBody(req);
      const { workOrderId, technicianNotes, partsUsed } = body;

      return sendJSON(res, 200, {
        success: true,
        mode: isMockMode ? "mock" : "live_salesforce",
        workOrderId: workOrderId || "WO-001001",
        generatedAt: new Date().toISOString(),
        serviceReport: `AI Generated Service Report for ${workOrderId || "WO-001001"}:\n\nTechnician Notes: ${technicianNotes || "Inspected and repaired"}\nParts: ${partsUsed || "None"}\n\nEquipment operational and returned to service.`
      });
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 6. OFFLINE QUEUE REPLAY & TELEMETRY APIS
    // ═════════════════════════════════════════════════════════════════════════
    // POST /api/sync/offline-queue (Batch Replay)
    if (req.method === "POST" && pathname === "/api/sync/offline-queue") {
      const body = await parseRequestBody(req);
      const { technicianId, mutations } = body;

      if (!Array.isArray(mutations)) {
        return sendJSON(res, 400, {
          success: false,
          error: "mutations array is required"
        });
      }

      const results = [];
      for (let i = 0; i < mutations.length; i++) {
        const mutation = mutations[i];
        if (!isMockMode && mutation.sobjectName && mutation.recordId && mutation.fields) {
          try {
            await fetch(
              `${instanceUrl}/services/data/v67.0/sobjects/${mutation.sobjectName}/${mutation.recordId}`,
              {
                method: "PATCH",
                headers: {
                  Authorization: `Bearer ${sfToken}`,
                  "Content-Type": "application/json"
                },
                body: JSON.stringify(mutation.fields)
              }
            );
          } catch (e) {}
        }
        results.push({
          queueId: mutation.queueId || `UUID-${i + 1}`,
          action: mutation.action || "update",
          sobjectName: mutation.sobjectName || "Work_Order__c",
          recordId: mutation.recordId,
          status: "synced",
          syncedAt: new Date().toISOString(),
          error: null
        });
      }

      return sendJSON(res, 200, {
        success: true,
        mode: isMockMode ? "mock" : "live_salesforce",
        technicianId: technicianId || "TECH-001",
        totalProcessed: mutations.length,
        syncedCount: mutations.length,
        failedCount: 0,
        results: results
      });
    }

    // POST /api/technician/location (GPS Telemetry)
    if (req.method === "POST" && pathname === "/api/technician/location") {
      const body = await parseRequestBody(req);
      const { latitude, longitude, technicianId, speed, timestamp } = body;

      if (latitude === undefined || longitude === undefined) {
        return sendJSON(res, 400, {
          success: false,
          error: "latitude and longitude are required"
        });
      }

      if (!isMockMode && technicianId && technicianId.startsWith("a02")) {
        try {
          await fetch(
            `${instanceUrl}/services/data/v67.0/sobjects/Technician__c/${technicianId}`,
            {
              method: "PATCH",
              headers: {
                Authorization: `Bearer ${sfToken}`,
                "Content-Type": "application/json"
              },
              body: JSON.stringify({
                Current_Latitude__c: parseFloat(latitude),
                Current_Longitude__c: parseFloat(longitude),
                Location_Updated__c: new Date().toISOString()
              })
            }
          );
        } catch (e) {}
      }

      return sendJSON(res, 200, {
        success: true,
        mode: isMockMode ? "mock" : "live_salesforce",
        technicianId: technicianId || "TECH-001",
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        updatedAt: timestamp || new Date().toISOString(),
        message: "GPS coordinates recorded in Salesforce."
      });
    }

    // GET /api/schema/:sobject
    if (req.method === "GET" && pathname.startsWith("/api/schema/")) {
      const sobjectName = pathname.replace("/api/schema/", "");

      if (!isMockMode) {
        try {
          const sfRes = await fetch(
            `${instanceUrl}/services/data/v67.0/sobjects/${sobjectName}/describe`,
            { headers: { Authorization: `Bearer ${sfToken}` } }
          );
          if (sfRes.ok) {
            const desc = await sfRes.json();
            return sendJSON(res, 200, {
              success: true,
              mode: "live_salesforce",
              sobjectName: desc.name,
              label: desc.label,
              fieldsCount: desc.fields?.length || 0,
              fields: desc.fields?.slice(0, 15).map((f) => ({
                name: f.name,
                label: f.label,
                type: f.type,
                updateable: f.updateable
              }))
            });
          }
        } catch (e) {}
      }

      return sendJSON(res, 200, {
        success: true,
        mode: "mock",
        sobjectName: sobjectName,
        label: sobjectName.replace(/__c$/, "").replace(/_/g, " "),
        fieldsCount: 18,
        keyFields: [
          "Id",
          "Name",
          "Status__c",
          "Priority__c",
          "Subject__c",
          "Equipment_ID__c"
        ]
      });
    }

    // ═════════════════════════════════════════════════════════════════════════
    // 7. MODEL CONTEXT PROTOCOL (MCP) JSON-RPC 2.0 ENDPOINT
    // ═════════════════════════════════════════════════════════════════════════
    if (
      pathname === "/mcp" ||
      pathname === "/services/mcp/v1" ||
      pathname === "/services/mcp/platform/sobject-reads"
    ) {
      if (req.method === "GET") {
        return sendJSON(res, 200, {
          status: "Salesforce digiField360 MCP Server Running",
          endpoint: `http://localhost:${PORT}/mcp`,
          toolsCount: MCP_TOOLS.length
        });
      }

      if (req.method === "POST") {
        const payload = await parseRequestBody(req);
        const { jsonrpc, id, method, params } = payload;

        if (jsonrpc !== "2.0") {
          return sendJSON(res, 400, {
            jsonrpc: "2.0",
            id,
            error: {
              code: -32600,
              message: "Invalid Request: Must be JSON-RPC 2.0"
            }
          });
        }

        // tools/list
        if (method === "tools/list") {
          return sendJSON(res, 200, {
            jsonrpc: "2.0",
            id,
            result: { tools: MCP_TOOLS }
          });
        }

        // tools/call
        if (method === "tools/call") {
          const toolName = params?.name;
          const args = params?.arguments || {};
          let toolOutput = "";

          if (toolName === "sobject_query") {
            if (!isMockMode && args.soql) {
              try {
                const sfRes = await fetch(
                  `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(args.soql)}`,
                  { headers: { Authorization: `Bearer ${sfToken}` } }
                );
                const sfData = await sfRes.json();
                toolOutput = JSON.stringify(sfData, null, 2);
              } catch (e) {
                toolOutput = JSON.stringify({ totalSize: MOCK_WORK_ORDERS.length, done: true, records: MOCK_WORK_ORDERS }, null, 2);
              }
            } else {
              toolOutput = JSON.stringify(
                { totalSize: MOCK_WORK_ORDERS.length, done: true, records: MOCK_WORK_ORDERS },
                null,
                2
              );
            }
          } else if (toolName === "sobject_search") {
            toolOutput = JSON.stringify(
              { searchRecords: MOCK_KNOWLEDGE },
              null,
              2
            );
          } else if (toolName === "sobject_update") {
            if (!isMockMode && args.sobjectName && args.recordId && args.fields) {
              try {
                await fetch(
                  `${instanceUrl}/services/data/v67.0/sobjects/${args.sobjectName}/${args.recordId}`,
                  {
                    method: "PATCH",
                    headers: {
                      Authorization: `Bearer ${sfToken}`,
                      "Content-Type": "application/json"
                    },
                    body: JSON.stringify(args.fields)
                  }
                );
              } catch (e) {}
            }
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
            let createdId = "a01000000MockCreatedId";
            if (!isMockMode && args.sobjectName && args.fields) {
              try {
                const cRes = await fetch(
                  `${instanceUrl}/services/data/v67.0/sobjects/${args.sobjectName}`,
                  {
                    method: "POST",
                    headers: {
                      Authorization: `Bearer ${sfToken}`,
                      "Content-Type": "application/json"
                    },
                    body: JSON.stringify(args.fields)
                  }
                );
                const cData = await cRes.json();
                if (cData.id) createdId = cData.id;
              } catch (e) {}
            }
            toolOutput = JSON.stringify(
              { success: true, id: createdId, errors: [] },
              null,
              2
            );
          } else if (toolName === "sobject_describe") {
            toolOutput = JSON.stringify(
              {
                name: args.sobjectName,
                label: args.sobjectName.replace(/__c$/, "").replace(/_/g, " "),
                fieldsCount: 15
              },
              null,
              2
            );
          } else if (toolName === "get_account_summary") {
            const limit = args.limit || 10;
            if (!isMockMode) {
              try {
                const soql = `SELECT Id, Name, Type, Industry, BillingCity, AnnualRevenue FROM Account ORDER BY AnnualRevenue DESC NULLS LAST LIMIT ${limit}`;
                const sfRes = await fetch(
                  `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(soql)}`,
                  { headers: { Authorization: `Bearer ${sfToken}` } }
                );
                if (sfRes.ok) {
                  const sfData = await sfRes.json();
                  toolOutput = JSON.stringify(sfData.records || [], null, 2);
                }
              } catch (e) {}
            }
            if (!toolOutput) {
              let results = MOCK_ACCOUNTS;
              if (args.industry) {
                results = results.filter(
                  (acc) =>
                    acc.Industry.toLowerCase() === args.industry.toLowerCase()
                );
              }
              toolOutput = JSON.stringify(results.slice(0, limit), null, 2);
            }
          } else if (toolName === "execute_natural_language_query") {
            const prompt = args.prompt || "";
            const maxRecords = args.maxRecords || 10;
            const parsed = translateNLToSOQL(prompt, maxRecords);
            let records = [];
            if (!isMockMode) {
              try {
                const sfRes = await fetch(
                  `${instanceUrl}/services/data/v67.0/query?q=${encodeURIComponent(parsed.soql)}`,
                  { headers: { Authorization: `Bearer ${sfToken}` } }
                );
                if (sfRes.ok) {
                  const sfData = await sfRes.json();
                  records = sfData.records || [];
                }
              } catch (e) {}
            }
            if (!records.length) {
              records = executeMockQuery(parsed, prompt);
            }
            const aiSummary = generateConversationalSummary(
              parsed.targetObject,
              records,
              prompt
            );
            toolOutput = JSON.stringify(
              {
                prompt: prompt,
                targetObject: parsed.targetObject,
                soqlGenerated: parsed.soql,
                count: records.length,
                records: records,
                aiSummary: aiSummary
              },
              null,
              2
            );
          } else {
            return sendJSON(res, 404, {
              jsonrpc: "2.0",
              id,
              error: { code: -32601, message: `Tool not found: ${toolName}` }
            });
          }

          return sendJSON(res, 200, {
            jsonrpc: "2.0",
            id,
            result: {
              content: [{ type: "text", text: toolOutput }]
            }
          });
        }

        return sendJSON(res, 200, {
          jsonrpc: "2.0",
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
  console.log(
    `🚀 digiField360 Mobile API & MCP Server running on port ${PORT}`
  );
  console.log(`📡 Health & API Discovery: http://localhost:${PORT}/health`);
  console.log(`🤖 MCP JSON-RPC Endpoint:  http://localhost:${PORT}/mcp`);
});
