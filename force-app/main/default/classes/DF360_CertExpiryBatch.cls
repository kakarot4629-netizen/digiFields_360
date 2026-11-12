public class DF360_CertExpiryBatch implements Database.Batchable<SObject>, Schedulable {
    public void execute(SchedulableContext sc) { Database.executeBatch(new DF360_CertExpiryBatch(), 200); }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date alertDate = Date.today().addDays(30);
        return Database.getQueryLocator([SELECT Id, Technician__c, Technician__r.Name, Skill__r.Skill_Name__c, Cert_Expiry__c
            FROM Technician_Skill__c WHERE Cert_Expiry__c <= :alertDate AND Cert_Expiry__c >= :Date.today() AND Is_Active__c = true]);
    }
    public void execute(Database.BatchableContext bc, List<Technician_Skill__c> skills) {
        List<Task> tasks = new List<Task>();
        for (Technician_Skill__c ts : skills) {
            tasks.add(new Task(Subject = 'Cert Expiry: ' + ts.Skill__r.Skill_Name__c + ' for ' + ts.Technician__r.Name,
                ActivityDate = Date.today(), Status = 'Open', Priority = 'High',
                Description = 'Certification expires on ' + ts.Cert_Expiry__c.format() + '. Please arrange renewal.'));
        }
        if (!tasks.isEmpty()) insert tasks;
    }
    public void finish(Database.BatchableContext bc) { }
}
