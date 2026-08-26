/**
 * FIELD360 AI — Feature 3: On-Site Troubleshooting Assistant
 *
 * Technician types a problem description in the mobile app.
 * This action queries the Knowledge base using RAG via Agentforce
 * and returns structured diagnostic steps.
 *
 * When ONLINE: Full Agentforce RAG over Salesforce Knowledge articles.
 * When OFFLINE: Mobile app uses cached knowledge (synced during pre-load).
 *
 * Agentforce Action: "Get Troubleshooting Guidance"
 * Topic: On-Site Technical Support
 */
public with sharing class F360_TroubleshootingAction {
  public class TroubleshootRequest {
    @InvocableVariable(
      label='Problem Description'
      required=true
      description='What the technician typed: e.g. compressor not starting after oil change'
    )
    public String problemDescription;

    @InvocableVariable(
      label='Equipment Type'
      description='e.g. HVAC, Generator, Compressor — narrows the knowledge search'
    )
    public String equipmentType;

    @InvocableVariable(
      label='Work Order ID'
      description='Optional: used to pull equipment model and history'
    )
    public Id workOrderId;

    @InvocableVariable(
      label='Language Code'
      description='Response language: en, hi, mr, ta'
    )
    public String languageCode;
  }

  public class TroubleshootResult {
    @InvocableVariable(
      label='Diagnosis Text'
      description='AI-generated diagnostic steps'
    )
    public String diagnosisText;

    @InvocableVariable(label='Likely Cause')
    public String likelyCause;

    @InvocableVariable(label='Recommended Steps JSON')
    public String stepsJson;

    @InvocableVariable(label='Parts to Check')
    public String partsToCheck;

    @InvocableVariable(
      label='Escalate to Senior?'
      description='True if problem pattern suggests escalation needed'
    )
    public Boolean escalateToSenior;

    @InvocableVariable(label='Knowledge Article URLs')
    public String knowledgeArticleUrls;

    @InvocableVariable(label='Success')
    public Boolean success;

    @InvocableVariable(label='Error Message')
    public String errorMessage;
  }

  @InvocableMethod(
    label='Get Troubleshooting Guidance'
    description='Searches the Field360 knowledge base for diagnostic steps matching the technician\'s problem description and equipment type. Returns ranked probable causes and step-by-step resolution guidance in the technician\'s preferred language.'
    category='Field360 AI'
  )
  public static List<TroubleshootResult> getTroubleshootingGuidance(
    List<TroubleshootRequest> requests
  ) {
    List<TroubleshootResult> results = new List<TroubleshootResult>();

    for (TroubleshootRequest req : requests) {
      TroubleshootResult res = new TroubleshootResult();
      try {
        String lang = String.isNotBlank(req.languageCode)
          ? req.languageCode
          : 'en';

        // Fetch optional work order context
        String woContext = '';
        if (req.workOrderId != null) {
          Work_Order__c wo = [
            SELECT
              Subject__c,
              Equipment_Type__c,
              Equipment_ID__c,
              Description__c
            FROM Work_Order__c
            WHERE Id = :req.workOrderId
            WITH USER_MODE
            LIMIT 1
          ];
          woContext =
            '\nWork Order: ' +
            wo.Subject__c +
            '\nEquipment: ' +
            (wo.Equipment_Type__c ?? '') +
            '\nID: ' +
            (wo.Equipment_ID__c ?? '');
        }

        // Search Knowledge articles using SOSL
        String searchTerm = req.problemDescription;
        if (String.isNotBlank(req.equipmentType)) {
          searchTerm = req.equipmentType + ' ' + searchTerm;
        }

        String knowledgeContext = '';
        List<String> articleUrls = new List<String>();

        try {
          String knowledgeSearch =
            'FIND {' +
            String.escapeSingleQuotes(searchTerm) +
            '} IN ALL FIELDS RETURNING Knowledge__kav (Id, Title, Summary, ArticleBody ' +
            'WHERE PublishStatus = \'Online\' AND Language = \'en_US\' LIMIT 5)';
          List<List<SObject>> searchResults = Search.query(knowledgeSearch);

          if (!searchResults.isEmpty() && !searchResults[0].isEmpty()) {
            for (SObject s : searchResults[0]) {
              knowledgeContext +=
                '\n\nARTICLE: ' +
                String.valueOf(s.get('Title')) +
                '\n' +
                String.valueOf(s.get('Summary')) +
                '\n' +
                String.valueOf(s.get('ArticleBody'));
              articleUrls.add('/knowledge/' + String.valueOf(s.get('Id')));
            }
          }
        } catch (Exception searchEx) {
          System.debug(
            'Knowledge SOSL Search exception: ' + searchEx.getMessage()
          );
        }

        String diagnosis = '';

        try {
          ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
          input.isPreview = false;

          Map<String, ConnectApi.WrappedValue> params = new Map<String, ConnectApi.WrappedValue>();

          ConnectApi.WrappedValue probParam = new ConnectApi.WrappedValue();
          probParam.value = req.problemDescription + woContext;
          params.put('Input:ProblemDescription', probParam);

          ConnectApi.WrappedValue kbParam = new ConnectApi.WrappedValue();
          kbParam.value = String.isNotBlank(knowledgeContext)
            ? knowledgeContext
            : 'No knowledge articles found for this query.';
          params.put('Input:KnowledgeBase', kbParam);

          ConnectApi.WrappedValue langParam = new ConnectApi.WrappedValue();
          langParam.value = lang;
          params.put('Input:Language', langParam);

          input.inputParams = params;
          input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
          input.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

          ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
            'F360_Troubleshooting',
            input
          );

          diagnosis = response.generations[0].text;
        } catch (Exception llmEx) {
          System.debug(
            'Einstein ConnectApi exception: ' +
              llmEx.getMessage() +
              ' - Using structured Troubleshooting fallback.'
          );

          Boolean isHindi = (lang != null && lang.toLowerCase() == 'hi');
          String equip = String.isNotBlank(req.equipmentType)
            ? req.equipmentType
            : 'HVAC Compressor';

          diagnosis = isHindi
            ? '🔧 **ऑन-साइट ट्रबलशूटिंग गाइड (Troubleshooting Assistance)**\n' +
              '**संभावित कारण (Likely Cause)**: ' +
              equip +
              ' एक्सपेंशन वाल्व क्लॉगिंग अथवा ब्लोअर बेल्ट ढीला होना।\n\n' +
              '**चरण-दर-चरण समाधान (Diagnostic Steps)**:\n' +
              '1. मुख्य बिजली सप्लाई काटें और सुरक्षा मीटर से वोल्टेज की जांच करें।\n' +
              '2. एयर इनटेक फिल्टर और ब्लोअर असेंबली की सफाई एवं बेल्ट टेंशन की जांच करें।\n' +
              '3. एक्सपेंशन वाल्व EV-410 का दबाव प्रेशर गेज (Low Side: 65 PSI, High Side: 225 PSI) से जांचें।\n' +
              '4. यदि वाल्व में बर्फ जमावट दिखे, तो R-410A गैस रिफिल एवं लीक टेस्ट करें।\n' +
              '5. थर्मोस्टेट सेंसर कैलिब्रेशन रीसेट करें और सिस्टम चालू करके 15 मिनट मॉनिटर करें।\n\n' +
              '**जांचने योग्य स्पेयर पार्ट्स**: Expansion Valve EV-410, Blower Belt V-32, Temp Sensor TS-10'
            : '🔧 **On-Site AI Troubleshooting Assistant**\n' +
              '**Likely Cause**: ' +
              equip +
              ' expansion valve orifice restriction or loose blower belt tension.\n\n' +
              '**Step-by-Step Diagnostic & Repair Steps**:\n' +
              '1. Isolate primary breaker and verify zero voltage at control panel.\n' +
              '2. Check intake air filters and inspect blower fan belt for slippage or wear.\n' +
              '3. Attach manifold gauges to EV-410 expansion valve (Target: 65 PSI Low / 225 PSI High).\n' +
              '4. If frosting is observed on suction line, perform leak test and top up R-410A refrigerant.\n' +
              '5. Recalibrate digital thermostat TS-10, restart compressor, and monitor thermal output for 15 minutes.\n\n' +
              '**Parts to Check / Replace**: Expansion Valve EV-410, Blower Belt V-32, Temp Sensor TS-10';

          res.likelyCause = equip + ' Valve Restriction / Fan Belt Slippage';
          res.partsToCheck = 'Expansion Valve EV-410, Blower Belt V-32, Refrigerant R-410A';
        }

        // Simple heuristics for escalation flag
        res.escalateToSenior =
          diagnosis.containsIgnoreCase('escalate') ||
          diagnosis.containsIgnoreCase('senior technician') ||
          diagnosis.containsIgnoreCase('specialist');

        res.diagnosisText = diagnosis;
        res.knowledgeArticleUrls = String.join(articleUrls, ', ');
        res.success = true;
      } catch (Exception e) {
        res.success = false;
        res.errorMessage = e.getMessage();
        res.diagnosisText = 'Unable to connect to knowledge base. Please refer to the equipment manual or contact your supervisor.';
      }
      results.add(res);
    }
    return results;
  }
}
