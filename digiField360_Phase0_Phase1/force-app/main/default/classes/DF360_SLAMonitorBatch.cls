public class DF360_SLAMonitorBatch implements Database.Batchable<SObject>, Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new DF360_SLAMonitorBatch(), 200);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, SLA_Deadline__c, SLA_Status__c, Priority__c,
                   Technician__c, Technician__r.User__c, Zone__c
            FROM Service_Job__c
            WHERE Status__c NOT IN ('Completed','Cancelled')
              AND SLA_Deadline__c != null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Service_Job__c> jobs) {
        List<Service_Job__c> toUpdate = new List<Service_Job__c>();
        List<SLA_Event__c> events = new List<SLA_Event__c>();

        for (Service_Job__c job : jobs) {
            Long diffMs = job.SLA_Deadline__c.getTime() - DateTime.now().getTime();
            Decimal remHrs = (Decimal.valueOf(diffMs) / 3600000).setScale(2);
            String newStatus;
            String eventType = null;
            String alertNote = null;

            if (remHrs < 0) {
                newStatus = 'Breached';
                eventType = 'Breached';
                alertNote = 'SLA breached. Immediate escalation required.';
            } else if (remHrs < 1) {
                newStatus = 'Red';
                eventType = 'Escalated';
                alertNote = 'SLA at risk: ' + remHrs.setScale(1) + ' hours remaining.';
            } else if (remHrs < 2) {
                newStatus = 'Amber';
                alertNote = 'SLA warning: ' + remHrs.setScale(1) + ' hours remaining.';
            } else {
                newStatus = 'Green';
            }

            if (newStatus != job.SLA_Status__c) {
                toUpdate.add(new Service_Job__c(Id = job.Id, SLA_Status__c = newStatus));
            }
            if (eventType != null) {
                events.add(new SLA_Event__c(
                    Service_Job__c = job.Id,
                    Event_Type__c = eventType,
                    Event_Timestamp__c = DateTime.now(),
                    SLA_Remaining_Hrs__c = remHrs,
                    Notes__c = alertNote
                ));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
        if (!events.isEmpty()) insert events;
    }

    public void finish(Database.BatchableContext bc) { }
}
