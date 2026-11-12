/**
 * FIELD360 AI — Invocable Action: Asset 360 & Service History Query
 *
 * Called by Agentforce agent when users ask about asset specifications,
 * warranty coverage, and previous repair histories.
 */
public with sharing class DF360_AssetHistoryInvocableAction {

    public class AssetHistoryRequest {
        @InvocableVariable(label='Asset ID' description='The ID of the Asset__c record')
        public Id assetId;

        @InvocableVariable(label='Work Order ID' description='Work Order ID linked to the asset')
        public Id workOrderId;

        @InvocableVariable(label='Serial Number' description='Asset OEM Serial Number')
        public String serialNumber;
    }

    public class AssetHistoryResult {
        @InvocableVariable(label='Asset Summary')
        public String assetSummary;

        @InvocableVariable(label='Warranty Status')
        public String warrantyStatus;

        @InvocableVariable(label='Specifications')
        public String specifications;

        @InvocableVariable(label='Past Service History')
        public String pastServiceHistory;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Query Asset 360 & History'
        description='Gathers asset profile, warranty expiration, specifications, and previous service history for Agentforce.'
        category='Field360 AI'
    )
    public static List<AssetHistoryResult> queryAssetHistory(List<AssetHistoryRequest> requests) {
        List<AssetHistoryResult> results = new List<AssetHistoryResult>();

        for (AssetHistoryRequest req : requests) {
            AssetHistoryResult res = new AssetHistoryResult();
            try {
                Id targetAssetId = req.assetId;

                // Resolve from Work Order if not provided directly
                if (targetAssetId == null && req.workOrderId != null) {
                    List<Work_Order__c> wos = [SELECT Asset__c FROM Work_Order__c WHERE Id = :req.workOrderId LIMIT 1];
                    if (!wos.isEmpty()) {
                        targetAssetId = wos[0].Asset__c;
                    }
                }

                // Resolve from Serial Number if not provided
                if (targetAssetId == null && String.isNotBlank(req.serialNumber)) {
                    List<Asset__c> assets = [SELECT Id FROM Asset__c WHERE Serial_Number__c = :req.serialNumber LIMIT 1];
                    if (!assets.isEmpty()) {
                        targetAssetId = assets[0].Id;
                    }
                }

                if (targetAssetId == null) {
                    res.success = false;
                    res.errorMessage = 'No matching asset found. Please provide Asset ID, Work Order ID, or Serial Number.';
                    results.add(res);
                    continue;
                }

                Map<String, Object> details = DF360_WorkOrderAssetController.getAsset360Details(targetAssetId, req.workOrderId);
                Asset__c ast = (Asset__c) details.get('asset');
                List<Work_Order__c> pastWos = (List<Work_Order__c>) details.get('pastWorkOrders');
                List<Job_History__c> jhs = (List<Job_History__c>) details.get('jobHistories');

                res.assetSummary = (ast.Product_Name__c != null ? ast.Product_Name__c : ast.Name) + 
                    ' (Model: ' + (ast.Model__c != null ? ast.Model__c : 'N/A') + 
                    ', Serial: ' + ast.Serial_Number__c + 
                    ', Mfg: ' + (ast.Manufacturer__c != null ? ast.Manufacturer__c : 'OEM') + 
                    ', Location: ' + (ast.Location_Address__c != null ? ast.Location_Address__c : 'Site') + ')';

                Boolean isWarranty = (ast.Warranty_Expiry__c != null && ast.Warranty_Expiry__c >= Date.today());
                res.warrantyStatus = isWarranty 
                    ? ('Active Warranty (Expires: ' + ast.Warranty_Expiry__c.format() + ')')
                    : ('Out of Warranty (Expired: ' + (ast.Warranty_Expiry__c != null ? ast.Warranty_Expiry__c.format() : 'N/A') + ')');

                res.specifications = String.isNotBlank(ast.Specifications__c) ? ast.Specifications__c : 'Standard operating specifications.';

                String histText = '';
                if (pastWos != null && !pastWos.isEmpty()) {
                    histText += 'PAST WORK ORDERS (' + pastWos.size() + '):\n';
                    for (Work_Order__c w : pastWos) {
                        histText += '- ' + w.Name + ': ' + w.Subject__c + ' [' + w.Status__c + '] Parts: ' + (w.Parts_Used__c != null ? w.Parts_Used__c : 'None') + '\n';
                    }
                }
                if (jhs != null && !jhs.isEmpty()) {
                    histText += '\nDIAGNOSTIC HISTORY RECORDS:\n';
                    for (Job_History__c j : jhs) {
                        histText += '- ' + (j.Job_Date__c != null ? j.Job_Date__c.format() : '') + ': ' + j.Fault_Description__c + ' -> Fixed: ' + j.Resolution__c + '\n';
                    }
                }
                if (String.isBlank(histText)) {
                    histText = 'No previous service records logged for this asset.';
                }
                res.pastServiceHistory = histText;
                res.success = true;

            } catch (Exception ex) {
                res.success = false;
                res.errorMessage = ex.getMessage();
            }
            results.add(res);
        }
        return results;
    }
}
