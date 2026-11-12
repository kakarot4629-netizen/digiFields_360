public with sharing class DF360_GuruAIController {

    @AuraEnabled
    public static String askGuruAI(Id technicianId, Id jobId, String message) {
        if (String.isBlank(message)) {
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => 'Please provide a technical question or error description.'
            });
        }

        String lowerMsg = message.toLowerCase().trim();

        // 1. Gather Context from Work_Order__c or Service_Job__c
        String equipName = 'Industrial Equipment';
        String equipModel = 'Standard Model';
        String equipCategory = 'Mechanical / Electrical';
        String customerName = 'Customer Site';
        String serialNumber = 'SN-UNKNOWN';
        Boolean isUnderWarranty = true;

        if (jobId != null) {
            try {
                // Check Work_Order__c first
                List<Work_Order__c> wos = [
                    SELECT Id, Name, Subject__c, Equipment_Type__c, Equipment_ID__c,
                           Account__r.Name, Asset__r.Name, Asset__r.Model__c,
                           Asset__r.Product_Category__c, Asset__r.Serial_Number__c,
                           Asset__r.Is_Under_Warranty__c
                    FROM Work_Order__c
                    WHERE Id = :jobId
                    LIMIT 1
                ];
                if (!wos.isEmpty()) {
                    Work_Order__c wo = wos[0];
                    if (wo.Asset__c != null) {
                        equipName = String.isNotBlank(wo.Asset__r.Name) ? wo.Asset__r.Name : equipName;
                        equipModel = String.isNotBlank(wo.Asset__r.Model__c) ? wo.Asset__r.Model__c : equipModel;
                        equipCategory = String.isNotBlank(wo.Asset__r.Product_Category__c) ? wo.Asset__r.Product_Category__c : equipCategory;
                        serialNumber = String.isNotBlank(wo.Asset__r.Serial_Number__c) ? wo.Asset__r.Serial_Number__c : serialNumber;
                        isUnderWarranty = wo.Asset__r.Is_Under_Warranty__c == true;
                    } else if (String.isNotBlank(wo.Equipment_Type__c)) {
                        equipCategory = wo.Equipment_Type__c;
                        equipName = wo.Equipment_Type__c;
                    }
                    if (wo.Account__r != null) {
                        customerName = wo.Account__r.Name;
                    }
                } else {
                    // Check Service_Job__c
                    List<Service_Job__c> jobs = [
                        SELECT Id, Name, Job_Type__c, Product_Category__c,
                               Asset__r.Product_Name__c, Asset__r.Serial_Number__c,
                               Asset__r.Model__c, Asset__r.Is_Under_Warranty__c,
                               Account__r.Name
                        FROM Service_Job__c
                        WHERE Id = :jobId
                        LIMIT 1
                    ];
                    if (!jobs.isEmpty()) {
                        Service_Job__c sj = jobs[0];
                        if (sj.Asset__c != null) {
                            equipName = sj.Asset__r.Product_Name__c;
                            serialNumber = sj.Asset__r.Serial_Number__c;
                            equipModel = sj.Asset__r.Model__c;
                            isUnderWarranty = sj.Asset__r.Is_Under_Warranty__c == true;
                        }
                        if (sj.Account__r != null) customerName = sj.Account__r.Name;
                    }
                }
            } catch (Exception ex) {
                System.debug('Context query exception: ' + ex.getMessage());
            }
        }

        // Build Structured Response Object
        Map<String, Object> responseEnvelope = new Map<String, Object>{
            'success' => true,
            'query' => message,
            'equipment' => equipName,
            'model' => equipModel,
            'serialNumber' => serialNumber,
            'isWarranty' => isUnderWarranty,
            'customer' => customerName
        };

        // Scenario 1: Coolant Pump / Water Pump / Generator
        if (lowerMsg.contains('coolant') || lowerMsg.contains('water pump') || lowerMsg.contains('cummins') || lowerMsg.contains('generator')) {
            responseEnvelope.put('intent', 'COMPONENT_REPLACEMENT_SOP');
            responseEnvelope.put('title', 'Cummins 250kVA Generator — Coolant Pump Replacement SOP');
            responseEnvelope.put('severity', 'WARNING');
            responseEnvelope.put('summary', 'Step-by-step diagnostic and replacement procedure for water/coolant pump assembly on Cummins 250kVA diesel generator.');
            
            responseEnvelope.put('safetyPrecautions', new List<String>{
                'Turn control panel to OFF, disconnect battery negative terminal (-), and lockout main breaker.',
                'Ensure engine jacket water temperature is below 40°C before opening cooling lines.'
            });

            responseEnvelope.put('actionableSteps', new List<Map<String, Object>>{
                new Map<String, Object>{ 'step' => 1, 'action' => 'Drain Coolant', 'details' => 'Position 50L container under radiator drain valve and drain completely.' },
                new Map<String, Object>{ 'step' => 2, 'action' => 'Release Serpentine Belt', 'details' => 'Relieve belt tensioner with 1/2" breaker bar and remove belt.' },
                new Map<String, Object>{ 'step' => 3, 'action' => 'Disassemble Water Pump', 'details' => 'Remove 6x M10 water pump body bolts in alternating cross pattern.' },
                new Map<String, Object>{ 'step' => 4, 'action' => 'Mount New Pump & Torque', 'details' => 'Clean face with Scotch-Brite, fit new O-ring gasket, torque to 45 Nm (33 lb-ft).' },
                new Map<String, Object>{ 'step' => 5, 'action' => 'Refill & Bleed', 'details' => 'Refill 50/50 OAT Ethylene Glycol and bleed air from top thermostat bleeder valve.' }
            });

            responseEnvelope.put('recommendedParts', new List<Map<String, Object>>{
                new Map<String, Object>{ 'partCode' => 'CV-KIT-01', 'name' => 'Coolant Pump Gasket Kit', 'unitCost' => 6800, 'category' => 'Mechanical', 'inStock' => true },
                new Map<String, Object>{ 'partCode' => 'AF-500K', 'name' => 'Air & Coolant Filter Cartridge', 'unitCost' => 1250, 'category' => 'Filtration', 'inStock' => true }
            });

            responseEnvelope.put('quickActions', new List<Map<String, Object>>{
                new Map<String, Object>{ 'action' => 'request_parts', 'label' => 'Request Gasket Kit (CV-KIT-01)' },
                new Map<String, Object>{ 'action' => 'pause_wo', 'label' => 'Pause: Waiting for Part' }
            });

            return JSON.serialize(responseEnvelope);
        }

        // Scenario 2: Error E-401 / High Head Pressure / Chiller / HVAC
        if (lowerMsg.contains('e-401') || lowerMsg.contains('e401') || lowerMsg.contains('chiller') || lowerMsg.contains('hvac') || lowerMsg.contains('high pressure')) {
            responseEnvelope.put('intent', 'ERROR_CODE_TROUBLESHOOTING');
            responseEnvelope.put('title', 'HVAC Chiller Unit — Error Code E-401 (High Head Pressure Cutout)');
            responseEnvelope.put('severity', 'HIGH');
            responseEnvelope.put('summary', 'Error E-401 triggers when discharge pressure exceeds 375 PSI (R-410A), tripping the safety High-Pressure Switch.');

            responseEnvelope.put('safetyPrecautions', new List<String>{
                'Discharge lines can exceed 85°C. Allow 15 minutes cooldown before attaching manifold gauges.',
                'Wear protective eyewear and insulated HVAC service gloves.'
            });

            responseEnvelope.put('actionableSteps', new List<Map<String, Object>>{
                new Map<String, Object>{ 'step' => 1, 'action' => 'Inspect Condenser Coils', 'details' => 'Check for dust/debris blockages. Flush with pressurized water & coil cleaner if fouled.' },
                new Map<String, Object>{ 'step' => 2, 'action' => 'Verify Condenser Fan Relay', 'details' => 'Inspect 24V Control Relay (RC-24V) and measure coil voltage across terminals A1-A2.' },
                new Map<String, Object>{ 'step' => 3, 'action' => 'Measure Pressures', 'details' => 'Attach digital manifold. If High Side is >380 PSI and Low Side is 118 PSI, check for non-condensable gas.' },
                new Map<String, Object>{ 'step' => 4, 'action' => 'Reset Alarm & Test', 'details' => 'Press red manual HP switch button, clear alarm on DDC, run under 80% load for 20 min.' }
            });

            responseEnvelope.put('recommendedParts', new List<Map<String, Object>>{
                new Map<String, Object>{ 'partCode' => 'RC-24V', 'name' => '24V Control Relay', 'unitCost' => 850, 'category' => 'Electrical', 'inStock' => true },
                new Map<String, Object>{ 'partCode' => 'CV-KIT-01', 'name' => 'HVAC Compressor Gasket Kit', 'unitCost' => 6800, 'category' => 'Mechanical', 'inStock' => true }
            });

            responseEnvelope.put('quickActions', new List<Map<String, Object>>{
                new Map<String, Object>{ 'action' => 'request_parts', 'label' => 'Request 24V Relay (RC-24V)' },
                new Map<String, Object>{ 'action' => 'pause_wo', 'label' => 'Pause: Waiting for Part' },
                new Map<String, Object>{ 'action' => 'escalate', 'label' => 'Escalate to Senior Engineer' }
            });

            return JSON.serialize(responseEnvelope);
        }

        // Scenario 3: Parts & Maintenance Lookup
        if (lowerMsg.contains('filter') || lowerMsg.contains('gasket') || lowerMsg.contains('part number') || lowerMsg.contains('oil')) {
            responseEnvelope.put('intent', 'PARTS_CATALOGUE_LOOKUP');
            responseEnvelope.put('title', 'Approved Spare Parts & Periodic Maintenance Guide');
            responseEnvelope.put('severity', 'INFO');
            responseEnvelope.put('summary', 'Approved inventory items for 250-hour servicing matching your equipment specifications.');

            responseEnvelope.put('safetyPrecautions', new List<String>{
                'Ensure machine is completely depressurized before replacing filter elements.'
            });

            responseEnvelope.put('actionableSteps', new List<Map<String, Object>>{
                new Map<String, Object>{ 'step' => 1, 'action' => 'Lube O-Ring', 'details' => 'Pre-lube oil filter O-ring with 15W-40 clean engine oil.' },
                new Map<String, Object>{ 'step' => 2, 'action' => 'Hand Tighten', 'details' => 'Spin filter until gasket contacts base, then tighten 3/4 turn by hand.' },
                new Map<String, Object>{ 'step' => 3, 'action' => 'Torque Drain Plug', 'details' => 'Torque oil sump drain plug to 75 Nm with new copper crush washer.' }
            });

            responseEnvelope.put('recommendedParts', new List<Map<String, Object>>{
                new Map<String, Object>{ 'partCode' => 'AF-500K', 'name' => 'Mechanical Air & Fluid Filter', 'unitCost' => 1250, 'category' => 'Filtration', 'inStock' => true },
                new Map<String, Object>{ 'partCode' => 'CV-KIT-01', 'name' => 'HVAC Compressor Gasket Kit', 'unitCost' => 6800, 'category' => 'Mechanical', 'inStock' => true },
                new Map<String, Object>{ 'partCode' => 'RC-24V', 'name' => 'Electrical 24V Control Relay', 'unitCost' => 850, 'category' => 'Electrical', 'inStock' => true }
            });

            responseEnvelope.put('quickActions', new List<Map<String, Object>>{
                new Map<String, Object>{ 'action' => 'request_parts', 'label' => 'Open Relevant Parts Catalog' }
            });

            return JSON.serialize(responseEnvelope);
        }

        // Default Intelligent Fallback
        responseEnvelope.put('intent', 'GENERAL_ASSISTANCE');
        responseEnvelope.put('title', 'GuruAI Field Diagnostic Guidance');
        responseEnvelope.put('severity', 'INFO');
        responseEnvelope.put('summary', 'Standard diagnostic procedure for: ' + message);

        responseEnvelope.put('safetyPrecautions', new List<String>{
            'Isolate primary electrical supply (LOTO) and verify 0V before mechanical inspection.'
        });

        responseEnvelope.put('actionableSteps', new List<Map<String, Object>>{
            new Map<String, Object>{ 'step' => 1, 'action' => 'Isolate & Lockout', 'details' => 'Apply LOTO padlocks to main supply breaker and test zero energy state.' },
            new Map<String, Object>{ 'step' => 2, 'action' => 'Visual Inspection', 'details' => 'Inspect wiring harness, contactors, and control board LED status indicators.' },
            new Map<String, Object>{ 'step' => 3, 'action' => 'Measure Parameters', 'details' => 'Verify 3-phase line voltages (415V ± 5%) and operating pressure limits.' }
        });

        responseEnvelope.put('recommendedParts', new List<Map<String, Object>>{
            new Map<String, Object>{ 'partCode' => 'RC-24V', 'name' => 'Control Relay 24V', 'unitCost' => 850, 'category' => 'Electrical', 'inStock' => true }
        });

        responseEnvelope.put('quickActions', new List<Map<String, Object>>{
            new Map<String, Object>{ 'action' => 'request_parts', 'label' => 'Browse Relevant Parts' },
            new Map<String, Object>{ 'action' => 'pause_wo', 'label' => 'Pause Work Order' }
        });

        return JSON.serialize(responseEnvelope);
    }
}
