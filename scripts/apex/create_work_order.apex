// Apex Anonymous Script to create a single Work Order record
Work_Order__c wo = new Work_Order__c(
    Subject__c = 'Urgent HVAC Cooling Failure - Plant Floor 2',
    Equipment_ID__c = 'HVAC-100',
    Equipment_Type__c = 'HVAC',
    Status__c = 'New',
    Priority__c = 'High',
    Description__c = 'HVAC-100 stopped cooling at 10 AM. Blower fan running but no chill airflow.'
);

insert wo;

System.debug('SUCCESS: Work Order Created with ID: ' + wo.Id);
