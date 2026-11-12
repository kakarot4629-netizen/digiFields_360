const fs = require('fs');
const path = require('path');

const filePath = path.resolve(__dirname, '../force-app/main/default/classes/DF360_WorkOrderAppointmentsAPI.cls');
let code = fs.readFileSync(filePath, 'utf8');

if (!code.includes("public static Map<String, Object> getWorkOrderBriefing")) {
  const methodDef = `
    /**
     * Dedicated Job Briefing Query Method
     * GET /services/apexrest/df360/v1/work-orders/{workOrderId}/briefing
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getWorkOrderBriefing(String workOrderIdentifier) {
        if (String.isBlank(workOrderIdentifier)) {
            return new Map<String, Object>{ 'success' => false, 'error' => 'Work Order Identifier required' };
        }
        String cleanedId = workOrderIdentifier.trim();
        List<Work_Order__c> wos = [
            SELECT Id, Name, Subject__c, Equipment_ID__c, Equipment_Type__c, Site_Address__c,
                   AI_Pre_Job_Briefing__c, Briefing_Generated__c
            FROM Work_Order__c
            WHERE Id = :cleanedId OR Name = :cleanedId
            LIMIT 1
        ];
        if (wos.isEmpty()) {
            return new Map<String, Object>{ 'success' => false, 'error' => 'Work Order not found for identifier: ' + workOrderIdentifier };
        }
        Work_Order__c wo = wos[0];
        return new Map<String, Object>{
            'success' => true,
            'workOrderId' => wo.Id,
            'workOrderName' => wo.Name,
            'subject' => wo.Subject__c,
            'equipmentId' => wo.Equipment_ID__c,
            'equipmentType' => wo.Equipment_Type__c,
            'siteAddress' => wo.Site_Address__c,
            'briefing' => wo.AI_Pre_Job_Briefing__c,
            'briefingGenerated' => wo.Briefing_Generated__c
        };
    }
}
`;
  code = code.substring(0, code.lastIndexOf('}')) + methodDef;
  fs.writeFileSync(filePath, code, 'utf8');
  console.log("✅ Successfully inserted getWorkOrderBriefing method into DF360_WorkOrderAppointmentsAPI.cls!");
} else {
  console.log("Method already present.");
}
