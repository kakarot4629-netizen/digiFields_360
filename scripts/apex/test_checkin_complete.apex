Service_Job__c sj = [SELECT Id, Name, Status__c, Technician__c FROM Service_Job__c ORDER BY CreatedDate DESC LIMIT 1];
System.debug('Testing SJ: ' + sj.Name + ' (' + sj.Id + '), Status: ' + sj.Status__c);
try {
    DF360_ServiceJobController.checkIn(sj.Id, sj.Technician__c, 19.0760, 72.8777);
    System.debug('Check-in succeeded!');
} catch (Exception e) {
    System.debug('CHECK-IN EXCEPTION: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
}

try {
    DF360_ServiceJobController.completeJob(sj.Id, true, 'https://sig.digifield360.io/sig.png');
    System.debug('Complete job succeeded!');
} catch (Exception e) {
    System.debug('COMPLETE JOB EXCEPTION: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString());
}
