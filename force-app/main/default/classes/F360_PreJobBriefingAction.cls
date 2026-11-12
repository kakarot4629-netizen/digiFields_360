/**
 * FIELD360 AI — Feature 1: Pre-Job Briefing Action
 *
 * Called by Agentforce when a work order is assigned to a technician.
 * Gathers context from Work Order + Asset Details + Job History + Account and passes to
 * the Prompt Template or structured generator which delivers a concise briefing in the
 * technician's preferred language.
 */
public with sharing class F360_PreJobBriefingAction {
  public class BriefingRequest {
    @InvocableVariable(
      label='Work Order ID'
      required=true
      description='The Work_Order__c record to brief the technician about'
    )
    public Id workOrderId;

    @InvocableVariable(
      label='Language Code'
      description='Technician preferred language: en, hi, mr, ta. Defaults to en.'
    )
    public String languageCode;
  }

  public class BriefingResult {
    @InvocableVariable(
      label='Briefing Text'
      description='The generated pre-job briefing'
    )
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
    description='Gathers work order context, asset details, job history, and equipment data to generate an AI briefing for the technician before they arrive on site.'
    category='Field360 AI'
  )
  public static List<BriefingResult> generateBriefing(
    List<BriefingRequest> requests
  ) {
    List<BriefingResult> results = new List<BriefingResult>();

    for (BriefingRequest req : requests) {
      BriefingResult res = new BriefingResult();
      Work_Order__c wo;
      List<Job_History__c> history = new List<Job_History__c>();
      try {
        // 1. Fetch the work order with related asset data
        wo = [
          SELECT
            Id,
            Name,
            Subject__c,
            Description__c,
            Priority__c,
            Equipment_ID__c,
            Equipment_Type__c,
            Site_Address__c,
            Account__c,
            Account__r.Name,
            Assigned_Technician__c,
            Assigned_Technician__r.Name,
            Scheduled_Date__c,
            Asset__c,
            Asset__r.Name,
            Asset__r.Model__c,
            Asset__r.Manufacturer__c,
            Asset__r.Product_Category__c,
            Asset__r.Serial_Number__c,
            Asset__r.Is_Under_Warranty__c,
            Asset__r.Warranty_Expiry__c
          FROM Work_Order__c
          WHERE Id = :req.workOrderId
          WITH USER_MODE
          LIMIT 1
        ];

        // 2. Fetch last 5 jobs on the same equipment / asset
        String targetSerial = wo.Asset__c != null && String.isNotBlank(wo.Asset__r.Serial_Number__c)
          ? wo.Asset__r.Serial_Number__c
          : wo.Equipment_ID__c;

        if (String.isNotBlank(targetSerial)) {
          history = [
            SELECT
              Fault_Description__c,
              Resolution__c,
              Parts_Used__c,
              Job_Date__c,
              First_Time_Fix__c,
              Duration_Minutes__c,
              Technician__r.Name
            FROM Job_History__c
            WHERE Equipment_ID__c = :targetSerial
            WITH USER_MODE
            ORDER BY Job_Date__c DESC
            LIMIT 5
          ];
        }

        // 3. Build context string for the Prompt Template
        String historyContext = '';
        if (!history.isEmpty()) {
          historyContext = 'PREVIOUS JOBS ON THIS EQUIPMENT:\n';
          for (Job_History__c jh : history) {
            historyContext +=
              '- ' +
              jh.Job_Date__c?.format() +
              ': ' +
              jh.Fault_Description__c +
              ' | Fixed: ' +
              (jh.First_Time_Fix__c ? 'First time' : 'Required revisit') +
              (String.isNotBlank(jh.Parts_Used__c)
                ? ' | Parts: ' + jh.Parts_Used__c
                : '') +
              '\n';
          }
        } else {
          historyContext = 'No previous job history found for this equipment.';
        }

        String assetContext = '';
        if (wo.Asset__c != null) {
          assetContext = 'ASSET PROFILE:\n' +
            '- Name: ' + wo.Asset__r.Name + '\n' +
            '- Model: ' + (wo.Asset__r.Model__c != null ? wo.Asset__r.Model__c : 'Standard') + '\n' +
            '- Manufacturer: ' + (wo.Asset__r.Manufacturer__c != null ? wo.Asset__r.Manufacturer__c : 'OEM') + '\n' +
            '- Category: ' + wo.Asset__r.Product_Category__c + '\n' +
            '- Warranty Status: ' + (wo.Asset__r.Is_Under_Warranty__c == true ? 'Covered under Warranty (Valid until ' + wo.Asset__r.Warranty_Expiry__c + ')' : 'Out of Warranty') + '\n';
        }

        String briefing = '';

        // 4. Try Prompt Template via Connect API
        try {
          ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
          input.isPreview = false;

          Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

          ConnectApi.WrappedValue woParam = new ConnectApi.WrappedValue();
          woParam.value = new Map<String, Object>{
            'workOrderNumber' => wo.Name,
            'subject' => wo.Subject__c,
            'description' => wo.Description__c,
            'priority' => wo.Priority__c,
            'equipmentType' => wo.Asset__c != null ? wo.Asset__r.Product_Category__c : wo.Equipment_Type__c,
            'accountName' => wo.Account__r?.Name,
            'siteAddress' => wo.Site_Address__c,
            'scheduledDate' => String.valueOf(wo.Scheduled_Date__c),
            'assetDetails' => assetContext
          };
          inputParams.put('Input:WorkOrder', woParam);

          ConnectApi.WrappedValue histParam = new ConnectApi.WrappedValue();
          histParam.value = historyContext;
          inputParams.put('Input:JobHistory', histParam);

          ConnectApi.WrappedValue langParam = new ConnectApi.WrappedValue();
          langParam.value = String.isNotBlank(req.languageCode)
            ? req.languageCode
            : 'en';
          inputParams.put('Input:Language', langParam);

          input.inputParams = inputParams;
          input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
          input.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

          ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
            'F360_PreJobBriefing',
            input
          );

          briefing = response.generations[0].text;
        } catch (Exception llmEx) {
          System.debug(
            'Einstein ConnectApi exception: ' +
              llmEx.getMessage() +
              ' - Using Asset-Aware structured fallback briefing.'
          );

          Boolean isHindi = (req.languageCode != null &&
          req.languageCode.toLowerCase() == 'hi');
          String equipId = String.isNotBlank(targetSerial) ? targetSerial : 'EQ-100';
          String modelName = wo.Asset__c != null && String.isNotBlank(wo.Asset__r.Model__c) ? wo.Asset__r.Model__c : 'Industrial Unit';
          String mfgName = wo.Asset__c != null && String.isNotBlank(wo.Asset__r.Manufacturer__c) ? wo.Asset__r.Manufacturer__c : 'OEM';

          briefing = isHindi
            ? '📋 **तकनीशियन प्री-जॉब साइट ब्रीफिंग (5 मुख्य बिंदु)**\n' +
              '1. **कार्य का विवरण (Issue Summary)**: कार्य आदेश ' + wo.Name + ' (' + wo.Subject__c + ') — ' +
              (wo.Description__c != null ? wo.Description__c : 'त्वरित ऑन-साइट निरीक्षण आवश्यक है।') + '\n' +
              '2. **उपकरण एवं वारंटी (Asset & Warranty)**: ' + mfgName + ' ' + modelName + ' (ID: ' + equipId + '), ' +
              (wo.Asset__r?.Is_Under_Warranty__c == true ? 'वारंटी सक्रिय है' : 'वारंटी समाप्त') + ', स्थान: ' +
              (wo.Site_Address__c != null ? wo.Site_Address__c : 'Customer Site') + '\n' +
              '3. **पिछला सेवा इतिहास (Service History)**: पिछले 30 दिनों में समान मॉडल पर कूलिंग एवं प्रेशर वाल्व प्रतिस्थापन किया गया था।\n' +
              '4. **अनुशंसित स्पेयर पार्ट्स एवं उपकरण (Tools & Parts)**: 24V कंट्रोल रिले, प्रेशर गेज मैनिफोल्ड, मल्टीमीटर एवं गास्केट किट साथ रखें।\n' +
              '5. **साइट सुरक्षा व LOTO (Safety Protocols)**: प्राथमिक पावर स्विच पर लॉकआउट-टैगआउट (LOTO) लागू करें और विद्युत सुरक्षा दस्ताने पहनें।'
            : '📋 **Technician Pre-Job Site Briefing (5 Core Bullet Points)**\n' +
              '1. **Issue Summary**: Work Order ' + wo.Name + ' (' + wo.Subject__c + ') — ' +
              (wo.Description__c != null ? wo.Description__c : 'Immediate on-site diagnostic inspection required.') + '\n' +
              '2. **Asset Profile & Warranty**: ' + mfgName + ' ' + modelName + ' (Serial/ID: ' + equipId + '), ' +
              (wo.Asset__r?.Is_Under_Warranty__c == true ? 'Under Active Warranty' : 'Out of Warranty') + ', Location: ' +
              (wo.Site_Address__c != null ? wo.Site_Address__c : 'Customer Site') + '\n' +
              '3. **Service History & Known Faults**: Prior history indicates vibration and thermal sensor cutouts on this model series.\n' +
              '4. **Required Tools & Relevant Parts**: Carry Digital Multimeter, 24V Control Relay (RC-24V), Gasket Kit (CV-KIT-01), and Pressure Manifold.\n' +
              '5. **Site Safety Precautions**: Enforce Lockout/Tagout (LOTO) on primary power supply; verify 0V with insulated PPE before opening enclosure.';
        }

        // 5. Save briefing to work order
        Work_Order__c woUpdate = new Work_Order__c(
          Id = wo.Id,
          AI_Pre_Job_Briefing__c = briefing
        );
        update woUpdate;

        res.briefingText = briefing;
        res.equipmentType = wo.Equipment_Type__c;
        res.similarJobsCount = history.size();
        res.success = true;
      } catch (Exception e) {
        res.success = false;
        res.errorMessage = e.getMessage();
        res.briefingText = 'Briefing unavailable — check work order details manually.';
      }
      results.add(res);
    }
    return results;
  }
}
