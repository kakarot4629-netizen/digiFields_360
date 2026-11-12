public with sharing class DF360_PartsController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> searchParts(String searchTerm, String category) {
        String likeVal = '%' + String.escapeSingleQuotes(searchTerm == null ? '' : searchTerm) + '%';
        String soql = 'SELECT Id, Name, Part_Code__c, Category__c, Unit_Cost__c, Is_Warranty_Item__c, Is_Active__c ' +
            'FROM Part__c WHERE Is_Active__c = true AND ' +
            '(Name LIKE :likeVal OR Part_Code__c LIKE :likeVal)';
        if (String.isNotBlank(category)) soql += ' AND Category__c = \'' + String.escapeSingleQuotes(category) + '\'';
        soql += ' ORDER BY Name ASC LIMIT 200';
        List<Part__c> parts = Database.query(soql);
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (Part__c p : parts) {
            result.add(new Map<String,Object>{ 'id'=> p.Id, 'name'=> p.Name,
                'code'=> p.Part_Code__c, 'category'=> p.Category__c,
                'cost'=> p.Unit_Cost__c, 'isWarranty'=> p.Is_Warranty_Item__c });
        }
        return result;
    }

    @AuraEnabled
    public static Id raisePartsRequest(Id jobId, Id partId, Integer qty) {
        Part__c part = [SELECT Unit_Cost__c, Is_Warranty_Item__c FROM Part__c WHERE Id = :partId LIMIT 1];
        Parts_Request__c req = new Parts_Request__c(
            Service_Job__c = jobId,
            Part__c = partId,
            Quantity__c = qty,
            Is_Warranty__c = part.Is_Warranty_Item__c,
            Status__c = (part.Unit_Cost__c != null && part.Unit_Cost__c * qty > 5000)
                ? 'Pending Approval' : 'Approved'
        );
        insert req;
        if (req.Status__c == 'Approved') {
            // Update job status and reserve stock
            reserveStock(partId, qty);
        }
        return req.Id;
    }

    @AuraEnabled
    public static void approveRequest(Id requestId, Boolean approved, String reason) {
        Parts_Request__c req = [SELECT Part__c, Quantity__c FROM Parts_Request__c WHERE Id = :requestId LIMIT 1];
        update new Parts_Request__c(
            Id = requestId,
            Status__c = approved ? 'Approved' : 'Rejected',
            Approved_By__c = UserInfo.getUserId(),
            Approved_At__c = DateTime.now(),
            Rejection_Reason__c = approved ? null : reason
        );
        if (approved) reserveStock(req.Part__c, (Integer)req.Quantity__c);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> getPendingApprovals() {
        List<Parts_Request__c> reqs = [
            SELECT Id, Name, Status__c, Part__c, Part__r.Name, Part__r.Unit_Cost__c,
                   Quantity__c, Service_Job__c, Service_Job__r.Name, Technician__c,
                   Technician__r.Name, CreatedDate
            FROM Parts_Request__c WHERE Status__c = 'Pending Approval'
            ORDER BY CreatedDate ASC LIMIT 100
        ];
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (Parts_Request__c r : reqs) {
            Decimal totalCost = (r.Part__r.Unit_Cost__c == null ? 0 : r.Part__r.Unit_Cost__c) * r.Quantity__c;
            result.add(new Map<String,Object>{ 'id'=> r.Id, 'partName'=> r.Part__r.Name,
                'qty'=> r.Quantity__c, 'totalCost'=> totalCost,
                'jobName'=> r.Service_Job__r.Name, 'techName'=> r.Technician__r?.Name,
                'requestedDate'=> r.CreatedDate });
        }
        return result;
    }

    private static void reserveStock(Id partId, Integer qty) {
        List<Parts_Stock__c> stocks = [
            SELECT Id, Quantity_Available__c, Quantity_Reserved__c
            FROM Parts_Stock__c WHERE Part__c = :partId AND Quantity_Available__c > 0
            ORDER BY Quantity_Available__c DESC LIMIT 1
        ];
        if (!stocks.isEmpty()) {
            stocks[0].Quantity_Reserved__c = (stocks[0].Quantity_Reserved__c == null ? 0 : stocks[0].Quantity_Reserved__c) + qty;
            update stocks[0];
        }
    }
}
