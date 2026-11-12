/**
 * @description Handler for DF360_AssetFeedbackTrigger
 * Automatically synchronizes relationships between Case Assets (Work_Order_Line_Item__c),
 * Actual Assets (Asset__c), Work Orders, and Cases.
 */
public with sharing class DF360_AssetFeedbackHandler {

    public static void handleBeforeInsert(List<Asset_Feedback__c> newRecords) {
        syncRelationships(newRecords, null);
    }

    public static void handleBeforeUpdate(List<Asset_Feedback__c> newRecords, Map<Id, Asset_Feedback__c> oldMap) {
        syncRelationships(newRecords, oldMap);
    }

    private static void syncRelationships(List<Asset_Feedback__c> records, Map<Id, Asset_Feedback__c> oldMap) {
        Set<Id> lineItemIds = new Set<Id>();
        Set<Id> workOrderIds = new Set<Id>();
        Set<Id> assetIds = new Set<Id>();

        for (Asset_Feedback__c afb : records) {
            Boolean lineItemChanged = (oldMap == null || afb.Work_Order_Line_Item__c != oldMap.get(afb.Id).Work_Order_Line_Item__c);
            Boolean assetChanged = (oldMap == null || afb.Asset__c != oldMap.get(afb.Id).Asset__c);
            Boolean woChanged = (oldMap == null || afb.Work_Order__c != oldMap.get(afb.Id).Work_Order__c);

            if (afb.Work_Order_Line_Item__c != null && lineItemChanged) {
                lineItemIds.add(afb.Work_Order_Line_Item__c);
            }
            if (afb.Work_Order_Line_Item__c == null && afb.Work_Order__c != null && afb.Asset__c != null && (assetChanged || woChanged)) {
                workOrderIds.add(afb.Work_Order__c);
                assetIds.add(afb.Asset__c);
            }
        }

        // Map Case Assets (Work_Order_Line_Item__c)
        Map<Id, Work_Order_Line_Item__c> lineItemMap = new Map<Id, Work_Order_Line_Item__c>();
        if (!lineItemIds.isEmpty()) {
            lineItemMap = new Map<Id, Work_Order_Line_Item__c>([
                SELECT Id, Asset__c, Work_Order__c, Work_Order__r.Case__c
                FROM Work_Order_Line_Item__c
                WHERE Id IN :lineItemIds
            ]);
        }

        // Map reverse matching: WorkOrder + Asset -> Case Asset (Work_Order_Line_Item__c)
        Map<String, Id> woAssetToLineItemId = new Map<String, Id>();
        if (!workOrderIds.isEmpty() && !assetIds.isEmpty()) {
            for (Work_Order_Line_Item__c woli : [
                SELECT Id, Asset__c, Work_Order__c
                FROM Work_Order_Line_Item__c
                WHERE Work_Order__c IN :workOrderIds AND Asset__c IN :assetIds
            ]) {
                woAssetToLineItemId.put(woli.Work_Order__c + '_' + woli.Asset__c, woli.Id);
            }
        }

        // Optional default current logged-in technician
        Id currentTechId = null;
        List<Technician__c> currentTechs = [
            SELECT Id FROM Technician__c WHERE User__c = :UserInfo.getUserId() LIMIT 1
        ];
        if (!currentTechs.isEmpty()) {
            currentTechId = currentTechs[0].Id;
        }

        for (Asset_Feedback__c afb : records) {
            // Case 1: Case Asset (Work_Order_Line_Item__c) is selected -> Auto-fill Actual Asset, Work Order, Case
            if (afb.Work_Order_Line_Item__c != null && lineItemMap.containsKey(afb.Work_Order_Line_Item__c)) {
                Work_Order_Line_Item__c woli = lineItemMap.get(afb.Work_Order_Line_Item__c);
                if (woli.Asset__c != null) {
                    afb.Asset__c = woli.Asset__c;
                }
                if (afb.Work_Order__c == null && woli.Work_Order__c != null) {
                    afb.Work_Order__c = woli.Work_Order__c;
                }
                if (afb.Case__c == null && woli.Work_Order__r != null && woli.Work_Order__r.Case__c != null) {
                    afb.Case__c = woli.Work_Order__r.Case__c;
                }
            }
            // Case 2: Work Order and Actual Asset selected -> Auto-match Case Asset if empty
            else if (afb.Work_Order_Line_Item__c == null && afb.Work_Order__c != null && afb.Asset__c != null) {
                String key = afb.Work_Order__c + '_' + afb.Asset__c;
                if (woAssetToLineItemId.containsKey(key)) {
                    afb.Work_Order_Line_Item__c = woAssetToLineItemId.get(key);
                }
            }

            // Default Technician if not provided
            if (afb.Technician__c == null && currentTechId != null) {
                afb.Technician__c = currentTechId;
            }
        }
    }
}
