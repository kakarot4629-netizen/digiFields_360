public with sharing class F360_WorkOrderLwcController {
    @AuraEnabled
    public static Map<String, Object> generateBriefing(Id workOrderId, String languageCode) {
        F360_PreJobBriefingAction.BriefingRequest request = new F360_PreJobBriefingAction.BriefingRequest();
        request.workOrderId = workOrderId;
        request.languageCode = languageCode;
        F360_PreJobBriefingAction.BriefingResult result =
            F360_PreJobBriefingAction.generateBriefing(new List<F360_PreJobBriefingAction.BriefingRequest>{ request })[0];
        return new Map<String, Object>{ 'success' => result.success, 'errorMessage' => result.errorMessage, 'briefingText' => result.briefingText };
    }

    @AuraEnabled
    public static Map<String, Object> getTroubleshootingGuidance(Id workOrderId, String problemDescription, String equipmentType, String languageCode) {
        F360_TroubleshootingAction.TroubleshootRequest request = new F360_TroubleshootingAction.TroubleshootRequest();
        request.workOrderId = workOrderId;
        request.problemDescription = problemDescription;
        request.equipmentType = equipmentType;
        request.languageCode = languageCode;
        F360_TroubleshootingAction.TroubleshootResult result =
            F360_TroubleshootingAction.getTroubleshootingGuidance(new List<F360_TroubleshootingAction.TroubleshootRequest>{ request })[0];
        return new Map<String, Object>{ 'success' => result.success, 'errorMessage' => result.errorMessage, 'diagnosisText' => result.diagnosisText, 'escalateToSenior' => result.escalateToSenior, 'knowledgeArticleUrls' => result.knowledgeArticleUrls };
    }

    @AuraEnabled
    public static Map<String, Object> generateReport(Id workOrderId, Boolean sendToCustomer) {
        F360_ServiceReportAction.ReportRequest request = new F360_ServiceReportAction.ReportRequest();
        request.workOrderId = workOrderId;
        request.sendToCustomer = sendToCustomer;
        F360_ServiceReportAction.ReportResult result =
            F360_ServiceReportAction.generateReport(new List<F360_ServiceReportAction.ReportRequest>{ request })[0];
        return new Map<String, Object>{ 'success' => result.success, 'errorMessage' => result.errorMessage, 'reportText' => result.reportText, 'documentUrl' => result.documentUrl };
    }

    @AuraEnabled
    public static Map<String, Object> recommendTechnician(Id workOrderId) {
        F360_SmartAssignmentAction.AssignmentRequest request = new F360_SmartAssignmentAction.AssignmentRequest();
        request.workOrderId = workOrderId;
        request.maxResults = 3;
        F360_SmartAssignmentAction.AssignmentResult result = F360_SmartAssignmentAction.recommend(new List<F360_SmartAssignmentAction.AssignmentRequest>{ request })[0];
        return new Map<String, Object>{ 'success' => result.success, 'errorMessage' => result.errorMessage, 'topTechnicianId' => result.topTechnicianId, 'topTechnicianName' => result.topTechnicianName, 'topReason' => result.topReason };
    }
}
