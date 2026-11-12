/**
 * @description Trigger on Asset_Feedback__c to maintain synchronized relationships
 * with Case Assets (Work_Order_Line_Item__c), Actual Assets (Asset__c), Work Orders, and Cases.
 */
trigger DF360_AssetFeedbackTrigger on Asset_Feedback__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            DF360_AssetFeedbackHandler.handleBeforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            DF360_AssetFeedbackHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
