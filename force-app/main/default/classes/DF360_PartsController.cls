public with sharing class DF360_PartsController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> searchParts(String searchTerm, String category) {
        String likeVal = '%' + String.escapeSingleQuotes(searchTerm == null ? '' : searchTerm) + '%';
        String soql = 'SELECT Id, Name, Part_Code__c, Category__c, Unit_Cost__c, Is_Warranty_Item__c, Is_Active__c ' +
            'FROM Part__c WHERE Is_Active__c = true AND ' +
            '(Name LIKE :likeVal OR Part_Code__c LIKE :likeVal)';
        if (String.isNotBlank(category)) {
            soql += ' AND Category__c = \'' + String.escapeSingleQuotes(category) + '\'';
        }
        soql += ' ORDER BY Name ASC LIMIT 200';
        List<Part__c> parts = Database.query(soql);
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (Part__c p : parts) {
            result.add(new Map<String,Object>{ 
                'id' => p.Id, 
                'name' => p.Name,
                'code' => p.Part_Code__c, 
                'category' => p.Category__c,
                'cost' => p.Unit_Cost__c, 
                'isWarranty' => p.Is_Warranty_Item__c 
            });
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getApplicablePartsForWorkOrder(Id workOrderId, String searchTerm) {
        if (workOrderId == null) {
            throw new AuraHandledException('Work Order ID is required.');
        }

        String sObjName = workOrderId.getSobjectType().getDescribe().getName();
        String assetCategory = null;
        String assetModel = null;
        String assetName = 'Equipment';
        String recordNumber = '';

        if (sObjName == 'Work_Order__c') {
            Work_Order__c wo = [
                SELECT Id, Name, Equipment_Type__c, Asset__c,
                       Asset__r.Name, Asset__r.Model__c, Asset__r.Product_Category__c
                FROM Work_Order__c
                WHERE Id = :workOrderId
                LIMIT 1
            ];
            recordNumber = wo.Name;
            assetCategory = wo.Asset__c != null ? wo.Asset__r.Product_Category__c : wo.Equipment_Type__c;
            assetModel = wo.Asset__c != null ? wo.Asset__r.Model__c : null;
            assetName = wo.Asset__r != null ? wo.Asset__r.Name : 'Equipment';
        } else if (sObjName == 'Service_Job__c') {
            Service_Job__c sj = [
                SELECT Id, Name, Product_Category__c, Asset__c,
                       Asset__r.Name, Asset__r.Model__c, Asset__r.Product_Category__c
                FROM Service_Job__c
                WHERE Id = :workOrderId
                LIMIT 1
            ];
            recordNumber = sj.Name;
            assetCategory = sj.Asset__c != null ? sj.Asset__r.Product_Category__c : sj.Product_Category__c;
            assetModel = sj.Asset__c != null ? sj.Asset__r.Model__c : null;
            assetName = sj.Asset__r != null ? sj.Asset__r.Name : 'Equipment';
        }

        String likeSearch = '%' + String.escapeSingleQuotes(searchTerm == null ? '' : searchTerm) + '%';
        String soql = 'SELECT Id, Name, Part_Code__c, Category__c, Unit_Cost__c, Is_Warranty_Item__c, Is_Active__c, Compatible_Products__c ' +
                      'FROM Part__c WHERE Is_Active__c = true';

        if (String.isNotBlank(searchTerm)) {
            soql += ' AND (Name LIKE :likeSearch OR Part_Code__c LIKE :likeSearch)';
        }

        // Apply intelligent category / model filtering
        if (String.isNotBlank(assetCategory)) {
            soql += ' AND Category__c = :assetCategory';
        }

        soql += ' ORDER BY Name ASC LIMIT 100';
        List<Part__c> parts = Database.query(soql);

        // If category filter returned very few or no results, fallback to general catalogue
        if (parts.isEmpty()) {
            String fallbackSoql = 'SELECT Id, Name, Part_Code__c, Category__c, Unit_Cost__c, Is_Warranty_Item__c, Is_Active__c, Compatible_Products__c ' +
                                  'FROM Part__c WHERE Is_Active__c = true';
            if (String.isNotBlank(searchTerm)) {
                fallbackSoql += ' AND (Name LIKE :likeSearch OR Part_Code__c LIKE :likeSearch)';
            }
            fallbackSoql += ' ORDER BY Name ASC LIMIT 50';
            parts = Database.query(fallbackSoql);
        }

        List<Map<String, Object>> partsList = new List<Map<String, Object>>();
        for (Part__c p : parts) {
            Boolean isDirectCompatible = true;
            if (String.isNotBlank(assetModel) && String.isNotBlank(p.Compatible_Products__c)) {
                isDirectCompatible = p.Compatible_Products__c.containsIgnoreCase(assetModel);
            }

            partsList.add(new Map<String, Object>{
                'id' => p.Id,
                'name' => p.Name,
                'code' => p.Part_Code__c,
                'category' => p.Category__c,
                'cost' => p.Unit_Cost__c,
                'isWarranty' => p.Is_Warranty_Item__c,
                'isDirectCompatible' => isDirectCompatible
            });
        }

        return new Map<String, Object>{
            'workOrderId' => workOrderId,
            'workOrderNumber' => recordNumber,
            'assetName' => assetName,
            'assetModel' => assetModel,
            'assetCategory' => assetCategory,
            'parts' => partsList
        };
    }

    @AuraEnabled
    public static Id raisePartsRequestForWorkOrder(Id workOrderId, Id partId, Integer qty) {
        if (workOrderId == null || partId == null || qty == null || qty <= 0) {
            throw new AuraHandledException('Invalid Work Order, Part, or Quantity.');
        }

        String sObjName = workOrderId.getSobjectType().getDescribe().getName();
        Part__c part = [SELECT Unit_Cost__c, Is_Warranty_Item__c FROM Part__c WHERE Id = :partId LIMIT 1];
        Boolean isAutoApproved = (part.Unit_Cost__c == null || (part.Unit_Cost__c * qty <= 5000 && part.Is_Warranty_Item__c));

        Id techRecordId = null;
        Parts_Request__c req = new Parts_Request__c(
            Part__c = partId,
            Quantity__c = qty,
            Is_Warranty__c = part.Is_Warranty_Item__c,
            Status__c = isAutoApproved ? 'Approved' : 'Pending Approval'
        );

        if (sObjName == 'Work_Order__c') {
            Work_Order__c wo = [SELECT Id, Asset__c, Assigned_Technician__c FROM Work_Order__c WHERE Id = :workOrderId LIMIT 1];
            req.Work_Order__c = workOrderId;
            // Resolve Technician__c custom record from Assigned_Technician__c (User ID)
            if (wo.Assigned_Technician__c != null) {
                List<Technician__c> techs = [SELECT Id FROM Technician__c WHERE User__c = :wo.Assigned_Technician__c LIMIT 1];
                if (!techs.isEmpty()) {
                    techRecordId = techs[0].Id;
                }
            }
        } else if (sObjName == 'Service_Job__c') {
            Service_Job__c sj = [SELECT Id, Asset__c, Technician__c FROM Service_Job__c WHERE Id = :workOrderId LIMIT 1];
            req.Service_Job__c = workOrderId;
            techRecordId = sj.Technician__c;
        }

        // Fallback: check if the current user running the request is a Technician
        if (techRecordId == null) {
            List<Technician__c> currentTechs = [SELECT Id FROM Technician__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];
            if (!currentTechs.isEmpty()) {
                techRecordId = currentTechs[0].Id;
            }
        }

        req.Technician__c = techRecordId;
        insert req;

        if (req.Status__c == 'Approved') {
            reserveStock(partId, qty);
        }
        return req.Id;
    }

    @AuraEnabled
    public static void issuePart(Id requestId) {
        Parts_Request__c req = [
            SELECT Id, Status__c, Part__c, Part__r.Name, Quantity__c, Work_Order__c
            FROM Parts_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];
        req.Status__c = 'Part Issued';
        update req;

        // If parent Work Order is Temporarily Paused waiting for part, notify assigned technician
        if (req.Work_Order__c != null) {
            List<Work_Order__c> wos = [
                SELECT Id, Name, Status__c, Current_Pause_Reason__c, Assigned_Technician__c
                FROM Work_Order__c
                WHERE Id = :req.Work_Order__c
                LIMIT 1
            ];
            if (!wos.isEmpty() && wos[0].Status__c == 'Temporarily Paused' && wos[0].Current_Pause_Reason__c == 'Waiting for Part') {
                if (wos[0].Assigned_Technician__c != null) {
                    try {
                        Task reminder = new Task(
                            Subject = 'Action Required: Part Issued for Paused Work Order ' + wos[0].Name,
                            Description = 'Requested part (' + (req.Part__r != null ? req.Part__r.Name : 'Spare Part') + ') has been issued from inventory depot. Please resume work on site.',
                            WhatId = wos[0].Id,
                            OwnerId = wos[0].Assigned_Technician__c,
                            Priority = 'High',
                            Status = 'Not Started',
                            ActivityDate = Date.today()
                        );
                        insert reminder;
                    } catch (Exception ex) {
                        System.debug('Task reminder error: ' + ex.getMessage());
                    }
                }
            }
        }
    }

    @AuraEnabled
    public static void consumePart(Id requestId, Id workOrderId) {
        Parts_Request__c req = [
            SELECT Id, Status__c, Part__c, Part__r.Name, Part__r.Part_Code__c, Quantity__c, Work_Order__c
            FROM Parts_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];

        req.Status__c = 'Consumed';
        update req;

        // Deduct from stock
        if (req.Part__c != null && req.Quantity__c != null) {
            List<Parts_Stock__c> stocks = [
                SELECT Id, Quantity_Available__c, Quantity_Reserved__c
                FROM Parts_Stock__c
                WHERE Part__c = :req.Part__c AND Quantity_Available__c > 0
                LIMIT 1
            ];
            if (!stocks.isEmpty()) {
                stocks[0].Quantity_Available__c = Math.max(0, stocks[0].Quantity_Available__c - req.Quantity__c);
                if (stocks[0].Quantity_Reserved__c != null) {
                    stocks[0].Quantity_Reserved__c = Math.max(0, stocks[0].Quantity_Reserved__c - req.Quantity__c);
                }
                update stocks[0];
            }
        }

        // Update Work Order parts consumed text
        Id targetWoId = workOrderId != null ? workOrderId : req.Work_Order__c;
        if (targetWoId != null && targetWoId.getSobjectType().getDescribe().getName() == 'Work_Order__c') {
            Work_Order__c wo = [SELECT Id, Parts_Used__c FROM Work_Order__c WHERE Id = :targetWoId LIMIT 1];
            String newEntry = req.Part__r.Name + ' (' + req.Quantity__c + 'x)';
            wo.Parts_Used__c = String.isBlank(wo.Parts_Used__c) ? newEntry : (wo.Parts_Used__c + ', ' + newEntry);
            update wo;
        }
    }

    @AuraEnabled
    public static void returnPart(Id requestId, String reason) {
        Parts_Request__c req = [
            SELECT Id, Status__c, Part__c, Quantity__c, Rejection_Reason__c
            FROM Parts_Request__c
            WHERE Id = :requestId
            LIMIT 1
        ];

        req.Status__c = 'Returned';
        req.Rejection_Reason__c = String.isNotBlank(reason) ? ('Return: ' + reason) : 'Returned unused to inventory';
        update req;

        // Release reserved stock back if it was reserved
        if (req.Part__c != null && req.Quantity__c != null) {
            List<Parts_Stock__c> stocks = [
                SELECT Id, Quantity_Available__c, Quantity_Reserved__c
                FROM Parts_Stock__c
                WHERE Part__c = :req.Part__c
                LIMIT 1
            ];
            if (!stocks.isEmpty()) {
                if (stocks[0].Quantity_Reserved__c != null && stocks[0].Quantity_Reserved__c >= req.Quantity__c) {
                    stocks[0].Quantity_Reserved__c = stocks[0].Quantity_Reserved__c - req.Quantity__c;
                    update stocks[0];
                }
            }
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getWorkOrderPartsRequests(Id workOrderId) {
        if (workOrderId == null) return new List<Map<String, Object>>();
        String sObjName = workOrderId.getSobjectType().getDescribe().getName();
        List<Parts_Request__c> reqs = new List<Parts_Request__c>();
        if (sObjName == 'Work_Order__c') {
            reqs = [
                SELECT Id, Name, Status__c, Part__c, Part__r.Name, Part__r.Part_Code__c,
                       Part__r.Unit_Cost__c, Quantity__c, CreatedDate
                FROM Parts_Request__c
                WHERE Work_Order__c = :workOrderId
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        } else if (sObjName == 'Service_Job__c') {
            reqs = [
                SELECT Id, Name, Status__c, Part__c, Part__r.Name, Part__r.Part_Code__c,
                       Part__r.Unit_Cost__c, Quantity__c, CreatedDate
                FROM Parts_Request__c
                WHERE Service_Job__c = :workOrderId
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        }

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Parts_Request__c r : reqs) {
            Decimal cost = (r.Part__r.Unit_Cost__c == null ? 0 : r.Part__r.Unit_Cost__c) * (r.Quantity__c != null ? r.Quantity__c : 1);
            result.add(new Map<String, Object>{
                'id' => r.Id,
                'name' => r.Name,
                'partName' => r.Part__r.Name,
                'partCode' => r.Part__r.Part_Code__c,
                'qty' => r.Quantity__c,
                'status' => r.Status__c,
                'totalCost' => cost,
                'createdDate' => r.CreatedDate
            });
        }
        return result;
    }

    @AuraEnabled
    public static Id raisePartsRequest(Id jobId, Id partId, Integer qty) {
        if (jobId == null || partId == null || qty == null || qty <= 0) {
            throw new AuraHandledException('Invalid Record, Part, or Quantity.');
        }

        String sObjName = jobId.getSobjectType().getDescribe().getName();
        if (sObjName == 'Work_Order__c') {
            return raisePartsRequestForWorkOrder(jobId, partId, qty);
        }

        Part__c part = [SELECT Unit_Cost__c, Is_Warranty_Item__c FROM Part__c WHERE Id = :partId LIMIT 1];

        Id techRecordId = null;
        List<Service_Job__c> sjList = [SELECT Id, Technician__c FROM Service_Job__c WHERE Id = :jobId LIMIT 1];
        if (!sjList.isEmpty()) {
            techRecordId = sjList[0].Technician__c;
        }
        if (techRecordId == null) {
            List<Technician__c> currentTechs = [SELECT Id FROM Technician__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];
            if (!currentTechs.isEmpty()) {
                techRecordId = currentTechs[0].Id;
            }
        }

        Parts_Request__c req = new Parts_Request__c(
            Service_Job__c = jobId,
            Technician__c = techRecordId,
            Part__c = partId,
            Quantity__c = qty,
            Is_Warranty__c = part.Is_Warranty_Item__c,
            Status__c = (part.Unit_Cost__c != null && part.Unit_Cost__c * qty > 5000)
                ? 'Pending Approval' : 'Approved'
        );
        insert req;
        if (req.Status__c == 'Approved') {
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
        if (approved && req.Part__c != null && req.Quantity__c != null) {
            reserveStock(req.Part__c, req.Quantity__c.intValue());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> getPendingApprovals() {
        List<Parts_Request__c> reqs = [
            SELECT Id, Name, Status__c, Part__c, Part__r.Name, Part__r.Unit_Cost__c,
                   Quantity__c, Service_Job__c, Service_Job__r.Name, Work_Order__c,
                   Work_Order__r.Name, Technician__c, Technician__r.Name, CreatedDate
            FROM Parts_Request__c WHERE Status__c = 'Pending Approval'
            ORDER BY CreatedDate ASC LIMIT 100
        ];
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (Parts_Request__c r : reqs) {
            Decimal totalCost = (r.Part__r.Unit_Cost__c == null ? 0 : r.Part__r.Unit_Cost__c) * (r.Quantity__c != null ? r.Quantity__c : 1);
            String relatedJobName = r.Work_Order__r != null ? r.Work_Order__r.Name : (r.Service_Job__r != null ? r.Service_Job__r.Name : '');
            result.add(new Map<String,Object>{ 
                'id' => r.Id, 
                'partName' => r.Part__r.Name,
                'qty' => r.Quantity__c, 
                'totalCost' => totalCost,
                'jobName' => relatedJobName, 
                'techName' => r.Technician__r != null ? r.Technician__r.Name : '',
                'requestedDate' => r.CreatedDate 
            });
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
