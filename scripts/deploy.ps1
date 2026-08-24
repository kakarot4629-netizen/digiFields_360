# DigiField360 AI — PowerShell Deployment Script
# Run from the project root: .\scripts\deploy.ps1
# Prerequisite: sf CLI authenticated as field360-dev
# See README.md Section 2 for full prerequisites.

param(
    [string]$OrgAlias = "field360-dev",
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

function Write-Step($n, $msg) {
    Write-Host "`n[$n] $msg" -ForegroundColor Cyan
}

function Write-OK($msg) {
    Write-Host "  ✓ $msg" -ForegroundColor Green
}

function Write-Warn($msg) {
    Write-Host "  ⚠ $msg" -ForegroundColor Yellow
}

function Invoke-Deploy($dir, $label) {
    Write-Step "" "Deploying: $label"
    sf project deploy start `
        --source-dir "force-app/main/default/$dir" `
        --target-org $OrgAlias `
        --wait 30
    if ($LASTEXITCODE -ne 0) {
        throw "Deploy failed for: $label"
    }
    Write-OK "$label deployed successfully"
}

Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║   digiField360 AI — Deployment Script v1.0      ║" -ForegroundColor Blue
Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Blue

# Verify org is authenticated
Write-Step "0" "Verifying org authentication"
sf org display --target-org $OrgAlias | Out-Null
Write-OK "Org $OrgAlias is authenticated"

# Step 1 — Custom Objects (must be first — Apex depends on them)
Invoke-Deploy "objects" "Custom Objects (F360__Work_Order__c, F360__Technician__c, F360__Job_History__c, F360__Maintenance_Alert__c, User fields)"

Write-Warn "Manual step required: Create 7 User custom fields in Setup > Object Manager > User > Fields if not already done."
Write-Warn "The script continues but Apex will fail to compile if User fields are missing."
Start-Sleep -Seconds 3

# Step 2 — Apex Classes
Invoke-Deploy "classes" "Apex Classes (all F360_ action classes + controller)"

# Step 3 — GenAI Prompt Templates
Invoke-Deploy "genAiPromptTemplates" "GenAI Prompt Templates"

Write-Warn "Manual step required: After this deploy, go to Setup > Prompt Builder and PUBLISH each of the 4 F360_ templates."
Write-Warn "Flows and Agentforce will fail at runtime if templates remain in Draft status."

# Step 4 — Lightning Web Components
Invoke-Deploy "lwc" "Lightning Web Components (field360WorkOrderDetail, field360DispatchBoard)"

# Step 5 — Flows
Invoke-Deploy "flows" "Flows (WO Assigned Briefing, WO Completed Report, Nightly Maintenance)"

# Step 6 — Permission Sets
Invoke-Deploy "permissionsets" "Permission Sets (Core, AI Actions, Dispatch, Knowledge)"

# Step 7 — Run tests (unless skipped)
if (-not $SkipTests) {
    Write-Step "7" "Running Apex test classes"
    sf apex run test `
        --test-level RunLocalTests `
        --target-org $OrgAlias `
        --wait 20 `
        --result-format human
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Some tests failed. Review output above. Coverage must be >= 80% on all F360_ classes."
    } else {
        Write-OK "All tests passed"
    }
} else {
    Write-Warn "Tests skipped (--SkipTests flag set)"
}

# Step 8 — Load test data (optional)
Write-Step "8" "Loading sample test data"
$dataFile = "test-data/field360-plan.json"
if (Test-Path $dataFile) {
    sf data import tree --plan $dataFile --target-org $OrgAlias
    Write-OK "Test data loaded"
} else {
    Write-Warn "Test data file not found: $dataFile — skipping"
}

Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   Deployment Complete!                           ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "`nRemaining manual steps:" -ForegroundColor Yellow
Write-Host "  1. Publish 4 Prompt Templates in Setup > Prompt Builder" -ForegroundColor Yellow
Write-Host "  2. Create Agentforce agent (Setup > Agentforce > Agents > New)" -ForegroundColor Yellow
Write-Host "  3. Configure agent topics and actions in Agentforce Builder" -ForegroundColor Yellow
Write-Host "  4. Set agent guardrails in Agentforce Builder" -ForegroundColor Yellow
Write-Host "  5. Activate the agent" -ForegroundColor Yellow
Write-Host "  6. Create Custom Notification Type 'F360_Maintenance_Alert_Notification'" -ForegroundColor Yellow
Write-Host "  7. Add LWC components to Lightning App Builder pages" -ForegroundColor Yellow
Write-Host "  8. Assign permission sets to users" -ForegroundColor Yellow
Write-Host "`nSee README.md Section 9 and 10 for the full post-deployment checklist.`n"
