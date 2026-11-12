// Test insert a single minimal Work Order record
try {
    Work_Order__c wo = new Work_Order__c(
        Subject__c = 'Test Single Insert',
        Status__c = 'New',
        Priority__c = 'Low'
    );
    insert wo;
    System.debug('Single insert succeeded: ' + wo.Id);
} catch (Exception e) {
    System.debug('Single insert error: ' + e.getMessage() + ' | ' + e.getTypeName());
}
