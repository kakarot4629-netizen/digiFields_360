/**
 * FIELD360 AI — Test Classes
 * Complete test coverage for all AI Apex actions.
 * Run: sf apex run test --test-level RunLocalTests --target-org field360-dev
 */
@isTest
public class F360_AI_Tests {
  // ── Test Data Factory ────────────────────────────────────────────────────
  @TestSetup
  static void makeData() {
    // Create test account
    Account acc = new Account(Name = 'Tata Motors Test');
    insert acc;

    // Create technician user
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User tech = new User(
      FirstName = 'Rahul',
      LastName = 'Sharma',
      Email = 'rahul.sharma.test@field360test.com',
      Username = 'rahul.sharma.test@field360test.com.sandbox',
      Alias = 'rahuls',
      TimeZoneSidKey = 'Asia/Kolkata',
      LocaleSidKey = 'en_IN',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = p.Id,
      Skills__c = 'HVAC, Compressor, Generator',
      First_Time_Fix_Rate__c = 87.5,
      Is_Active__c = true
    );
    insert tech;

    // Create work orders
    List<Work_Order__c> wos = new List<Work_Order__c>();
    wos.add(
      new Work_Order__c(
        Subject__c = 'HVAC Annual Service',
        Status__c = 'New',
        Priority__c = 'High',
        Account__c = acc.Id,
        Equipment_ID__c = 'HVAC-001',
        Equipment_Type__c = 'HVAC',
        Site_Address__c = 'Pimpri-Chinchwad MIDC, Pune',
        Description__c = 'Annual service for 3 HVAC units on floor 2'
      )
    );
    wos.add(
      new Work_Order__c(
        Subject__c = 'Generator Inspection',
        Status__c = 'Assigned',
        Priority__c = 'Medium',
        Account__c = acc.Id,
        Assigned_Technician__c = tech.Id,
        Equipment_ID__c = 'GEN-002',
        Equipment_Type__c = 'Generator',
        Site_Address__c = 'Bhosari MIDC, Pune'
      )
    );
    insert wos;

    // Create job history for predictive maintenance tests
    List<Job_History__c> histories = new List<Job_History__c>();
    for (Integer i = 0; i < 5; i++) {
      histories.add(
        new Job_History__c(
          Work_Order__c = wos[0].Id,
          Equipment_ID__c = 'HVAC-001',
          Equipment_Type__c = 'HVAC',
          Fault_Description__c = 'Cooling inefficiency — fault ' + i,
          Resolution__c = 'Filter replaced, refrigerant topped up',
          Parts_Used__c = 'Air filter 20x25, R-32 refrigerant 500g',
          Technician__c = tech.Id,
          Job_Date__c = Date.today().addDays(-(i * 15)),
          First_Time_Fix__c = i < 4,
          Duration_Minutes__c = 90 + (i * 15),
          Account__c = acc.Id
        )
      );
    }
    insert histories;
  }

  // ── Feature 1: Pre-Job Briefing ─────────────────────────────────────────
  @isTest
  static void testPreJobBriefingSuccess() {
    Work_Order__c wo = [
      SELECT Id
      FROM Work_Order__c
      WHERE Equipment_ID__c = 'GEN-002'
      LIMIT 1
    ];
    Test.startTest();
    // Mock the Connect API call
    Test.setMock(
      HttpCalloutMock.class,
      new F360_MockPromptTemplate('PRE_JOB_BRIEFING_RESPONSE')
    );

    List<F360_PreJobBriefingAction.BriefingRequest> reqs = new List<F360_PreJobBriefingAction.BriefingRequest>();
    F360_PreJobBriefingAction.BriefingRequest req = new F360_PreJobBriefingAction.BriefingRequest();
    req.workOrderId = wo.Id;
    req.languageCode = 'en';
    reqs.add(req);

    List<F360_PreJobBriefingAction.BriefingResult> results = F360_PreJobBriefingAction.generateBriefing(
      reqs
    );
    Test.stopTest();

    System.assertNotEquals(null, results, 'Results should not be null');
    System.assertEquals(1, results.size(), 'Should return one result');
    // Note: actual LLM call is mocked — in sandbox this will call the real Einstein API
  }

  @isTest
  static void testPreJobBriefingWithHistory() {
    Work_Order__c wo = [
      SELECT Id
      FROM Work_Order__c
      WHERE Equipment_ID__c = 'HVAC-001'
      LIMIT 1
    ];
    List<Job_History__c> history = [
      SELECT Id
      FROM Job_History__c
      WHERE Equipment_ID__c = 'HVAC-001'
    ];

    System.assertEquals(
      5,
      history.size(),
      '5 history records should exist for HVAC-001'
    );

    Test.startTest();
    Test.setMock(
      HttpCalloutMock.class,
      new F360_MockPromptTemplate('BRIEFING_WITH_HISTORY')
    );

    List<F360_PreJobBriefingAction.BriefingRequest> reqs = new List<F360_PreJobBriefingAction.BriefingRequest>();
    F360_PreJobBriefingAction.BriefingRequest req = new F360_PreJobBriefingAction.BriefingRequest();
    req.workOrderId = wo.Id;
    req.languageCode = 'hi'; // Hindi
    reqs.add(req);

    List<F360_PreJobBriefingAction.BriefingResult> results = F360_PreJobBriefingAction.generateBriefing(
      reqs
    );
    Test.stopTest();

    System.assertEquals(1, results.size());
  }

  // ── Feature 4: Smart Assignment ──────────────────────────────────────────
  @isTest
  static void testSmartAssignmentWithTechnician() {
    Work_Order__c wo = [
      SELECT Id
      FROM Work_Order__c
      WHERE Equipment_Type__c = 'HVAC'
      LIMIT 1
    ];

    Test.startTest();
    List<F360_SmartAssignmentAction.AssignmentRequest> reqs = new List<F360_SmartAssignmentAction.AssignmentRequest>();
    F360_SmartAssignmentAction.AssignmentRequest req = new F360_SmartAssignmentAction.AssignmentRequest();
    req.workOrderId = wo.Id;
    req.maxResults = 3;
    reqs.add(req);

    List<F360_SmartAssignmentAction.AssignmentResult> results = F360_SmartAssignmentAction.recommend(
      reqs
    );
    Test.stopTest();

    System.assertEquals(1, results.size());
    System.assertEquals(
      true,
      results[0].success,
      'Assignment recommendation should succeed: ' + results[0].errorMessage
    );
    // Rahul has HVAC skills — should be recommended
    System.assertNotEquals(
      null,
      results[0].recommendationsJson,
      'Should return recommendations'
    );
  }

  @isTest
  static void testSmartAssignmentNoTechnicians() {
    // Deactivate all technicians
    List<User> techs = [SELECT Id FROM User WHERE Is_Active__c = TRUE LIMIT 10];
    for (User u : techs)
      u.Is_Active__c = false;
    update techs;

    Work_Order__c wo = [SELECT Id FROM Work_Order__c LIMIT 1];

    Test.startTest();
    List<F360_SmartAssignmentAction.AssignmentRequest> reqs = new List<F360_SmartAssignmentAction.AssignmentRequest>();
    F360_SmartAssignmentAction.AssignmentRequest req = new F360_SmartAssignmentAction.AssignmentRequest();
    req.workOrderId = wo.Id;
    reqs.add(req);

    List<F360_SmartAssignmentAction.AssignmentResult> results = F360_SmartAssignmentAction.recommend(
      reqs
    );
    Test.stopTest();

    System.assertEquals(1, results.size());
    System.assertEquals(
      true,
      results[0].success,
      'Should succeed even with no technicians'
    );
    System.assertEquals(
      null,
      results[0].topTechnicianId,
      'No technicians should mean no top recommendation'
    );
  }

  // ── Feature 6: Predictive Maintenance ───────────────────────────────────
  @isTest
  static void testPredictiveMaintenance_HighRiskEquipment() {
    // HVAC-001 has 5 jobs in 90 days — should score high
    Test.startTest();
    Test.setMock(
      HttpCalloutMock.class,
      new F360_MockPromptTemplate('MAINTENANCE_ALERT')
    );

    List<F360_PredictiveMaintenanceAction.MaintenanceRequest> reqs = new List<F360_PredictiveMaintenanceAction.MaintenanceRequest>();
    F360_PredictiveMaintenanceAction.MaintenanceRequest req = new F360_PredictiveMaintenanceAction.MaintenanceRequest();
    req.lookBackDays = 90;
    req.riskThreshold = 30; // Low threshold to ensure HVAC-001 is flagged in test
    reqs.add(req);

    List<F360_PredictiveMaintenanceAction.MaintenanceResult> results = F360_PredictiveMaintenanceAction.analyseEquipment(
      reqs
    );
    Test.stopTest();

    System.assertEquals(1, results.size());
    System.assertEquals(true, results[0].success);
    System.assertEquals(
      1,
      results[0].equipmentAnalysed,
      'Should have analysed 1 equipment (HVAC-001)'
    );
    System.assertNotEquals(
      0,
      results[0].alertsCreated,
      'HVAC-001 should be flagged with 5 jobs in 90 days'
    );
  }

  @isTest
  static void testPredictiveMaintenance_HighThreshold() {
    Test.startTest();
    List<F360_PredictiveMaintenanceAction.MaintenanceRequest> reqs = new List<F360_PredictiveMaintenanceAction.MaintenanceRequest>();
    F360_PredictiveMaintenanceAction.MaintenanceRequest req = new F360_PredictiveMaintenanceAction.MaintenanceRequest();
    req.lookBackDays = 90;
    req.riskThreshold = 99; // Maximum threshold — nothing should be flagged
    reqs.add(req);

    List<F360_PredictiveMaintenanceAction.MaintenanceResult> results = F360_PredictiveMaintenanceAction.analyseEquipment(
      reqs
    );
    Test.stopTest();

    System.assertEquals(
      0,
      results[0].alertsCreated,
      'Nothing should be flagged at threshold 99'
    );
  }

  // ── Feature 7: Customer Booking ─────────────────────────────────────────
  @isTest
  static void testGetAvailableSlots() {
    Test.startTest();
    List<F360_BookingAgentAction.AvailabilityRequest> reqs = new List<F360_BookingAgentAction.AvailabilityRequest>();
    F360_BookingAgentAction.AvailabilityRequest req = new F360_BookingAgentAction.AvailabilityRequest();
    req.jobDescription = 'Generator making noise';
    req.customerPhone = '919876543210';
    req.equipmentType = 'Generator';
    reqs.add(req);

    List<F360_BookingAgentAction.AvailabilityResult> results = F360_BookingAgentAction.getAvailableSlots(
      reqs
    );
    Test.stopTest();

    System.assertEquals(1, results.size());
    System.assertEquals(true, results[0].success);
    System.assertEquals(
      true,
      results[0].hasSlots,
      'Should find available slots'
    );
    System.assertNotEquals(
      null,
      results[0].slot1Summary,
      'First slot should have a label'
    );
  }

  @isTest
  static void testConfirmBooking() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    User tech = [SELECT Id FROM User WHERE Is_Active__c = TRUE LIMIT 1];

    Date tomorrow = Date.today().addDays(1);
    String slotJson = JSON.serialize(
      new Map<String, Object>{
        'date' => String.valueOf(tomorrow),
        'time' => '09:00',
        'technicianId' => tech.Id,
        'technicianName' => 'Test Tech',
        'displayLabel' => tomorrow.format() + ' at 09:00 hrs'
      }
    );

    Test.startTest();
    List<F360_BookingAgentAction.ConfirmRequest> reqs = new List<F360_BookingAgentAction.ConfirmRequest>();
    F360_BookingAgentAction.ConfirmRequest req = new F360_BookingAgentAction.ConfirmRequest();
    req.selectedSlotJson = slotJson;
    req.customerPhone = '919876543210';
    req.jobDescription = 'Generator making noise on startup';
    req.accountId = acc.Id;
    req.equipmentType = 'Generator';
    reqs.add(req);

    List<F360_BookingAgentAction.ConfirmResult> results = F360_BookingAgentAction.confirmBooking(
      reqs
    );
    Test.stopTest();

    System.assertEquals(1, results.size());
    System.assertEquals(true, results[0].success);
    System.assertNotEquals(
      null,
      results[0].workOrderId,
      'Work order should be created'
    );
    System.assert(
      results[0].confirmationMessage.contains('Booking confirmed'),
      'Confirmation message should contain "Booking confirmed"'
    );

    // Verify work order created in database
    Work_Order__c createdWO = [
      SELECT Status__c, Assigned_Technician__c
      FROM Work_Order__c
      WHERE Id = :results[0].workOrderId
    ];
    System.assertEquals('Assigned', createdWO.Status__c);
    System.assertEquals(tech.Id, createdWO.Assigned_Technician__c);
  }

  // ── Dispatch Board Controller ────────────────────────────────────────────
  @isTest
  static void testDispatchBoardGetOpenWorkOrders() {
    Test.startTest();
    List<Work_Order__c> wos = F360_DispatchBoardController.getOpenWorkOrders();
    Test.stopTest();

    System.assert(
      wos.size() >= 2,
      'Should return at least the 2 test work orders'
    );
    // Completed work orders should not appear
    for (Work_Order__c wo : wos) {
      System.assertNotEquals('Completed', wo.Status__c);
      System.assertNotEquals('Cancelled', wo.Status__c);
    }
  }

  @isTest
  static void testDispatchBoardGetActiveTechnicians() {
    Test.startTest();
    List<User> techs = F360_DispatchBoardController.getActiveTechnicians();
    Test.stopTest();

    System.assert(
      techs.size() >= 1,
      'Should return at least the test technician'
    );
  }

  @isTest
  static void testCreatePreventiveWorkOrder() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Maintenance_Alert__c alert = new Maintenance_Alert__c(
      Equipment_ID__c = 'HVAC-001',
      Equipment_Type__c = 'HVAC',
      Account__c = acc.Id,
      Risk_Score__c = 78,
      AI_Explanation__c = 'Test risk explanation',
      Status__c = 'New'
    );
    insert alert;

    Test.startTest();
    Work_Order__c wo = F360_DispatchBoardController.createPreventiveWorkOrder(
      alert.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, wo, 'Work order should be created');
    System.assertEquals(
      'High',
      wo.Priority__c,
      'Risk 78 should create High priority WO'
    );

    Maintenance_Alert__c updated = [
      SELECT Status__c, Resulting_Work_Order__c
      FROM Maintenance_Alert__c
      WHERE Id = :alert.Id
    ];
    System.assertEquals('Work Order Created', updated.Status__c);
    System.assertEquals(wo.Id, updated.Resulting_Work_Order__c);
  }

  // ── NL2SOQL Dynamic Query Controller ─────────────────────────────────────
  @isTest
  static void testNLQueryAccounts() {
    Test.startTest();
    F360_NLQueryController.QueryResult res = F360_NLQueryController.executeNaturalLanguageQuery(
      'Show me top accounts in Pune',
      5
    );
    Test.stopTest();

    System.assertEquals(true, res.isSuccess);
    System.assertEquals('Account', res.targetObject);
    System.assertNotEquals(0, res.columns.size());
    System.assertNotEquals(null, res.soql);
    System.assertNotEquals(null, res.aiSummary);
  }

  @isTest
  static void testNLQueryTechnicians() {
    Technician__c tech = new Technician__c(
      Name = 'Test Technician',
      Skills__c = 'Generator;HVAC',
      Is_Active__c = true,
      Available_For_Assignment__c = true,
      First_Time_Fix_Rate__c = 90
    );
    insert tech;

    Test.startTest();
    F360_NLQueryController.QueryResult res = F360_NLQueryController.executeNaturalLanguageQuery(
      'Who are available resources with generator skills',
      5
    );
    Test.stopTest();

    System.assertEquals(true, res.isSuccess);
    System.assertEquals('Technician__c', res.targetObject);
    System.assert(res.recordCount >= 1);
    System.assert(res.soql.contains('Technician__c'));
  }

  @isTest
  static void testNLQueryWorkOrders() {
    Test.startTest();
    F360_NLQueryController.QueryResult res = F360_NLQueryController.executeNaturalLanguageQuery(
      'Show critical open work orders',
      5
    );
    Test.stopTest();

    System.assertEquals(true, res.isSuccess);
    System.assertEquals('Work_Order__c', res.targetObject);
    System.assertNotEquals(null, res.soql);
  }

  @isTest
  static void testNLQueryAlerts() {
    Test.startTest();
    F360_NLQueryController.QueryResult res = F360_NLQueryController.executeNaturalLanguageQuery(
      'Show critical alerts on generators',
      5
    );
    Test.stopTest();

    System.assertEquals(true, res.isSuccess);
    System.assertEquals('Maintenance_Alert__c', res.targetObject);
    System.assertNotEquals(null, res.soql);
  }
}

/**
 * Mock HTTP callout for ConnectApi.EinsteinLLM calls
 * Returns a plausible prompt template response without hitting Einstein
 */
