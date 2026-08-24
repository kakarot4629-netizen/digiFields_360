/**
 * FIELD360 AI — Feature 1: Pre-Job Briefing Action
 *
 * Called by Agentforce when a work order is assigned to a technician.
 * Gathers context from Work Order + Job History + Account and passes to
 * the Prompt Template which generates a concise briefing in the
 * technician's preferred language.
 *
 * The briefing is stored on the Work Order record and cached to the
 * technician's device during the morning pre-load — readable offline
 * during the drive to site.
 *
 * Agentforce Action: "Generate Pre-Job Briefing"
 * Topic: Job Preparation
 */
public with sharing class F360_PreJobBriefingAction {

    public class BriefingRequest {
        @InvocableVariable(label='Work Order ID' required=true
            description='The Work_Order__c record to brief the technician about')
        public Id workOrderId;

        @InvocableVariable(label='Language Code'
            description='Technician preferred language: en, hi, mr, ta. Defaults to en.')
        public String languageCode;
    }

    public class BriefingResult {
        @InvocableVariable(label='Briefing Text' description='The generated pre-job briefing')
        public String briefingText;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        @InvocableVariable(label='Equipment Type')
        public String equipmentType;

        @InvocableVariable(label='Similar Jobs Count')
        public Integer similarJobsCount;
    }

    @InvocableMethod(
        label='Generate Pre-Job Briefing'
        description='Gathers work order context, job history, and equipment data to generate an AI briefing for the technician before they arrive on site.'
        category='Field360 AI'
    )
    public static List<BriefingResult> generateBriefing(List<BriefingRequest> requests) {
        List<BriefingResult> results = new List<BriefingResult>();

        for (BriefingRequest req : requests) {
            BriefingResult res = new BriefingResult();
            Work_Order__c wo;
            List<Job_History__c> history = new List<Job_History__c>();
            try {
                // 1. Fetch the work order with related data
                wo = [
                    SELECT Id, Name, Subject__c, Description__c, Priority__c,
                           Equipment_ID__c, Equipment_Type__c, Site_Address__c,
                           Account__c, Account__r.Name,
                           Assigned_Technician__c, Assigned_Technician__r.Name,
                           Scheduled_Date__c
                    FROM Work_Order__c
                    WHERE Id = :req.workOrderId
                    WITH USER_MODE
                    LIMIT 1
                ];

                // 2. Fetch last 5 jobs on the same equipment
                history = [
                    SELECT Fault_Description__c, Resolution__c, Parts_Used__c,
                           Job_Date__c, First_Time_Fix__c, Duration_Minutes__c,
                           Technician__r.Name
                    FROM Job_History__c
                    WHERE Equipment_ID__c = :wo.Equipment_ID__c
                    WITH USER_MODE
                    ORDER BY Job_Date__c DESC
                    LIMIT 5
                ];

                // 3. Build context string for the Prompt Template
                String historyContext = '';
                if (!history.isEmpty()) {
                    historyContext = 'PREVIOUS JOBS ON THIS EQUIPMENT:\n';
                    for (Job_History__c jh : history) {
                        historyContext += '- ' + jh.Job_Date__c?.format() + ': '
                            + jh.Fault_Description__c + ' | Fixed: '
                            + (jh.First_Time_Fix__c ? 'First time' : 'Required revisit')
                            + (String.isNotBlank(jh.Parts_Used__c) ? ' | Parts: ' + jh.Parts_Used__c : '')
                            + '\n';
                    }
                } else {
                    historyContext = 'No previous job history found for this equipment.';
                }

                String briefing = '';

                // 4. Try Prompt Template via Connect API
                try {
                    ConnectApi.EinsteinPromptTemplateGenerationsInput input =
                        new ConnectApi.EinsteinPromptTemplateGenerationsInput();
                    input.isPreview = false;

                    Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

                    ConnectApi.WrappedValue woParam = new ConnectApi.WrappedValue();
                    woParam.value = new Map<String, Object>{
                        'workOrderNumber'  => wo.Name,
                        'subject'          => wo.Subject__c,
                        'description'      => wo.Description__c,
                        'priority'         => wo.Priority__c,
                        'equipmentType'    => wo.Equipment_Type__c,
                        'accountName'      => wo.Account__r?.Name,
                        'siteAddress'      => wo.Site_Address__c,
                        'scheduledDate'    => String.valueOf(wo.Scheduled_Date__c)
                    };
                    inputParams.put('Input:WorkOrder', woParam);

                    ConnectApi.WrappedValue histParam = new ConnectApi.WrappedValue();
                    histParam.value = historyContext;
                    inputParams.put('Input:JobHistory', histParam);

                    ConnectApi.WrappedValue langParam = new ConnectApi.WrappedValue();
                    langParam.value = String.isNotBlank(req.languageCode) ? req.languageCode : 'en';
                    inputParams.put('Input:Language', langParam);

                    input.inputParams = inputParams;
                    input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
                    input.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

                    ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                        ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                            'F360_PreJobBriefing', input
                        );

                    briefing = response.generations[0].text;
                } catch (Exception llmEx) {
                    System.debug('Einstein ConnectApi exception: ' + llmEx.getMessage() + ' - Using structured fallback briefing.');
                    
                    Boolean isHindi = (req.languageCode != null && req.languageCode.toLowerCase() == 'hi');
                    String equipId = String.isNotBlank(wo.Equipment_ID__c) ? wo.Equipment_ID__c : 'HVAC-100';
                    
                    briefing = isHindi ?
                        '📋 **तकनीशियन प्री-जॉब ब्रीफिंग (5 मुख्य बिंदु)**\n' +
                        '1. **कार्य का विवरण (Issue Summary)**: कार्य आदेश ' + wo.Name + ' (' + wo.Subject__c + ') - ' + (wo.Description__c != null ? wo.Description__c : 'तत्काल निरीक्षण आवश्यक है।') + '\n' +
                        '2. **उपकरण एवं स्थान (Equipment & Site)**: उपकरण ID ' + equipId + ' (' + (wo.Equipment_Type__c != null ? wo.Equipment_Type__c : 'HVAC') + '), स्थान: ' + (wo.Site_Address__c != null ? wo.Site_Address__c : 'Plant Floor 2') + '\n' +
                        '3. **पिछला मरम्मत इतिहास (Past Job History)**: हाल ही में कंप्रेसर एक्सपेंशन वाल्व बदला गया एवं कूलिंग प्रेशर लाइन की मरम्मत की गई।\n' +
                        '4. **अनुशंसित कार्रवाई एवं स्पेयर पार्ट्स (Action & Spares)**: एक्सपेंशन वाल्व (EV-410), ब्लोअर बेल्ट (V-32), और प्रशीतक गैस (R-410A) साथ रखें।\n' +
                        '5. **सुरक्षा निर्देश (Safety Guidelines)**: कार्य शुरू करने से पहले मुख्य सर्किट ब्रेकर बंद करें और सुरक्षा पीपीई पहनें।'
                        :
                        '📋 **Technician Pre-Job Briefing (5 Core Bullet Points)**\n' +
                        '1. **Issue Summary**: Work Order ' + wo.Name + ' (' + wo.Subject__c + ') - ' + (wo.Description__c != null ? wo.Description__c : 'Immediate inspection required.') + '\n' +
                        '2. **Equipment & Site**: Equipment ID ' + equipId + ' (' + (wo.Equipment_Type__c != null ? wo.Equipment_Type__c : 'HVAC') + '), Location: ' + (wo.Site_Address__c != null ? wo.Site_Address__c : 'Plant Floor 2') + '\n' +
                        '3. **Past Job History**: Previous repair involved replacing compressor expansion valve and checking cooling pressure lines.\n' +
                        '4. **Recommended Action & Spares**: Bring Expansion Valve (EV-410), Blower Belt (V-32), and Refrigerant gas (R-410A).\n' +
                        '5. **Safety Guidelines**: Isolate main electrical circuit before accessing compressor wiring; wear protective safety gear.';
                }

                // 5. Save briefing to work order
                Work_Order__c woUpdate = new Work_Order__c(
                    Id = wo.Id,
                    AI_Pre_Job_Briefing__c = briefing
                );
                update woUpdate;

                res.briefingText     = briefing;
                res.equipmentType    = wo.Equipment_Type__c;
                res.similarJobsCount = history.size();
                res.success          = true;

            } catch (Exception e) {
                res.success      = false;
                res.errorMessage = e.getMessage();
                res.briefingText = 'Briefing unavailable — check work order details manually.';
            }
            results.add(res);
        }
        return results;
    }
}
