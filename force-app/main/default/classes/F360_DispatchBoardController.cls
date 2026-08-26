/**
 * FIELD360 — Dispatch Board Controller
 * Wire-compatible Apex methods for the field360DispatchBoard LWC.
 * Uses @AuraEnabled(cacheable=true) for wire adapter support.
 */
public with sharing class F360_DispatchBoardController {
  @AuraEnabled(cacheable=true)
  public static List<Work_Order__c> getOpenWorkOrders() {
    return [
      SELECT
        Id,
        Name,
        Subject__c,
        Status__c,
        Priority__c,
        Description__c,
        Equipment_Type__c,
        Equipment_ID__c,
        Site_Address__c,
        Scheduled_Date__c,
        Account__c,
        Account__r.Name,
        Assigned_Technician__c,
        Assigned_Technician__r.Name,
        AI_Assignment_Reason__c,
        AI_Pre_Job_Briefing__c
      FROM Work_Order__c
      WHERE Status__c NOT IN ('Completed', 'Cancelled')
      ORDER BY Priority__c ASC, Scheduled_Date__c ASC
      LIMIT 100
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<User> getActiveTechnicians() {
    return [
      SELECT
        Id,
        Name,
        Skills__c,
        First_Time_Fix_Rate__c,
        Jobs_Completed_Total__c,
        Is_Active__c
      FROM User
      WHERE Is_Active__c = TRUE AND IsActive = TRUE
      ORDER BY Name ASC
      LIMIT 50
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<Maintenance_Alert__c> getMaintenanceAlerts() {
    return [
      SELECT
        Id,
        Name,
        Equipment_ID__c,
        Equipment_Type__c,
        Risk_Score__c,
        AI_Explanation__c,
        Jobs_In_Period__c,
        Days_Since_Last_Service__c,
        Status__c,
        Analysis_Date__c,
        Account__c,
        Account__r.Name
      FROM Maintenance_Alert__c
      WHERE Status__c = 'New'
      ORDER BY Risk_Score__c DESC
      LIMIT 20
    ];
  }

  @AuraEnabled
  public static Work_Order__c createPreventiveWorkOrder(Id alertId) {
    Maintenance_Alert__c alert = [
      SELECT
        Id,
        Equipment_ID__c,
        Equipment_Type__c,
        Account__c,
        AI_Explanation__c,
        Risk_Score__c
      FROM Maintenance_Alert__c
      WHERE Id = :alertId
      LIMIT 1
    ];

    Work_Order__c wo = new Work_Order__c();
    wo.Subject__c = 'Preventive Maintenance — ' + alert.Equipment_Type__c;
    wo.Description__c =
      'AI-recommended preventive maintenance. Risk score: ' +
      alert.Risk_Score__c +
      '/100\n\n' +
      alert.AI_Explanation__c;
    wo.Priority__c = alert.Risk_Score__c >= 75 ? 'High' : 'Medium';
    wo.Status__c = 'New';
    wo.Account__c = alert.Account__c;
    wo.Equipment_ID__c = alert.Equipment_ID__c;
    wo.Equipment_Type__c = alert.Equipment_Type__c;
    insert wo;

    update new Maintenance_Alert__c(
      Id = alertId,
      Status__c = 'Work Order Created',
      Resulting_Work_Order__c = wo.Id
    );

    return wo;
  }

  @AuraEnabled(cacheable=true)
  public static List<Equipment__c> getEquipment() {
    return [
      SELECT
        Id,
        Name,
        Account__c,
        Account__r.Name,
        Equipment_ID__c,
        Equipment_Type__c,
        Serial_Number__c,
        Model__c,
        Manufacturer__c,
        Site_Address__c,
        Install_Date__c,
        Last_Service_Date__c,
        Status__c,
        Current_Latitude__c,
        Current_Longitude__c,
        Description__c
      FROM Equipment__c
      ORDER BY Name ASC
      LIMIT 200
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<Parts_Inventory__c> getPartsInventory() {
    return [
      SELECT
        Id,
        Name,
        Part_Number__c,
        Part_Name__c,
        Category__c,
        Technician__c,
        Technician__r.Name,
        Quantity__c,
        Minimum_Stock__c,
        Unit_Cost__c,
        Supplier__c,
        Last_Restocked__c,
        Status__c
      FROM Parts_Inventory__c
      ORDER BY Part_Name__c ASC
      LIMIT 200
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<Job_Schedule__c> getJobSchedule() {
    return [
      SELECT
        Id,
        Name,
        Work_Order__c,
        Work_Order__r.Name,
        Technician__c,
        Technician__r.Name,
        Scheduled_Date__c,
        Start_Time__c,
        End_Time__c,
        Status__c,
        Notes__c,
        Duration_Hours__c,
        Priority__c
      FROM Job_Schedule__c
      WHERE Scheduled_Date__c >= TODAY
      ORDER BY Scheduled_Date__c ASC, Start_Time__c ASC
      LIMIT 100
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<Maintenance_Recommendation__c> getMaintenanceRecommendations() {
    return [
      SELECT
        Id,
        Name,
        Equipment__c,
        Equipment__r.Name,
        Account__c,
        Account__r.Name,
        Maintenance_Type__c,
        Recommended_Action__c,
        Priority__c,
        Status__c,
        Trigger_Source__c,
        Risk_Score__c,
        Recommended_Date__c,
        Work_Order__c,
        Work_Order__r.Name,
        AI_Explanation__c,
        Assigned_Technician__c,
        Assigned_Technician__r.Name
      FROM Maintenance_Recommendation__c
      WHERE Status__c IN ('New', 'In Progress')
      ORDER BY Risk_Score__c DESC
      LIMIT 50
    ];
  }
}
