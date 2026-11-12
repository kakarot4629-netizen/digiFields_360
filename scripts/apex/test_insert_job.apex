Account acc = [SELECT Id FROM Account LIMIT 1];
insert new Service_Job__c(
    Account__c = acc.Id, 
    Job_Type__c = 'Corrective Breakdown', 
    Priority__c = 'Critical', 
    Product_Category__c = 'Mechanical', 
    Status__c = 'New', 
    Notes__c = 'Verification job after flow fix'
);
System.debug('Service Job inserted successfully with Flow triggered!');
