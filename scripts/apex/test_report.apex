Work_Order__c wo = [SELECT Id FROM Work_Order__c WHERE Status__c = 'Completed' ORDER BY LastModifiedDate DESC LIMIT 1];
F360_ServiceReportAction.ReportRequest req = new F360_ServiceReportAction.ReportRequest();
req.workOrderId = wo.Id;
req.sendToCustomer = false;

List<F360_ServiceReportAction.ReportResult> res = F360_ServiceReportAction.generateReport(new List<F360_ServiceReportAction.ReportRequest>{req});

System.debug('REPORT_SUCCESS: ' + res[0].success);
System.debug('REPORT_DOCUMENT_URL: ' + res[0].documentUrl);
System.debug('REPORT_TEXT:\n' + res[0].reportText);
