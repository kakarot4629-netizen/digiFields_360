/**
 * @description Controller for Dynamic Natural Language to Salesforce Query (NL2SOQL)
 *              Allows users to type arbitrary questions (e.g. "top accounts", "who are available resources in Pune",
 *              "critical alerts on generators") and returns structured records, dynamic datatable columns,
 *              generated SOQL, and conversational AI summaries.
 */
public with sharing class F360_NLQueryController {
  public class ColumnDef {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String fieldName;
    @AuraEnabled
    public String type;
    @AuraEnabled
    public Boolean sortable;

    public ColumnDef(String label, String fieldName, String type) {
      this.label = label;
      this.fieldName = fieldName;
      this.type = type;
      this.sortable = true;
    }
  }

  public class QueryResult {
    @AuraEnabled
    public Boolean isSuccess;
    @AuraEnabled
    public String errorMessage;
    @AuraEnabled
    public String prompt;
    @AuraEnabled
    public String targetObject;
    @AuraEnabled
    public String targetObjectLabel;
    @AuraEnabled
    public String soql;
    @AuraEnabled
    public Integer recordCount;
    @AuraEnabled
    public List<ColumnDef> columns;
    @AuraEnabled
    public List<Map<String, Object>> records;
    @AuraEnabled
    public String aiSummary;

    public QueryResult() {
      this.isSuccess = true;
      this.columns = new List<ColumnDef>();
      this.records = new List<Map<String, Object>>();
      this.recordCount = 0;
    }
  }

  @AuraEnabled(cacheable=false)
  public static QueryResult executeNaturalLanguageQuery(
    String prompt,
    Integer maxRecords
  ) {
    QueryResult res = new QueryResult();
    res.prompt = prompt;
    if (maxRecords == null || maxRecords <= 0 || maxRecords > 100) {
      maxRecords = 10;
    }

    try {
      String lowerPrompt = String.isNotBlank(prompt)
        ? prompt.toLowerCase().trim()
        : 'top accounts';
      String targetSObject = resolveTargetObject(lowerPrompt);
      res.targetObject = targetSObject;

      Schema.SObjectType sObjType = Schema.getGlobalDescribe()
        .get(targetSObject);
      if (sObjType == null) {
        targetSObject = 'Account';
        sObjType = Schema.getGlobalDescribe().get('Account');
      }
      res.targetObjectLabel = sObjType.getDescribe().getLabel();

      // Build dynamic SOQL query
      String soql = buildDynamicSOQL(targetSObject, lowerPrompt, maxRecords);
      res.soql = soql;

      // Execute Query
      List<SObject> queryRecords = Database.query(soql);

      // In-memory filter for LongTextArea fields like Skills__c
      if (targetSObject == 'Technician__c') {
        List<SObject> filtered = new List<SObject>();
        for (SObject sobj : queryRecords) {
          String skills = (String) sobj.get('Skills__c');
          String lowerSkills = String.isNotBlank(skills)
            ? skills.toLowerCase()
            : '';
          if (
            lowerPrompt.contains('generator') &&
            !lowerSkills.contains('generator')
          )
            continue;
          if (
            (lowerPrompt.contains('hvac') || lowerPrompt.contains('chiller')) &&
            !lowerSkills.contains('hvac')
          )
            continue;
          if (
            lowerPrompt.contains('compressor') &&
            !lowerSkills.contains('compressor')
          )
            continue;
          if (
            lowerPrompt.contains('electrical') &&
            !lowerSkills.contains('electrical')
          )
            continue;
          filtered.add(sobj);
        }
        queryRecords = filtered;
      }

      res.recordCount = queryRecords.size();

      // Build Dynamic Columns & Format Records
      buildColumnsAndRecords(targetSObject, queryRecords, res);

      // Generate Conversational AI Summary
      res.aiSummary = generateAISummary(
        targetSObject,
        res.records,
        lowerPrompt
      );
      res.isSuccess = true;
    } catch (Exception ex) {
      res.isSuccess = false;
      res.errorMessage = ex.getMessage();
      res.aiSummary = 'Unable to complete query: ' + ex.getMessage();
    }

    return res;
  }

  private static String resolveTargetObject(String prompt) {
    if (
      prompt.contains('technician') ||
      prompt.contains('resource') ||
      prompt.contains('tech') ||
      prompt.contains('engineer') ||
      prompt.contains('worker') ||
      prompt.contains('staff') ||
      prompt.contains('who available') ||
      prompt.contains('assigned resource') ||
      prompt.contains('skill')
    ) {
      return 'Technician__c';
    }
    if (
      prompt.contains('alert') ||
      prompt.contains('risk') ||
      prompt.contains('predictive') ||
      prompt.contains('warning') ||
      prompt.contains('anomaly')
    ) {
      return 'Maintenance_Alert__c';
    }
    if (
      prompt.contains('work order') ||
      prompt.contains('job') ||
      prompt.contains('ticket') ||
      prompt.contains('task') ||
      prompt.contains('repair') ||
      prompt.contains('briefing') ||
      prompt.contains('pending') ||
      prompt.contains('order')
    ) {
      return 'Work_Order__c';
    }
    if (
      prompt.contains('contact') ||
      prompt.contains('person') ||
      prompt.contains('manager') ||
      prompt.contains('customer contact')
    ) {
      return 'Contact';
    }
    if (
      prompt.contains('history') ||
      prompt.contains('past job') ||
      prompt.contains('resolution')
    ) {
      return 'Job_History__c';
    }
    return 'Account';
  }

  private static String buildDynamicSOQL(
    String targetSObject,
    String prompt,
    Integer maxRecords
  ) {
    List<String> whereClauses = new List<String>();
    String orderByClause = '';
    String selectFields = '';

    if (targetSObject == 'Technician__c') {
      selectFields = 'Id, Name, Skills__c, Is_Active__c, Available_For_Assignment__c, First_Time_Fix_Rate__c, Jobs_Completed_Total__c';

      if (
        prompt.contains('available') ||
        prompt.contains('who available') ||
        prompt.contains('free')
      ) {
        whereClauses.add('Available_For_Assignment__c = true');
        whereClauses.add('Is_Active__c = true');
      } else if (prompt.contains('active')) {
        whereClauses.add('Is_Active__c = true');
      }

      orderByClause = 'ORDER BY First_Time_Fix_Rate__c DESC NULLS LAST, Jobs_Completed_Total__c DESC';
    } else if (targetSObject == 'Work_Order__c') {
      selectFields = 'Id, Name, Subject__c, Status__c, Priority__c, Equipment_ID__c, Equipment_Type__c, Scheduled_Date__c, AI_Risk_Score__c';

      if (prompt.contains('critical')) {
        whereClauses.add('Priority__c = \'Critical\'');
      } else if (prompt.contains('high priority') || prompt.contains('high')) {
        whereClauses.add('Priority__c IN (\'Critical\', \'High\')');
      }
      if (
        prompt.contains('open') ||
        prompt.contains('pending') ||
        prompt.contains('assigned')
      ) {
        whereClauses.add(
          'Status__c IN (\'Assigned\', \'In Progress\', \'En Route\', \'On Site\')'
        );
      } else if (prompt.contains('completed') || prompt.contains('done')) {
        whereClauses.add('Status__c = \'Completed\'');
      }
      if (prompt.contains('generator')) {
        whereClauses.add('Equipment_Type__c = \'Generator\'');
      } else if (prompt.contains('hvac') || prompt.contains('chiller')) {
        whereClauses.add('Equipment_Type__c = \'HVAC\'');
      }

      orderByClause = 'ORDER BY CreatedDate DESC';
    } else if (targetSObject == 'Maintenance_Alert__c') {
      selectFields = 'Id, Name, Equipment_ID__c, Equipment_Type__c, Status__c, Risk_Score__c, Analysis_Date__c, Days_Since_Last_Service__c';

      if (prompt.contains('open') || !prompt.contains('resolved')) {
        whereClauses.add('Status__c = \'Open\'');
      }
      if (prompt.contains('critical') || prompt.contains('high risk')) {
        whereClauses.add('Risk_Score__c >= 80');
      }
      if (prompt.contains('generator')) {
        whereClauses.add('Equipment_Type__c = \'Generator\'');
      }

      orderByClause = 'ORDER BY Risk_Score__c DESC, Analysis_Date__c DESC';
    } else if (targetSObject == 'Contact') {
      selectFields = 'Id, Name, Title, Email, Phone, Account.Name';
      orderByClause = 'ORDER BY Name ASC';
    } else {
      // Account
      selectFields = 'Id, Name, Type, Industry, BillingCity, BillingState, Phone, AnnualRevenue';

      if (prompt.contains('pune')) {
        whereClauses.add('BillingCity = \'Pune\'');
      } else if (prompt.contains('mumbai')) {
        whereClauses.add('BillingCity = \'Mumbai\'');
      } else if (prompt.contains('delhi') || prompt.contains('gurgaon')) {
        whereClauses.add('BillingCity IN (\'Delhi\', \'Gurgaon\')');
      } else if (prompt.contains('bangalore') || prompt.contains('bengaluru')) {
        whereClauses.add('BillingCity IN (\'Bangalore\', \'Bengaluru\')');
      }

      if (
        prompt.contains('biotech') ||
        prompt.contains('pharma') ||
        prompt.contains('biotechnology')
      ) {
        whereClauses.add(
          'Industry IN (\'Biotechnology\', \'Pharmaceuticals\', \'Healthcare\')'
        );
      } else if (
        prompt.contains('auto') ||
        prompt.contains('automotive') ||
        prompt.contains('manufacturing')
      ) {
        whereClauses.add('Industry IN (\'Automotive\', \'Manufacturing\')');
      } else if (
        prompt.contains('tech') ||
        prompt.contains('technology') ||
        prompt.contains('software')
      ) {
        whereClauses.add('Industry = \'Technology\'');
      }

      orderByClause = 'ORDER BY AnnualRevenue DESC NULLS LAST, Name ASC';
    }

    String soql = 'SELECT ' + selectFields + ' FROM ' + targetSObject;
    if (!whereClauses.isEmpty()) {
      soql += ' WHERE ' + String.join(whereClauses, ' AND ');
    }
    if (String.isNotBlank(orderByClause)) {
      soql += ' ' + orderByClause;
    }
    soql += ' LIMIT ' + maxRecords;

    return soql;
  }

  private static void buildColumnsAndRecords(
    String targetSObject,
    List<SObject> records,
    QueryResult res
  ) {
    Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(targetSObject);
    Map<String, Schema.SObjectField> fieldMap = sObjType.getDescribe()
      .fields.getMap();

    List<ColumnDef> cols = new List<ColumnDef>();
    Set<String> addedFields = new Set<String>();

    if (targetSObject == 'Technician__c') {
      addCol(cols, addedFields, fieldMap, 'Name', 'Technician Name', 'text');
      addCol(cols, addedFields, fieldMap, 'Skills__c', 'Skills', 'text');
      addCol(
        cols,
        addedFields,
        fieldMap,
        'Available_For_Assignment__c',
        'Available?',
        'boolean'
      );
      addCol(cols, addedFields, fieldMap, 'Is_Active__c', 'Active', 'boolean');
      addCol(
        cols,
        addedFields,
        fieldMap,
        'First_Time_Fix_Rate__c',
        'Fix Rate (%)',
        'percent'
      );
      addCol(
        cols,
        addedFields,
        fieldMap,
        'Jobs_Completed_Total__c',
        'Jobs Completed',
        'number'
      );
    } else if (targetSObject == 'Work_Order__c') {
      addCol(cols, addedFields, fieldMap, 'Name', 'Work Order #', 'text');
      addCol(cols, addedFields, fieldMap, 'Subject__c', 'Subject', 'text');
      addCol(cols, addedFields, fieldMap, 'Status__c', 'Status', 'text');
      addCol(cols, addedFields, fieldMap, 'Priority__c', 'Priority', 'text');
      addCol(
        cols,
        addedFields,
        fieldMap,
        'Equipment_Type__c',
        'Equipment',
        'text'
      );
      addCol(
        cols,
        addedFields,
        fieldMap,
        'AI_Risk_Score__c',
        'Risk Score',
        'number'
      );
      addCol(
        cols,
        addedFields,
        fieldMap,
        'Scheduled_Date__c',
        'Scheduled Date',
        'date'
      );
    } else if (targetSObject == 'Maintenance_Alert__c') {
      addCol(cols, addedFields, fieldMap, 'Name', 'Alert ID', 'text');
      addCol(
        cols,
        addedFields,
        fieldMap,
        'Equipment_ID__c',
        'Equipment ID',
        'text'
      );
      addCol(cols, addedFields, fieldMap, 'Equipment_Type__c', 'Type', 'text');
      addCol(cols, addedFields, fieldMap, 'Status__c', 'Status', 'text');
      addCol(
        cols,
        addedFields,
        fieldMap,
        'Risk_Score__c',
        'Risk Score',
        'number'
      );
      addCol(
        cols,
        addedFields,
        fieldMap,
        'Days_Since_Last_Service__c',
        'Days Since Service',
        'number'
      );
    } else if (targetSObject == 'Contact') {
      addCol(cols, addedFields, fieldMap, 'Name', 'Full Name', 'text');
      addCol(cols, addedFields, fieldMap, 'Title', 'Title', 'text');
      addCol(cols, addedFields, fieldMap, 'Email', 'Email', 'email');
      addCol(cols, addedFields, fieldMap, 'Phone', 'Phone', 'phone');
    } else {
      // Account
      addCol(cols, addedFields, fieldMap, 'Name', 'Account Name', 'text');
      addCol(cols, addedFields, fieldMap, 'Industry', 'Industry', 'text');
      addCol(cols, addedFields, fieldMap, 'BillingCity', 'City', 'text');
      addCol(cols, addedFields, fieldMap, 'BillingState', 'State', 'text');
      addCol(
        cols,
        addedFields,
        fieldMap,
        'AnnualRevenue',
        'Annual Revenue',
        'currency'
      );
      addCol(cols, addedFields, fieldMap, 'Phone', 'Phone', 'phone');
    }

    res.columns = cols;

    // Convert SObjects to Map for datatable serialization
    List<Map<String, Object>> formattedRecords = new List<Map<String, Object>>();
    for (SObject sobj : records) {
      Map<String, Object> row = new Map<String, Object>();
      row.put('Id', sobj.Id);
      for (ColumnDef col : cols) {
        Object val = sobj.get(col.fieldName);
        row.put(col.fieldName, val);
      }
      formattedRecords.add(row);
    }
    res.records = formattedRecords;
  }

  private static void addCol(
    List<ColumnDef> cols,
    Set<String> addedFields,
    Map<String, Schema.SObjectField> fieldMap,
    String fieldName,
    String defaultLabel,
    String defaultType
  ) {
    if (addedFields.contains(fieldName))
      return;
    addedFields.add(fieldName);

    String label = defaultLabel;
    String type = defaultType;

    if (fieldMap.containsKey(fieldName)) {
      Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
      label = dfr.getLabel();
      Schema.DisplayType dt = dfr.getType();
      if (dt == Schema.DisplayType.Currency)
        type = 'currency';
      else if (dt == Schema.DisplayType.Percent)
        type = 'percent';
      else if (
        dt == Schema.DisplayType.Date ||
        dt == Schema.DisplayType.DateTime
      )
        type = 'date';
      else if (dt == Schema.DisplayType.Boolean)
        type = 'boolean';
      else if (dt == Schema.DisplayType.Phone)
        type = 'phone';
      else if (dt == Schema.DisplayType.Email)
        type = 'email';
      else if (
        dt == Schema.DisplayType.Integer ||
        dt == Schema.DisplayType.Double
      )
        type = 'number';
      else
        type = 'text';
    }

    cols.add(new ColumnDef(label, fieldName, type));
  }

  private static String generateAISummary(
    String targetSObject,
    List<Map<String, Object>> records,
    String prompt
  ) {
    if (records.isEmpty()) {
      return 'No records found matching your request for "' +
        prompt +
        '". Try modifying your search keywords.';
    }

    Integer count = records.size();
    List<String> topNames = new List<String>();
    for (Integer i = 0; i < Math.min(3, count); i++) {
      String name = (String) records[i].get('Name');
      if (String.isNotBlank(name)) {
        topNames.add(name);
      }
    }

    if (targetSObject == 'Technician__c') {
      return 'Found ' +
        count +
        ' technician(s) matching your request. Top results: ' +
        String.join(topNames, ', ') +
        '.';
    } else if (targetSObject == 'Work_Order__c') {
      return 'Found ' +
        count +
        ' work order(s) matching your criteria. Priority items: ' +
        String.join(topNames, ', ') +
        '.';
    } else if (targetSObject == 'Maintenance_Alert__c') {
      return 'Identified ' +
        count +
        ' predictive maintenance alert(s). Focus equipment: ' +
        String.join(topNames, ', ') +
        '.';
    } else {
      return 'Found ' +
        count +
        ' account(s) matching your request. Top accounts: ' +
        String.join(topNames, ', ') +
        '.';
    }
  }
}
