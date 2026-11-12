trigger DF360_AssignedResourceTrigger on Assigned_Resource__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            DF360_AssignedResourceTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            DF360_AssignedResourceTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
