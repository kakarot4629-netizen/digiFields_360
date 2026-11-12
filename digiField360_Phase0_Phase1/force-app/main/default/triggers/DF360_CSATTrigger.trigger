trigger DF360_CSATTrigger on CSAT__c (after insert, after update) {
    if (Trigger.isAfter) {
        for (CSAT__c csat : Trigger.new) {
            CSAT__c old = Trigger.isUpdate ? Trigger.oldMap.get(csat.Id) : null;
            Boolean justResponded = csat.Is_Responded__c && (old == null || !old.Is_Responded__c);
            if (justResponded && csat.Rating__c != null && csat.Rating__c <= 2 && !csat.Alert_Sent__c) {
                DF360_CSATTriggerHelper.sendLowCSATAlert(csat.Id, csat.Service_Job__c, (Integer)csat.Rating__c);
            }
        }
    }
}
