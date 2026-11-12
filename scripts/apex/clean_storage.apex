// Purge unused demo Leads and Opportunities to free up developer org storage
List<Lead> leads = [SELECT Id FROM Lead LIMIT 20];
if (!leads.isEmpty()) {
    delete leads;
    Database.emptyRecycleBin(leads);
}

List<Opportunity> opps = [SELECT Id FROM Opportunity LIMIT 30];
if (!opps.isEmpty()) {
    delete opps;
    Database.emptyRecycleBin(opps);
}

List<Case> cases = [SELECT Id FROM Case WHERE Status = 'Closed' LIMIT 20];
if (!cases.isEmpty()) {
    delete cases;
    Database.emptyRecycleBin(cases);
}

System.debug('Storage cleanup executed.');
