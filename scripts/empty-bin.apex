List<SLA_Event__c> binList = [SELECT Id FROM SLA_Event__c WHERE isDeleted = true LIMIT 5000 ALL ROWS];
if (!binList.isEmpty()) {
    Database.emptyRecycleBin(binList);
    System.debug('Permanently purged ' + binList.size() + ' records from Recycle Bin.');
}
