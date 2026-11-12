// Storage audit script
Map<String, Integer> counts = new Map<String, Integer>();
List<String> objects = new List<String>{
    'Account', 'Contact', 'Opportunity', 'Lead', 'Case', 'Task', 'Event',
    'FeedItem', 'FeedComment', 'ContentDocument', 'Attachment', 'Asset', 'Product2',
    'Work_Order__c', 'Service_Job__c', 'Technician__c', 'Job_History__c',
    'Maintenance_Alert__c', 'Equipment__c', 'Part__c', 'SLA_Config__c'
};

for (String obj : objects) {
    try {
        Integer cnt = Database.countQuery('SELECT count() FROM ' + obj);
        if (cnt > 0) counts.put(obj, cnt);
    } catch (Exception e) {}
}

System.debug('STORAGE COUNTS: ' + JSON.serializePretty(counts));

// Check and empty recycle bin
try {
    List<sObject> deleted = [SELECT Id FROM Work_Order__c WHERE isDeleted = true LIMIT 200 ALL ROWS];
    if (!deleted.isEmpty()) {
        Database.emptyRecycleBin(deleted);
        System.debug('Emptied ' + deleted.size() + ' deleted Work_Order__c records from Recycle Bin');
    }
} catch (Exception e) {
    System.debug('Recycle bin check error: ' + e.getMessage());
}
