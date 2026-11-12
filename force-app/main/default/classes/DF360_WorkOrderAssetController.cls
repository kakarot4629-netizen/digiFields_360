public with sharing class DF360_WorkOrderAssetController {

    @AuraEnabled
    public static Map<String, Object> associateAsset(Id workOrderId, Id assetId) {
        if (workOrderId == null || assetId == null) {
            throw new AuraHandledException('Work Order ID and Asset ID are required.');
        }

        Asset__c asset = [
            SELECT Id, Name, Serial_Number__c, Model__c, Manufacturer__c,
                   Product_Category__c, Product_Name__c, Location_Address__c,
                   Account__c, Warranty_Expiry__c, Is_Under_Warranty__c, Status__c
            FROM Asset__c
            WHERE Id = :assetId
            LIMIT 1
        ];

        Work_Order__c wo = [
            SELECT Id, Name, Subject__c, Site_Address__c, Account__c, Equipment_ID__c, Equipment_Type__c
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        wo.Asset__c = asset.Id;
        wo.Equipment_ID__c = String.isNotBlank(asset.Serial_Number__c) ? asset.Serial_Number__c : asset.Name;
        if (String.isNotBlank(asset.Product_Category__c)) {
            wo.Equipment_Type__c = asset.Product_Category__c;
        }
        if (String.isNotBlank(asset.Location_Address__c) && String.isBlank(wo.Site_Address__c)) {
            wo.Site_Address__c = asset.Location_Address__c;
        }
        if (asset.Account__c != null && wo.Account__c == null) {
            wo.Account__c = asset.Account__c;
        }

        update wo;

        return getAsset360Details(assetId, workOrderId);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAsset360Details(Id assetId, Id workOrderId) {
        if (assetId == null && workOrderId != null) {
            List<Work_Order__c> wos = [SELECT Asset__c FROM Work_Order__c WHERE Id = :workOrderId LIMIT 1];
            if (!wos.isEmpty()) {
                assetId = wos[0].Asset__c;
            }
        }

        if (assetId == null) {
            return new Map<String, Object>{ 'success' => false, 'message' => 'No asset linked.' };
        }

        Asset__c asset = [
            SELECT Id, Name, Serial_Number__c, Model__c, Manufacturer__c,
                   Product_Category__c, Product_Name__c, Install_Date__c,
                   Warranty_Expiry__c, Is_Under_Warranty__c, Last_Service_Date__c,
                   Visit_Count_30d__c, Location_Address__c, Status__c,
                   Specifications__c, Account__c, Account__r.Name, Zone__c, Zone__r.Name
            FROM Asset__c
            WHERE Id = :assetId
            LIMIT 1
        ];

        // Fetch past Work Orders on this Asset
        List<Work_Order__c> pastWorkOrders = [
            SELECT Id, Name, Subject__c, Status__c, Priority__c, Scheduled_Date__c,
                   Completed_Date__c, Assigned_Technician__r.Name, Parts_Used__c,
                   Description__c, Technician_Notes__c
            FROM Work_Order__c
            WHERE Asset__c = :assetId
            ORDER BY CreatedDate DESC
            LIMIT 25
        ];

        // Fetch past Job History entries for this Asset / Serial Number
        String serial = asset.Serial_Number__c;
        List<Job_History__c> jobHistories = new List<Job_History__c>();
        if (String.isNotBlank(serial)) {
            jobHistories = [
                SELECT Id, Name, Job_Date__c, Fault_Description__c, Resolution__c,
                       Parts_Used__c, Root_Cause__c, First_Time_Fix__c,
                       Duration_Minutes__c, Customer_Satisfaction__c, Technician__r.Name
                FROM Job_History__c
                WHERE Equipment_ID__c = :serial
                ORDER BY Job_Date__c DESC
                LIMIT 25
            ];
        }

        // Fetch parts consumed on this asset
        List<Parts_Request__c> partsRequests = [
            SELECT Id, Name, Part__c, Part__r.Name, Part__r.Part_Code__c,
                   Quantity__c, Status__c, CreatedDate
            FROM Parts_Request__c
            WHERE (Work_Order__c IN :pastWorkOrders OR Service_Job__r.Asset__c = :assetId)
            ORDER BY CreatedDate DESC
            LIMIT 30
        ];

        // Fetch attached manuals / documents
        List<ContentDocumentLink> docLinks = [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension,
                   ContentDocument.ContentSize, ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :assetId
            LIMIT 15
        ];

        List<Map<String, Object>> documents = new List<Map<String, Object>>();
        for (ContentDocumentLink cdl : docLinks) {
            documents.add(new Map<String, Object>{
                'id' => cdl.ContentDocumentId,
                'title' => cdl.ContentDocument.Title,
                'extension' => cdl.ContentDocument.FileExtension,
                'size' => cdl.ContentDocument.ContentSize,
                'createdDate' => cdl.ContentDocument.CreatedDate
            });
        }

        // Fetch asset feedbacks across Asset, Case, and Work Order
        List<Asset_Feedback__c> assetFeedbacks = [
            SELECT Id, Name, Feedback_Type__c, Operational_Status__c, Asset_Condition__c,
                   Rating__c, Feedback_Notes__c, Recommended_Action__c,
                   Work_Order__c, Work_Order__r.Name, Case__c, Case__r.CaseNumber,
                   Technician__c, Technician__r.Name, Pre_Service_Photo_URL__c, Post_Service_Photo_URL__c, CreatedDate
            FROM Asset_Feedback__c
            WHERE Asset__c = :assetId
            ORDER BY CreatedDate DESC
            LIMIT 25
        ];

        return new Map<String, Object>{
            'success' => true,
            'asset' => asset,
            'pastWorkOrders' => pastWorkOrders,
            'jobHistories' => jobHistories,
            'partsRequests' => partsRequests,
            'documents' => documents,
            'assetFeedbacks' => assetFeedbacks,
            'isUnderWarranty' => (asset.Warranty_Expiry__c != null && asset.Warranty_Expiry__c >= Date.today())
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<Asset__c> searchAssets(String searchTerm, Id accountId) {
        String filter = '%' + String.escapeSingleQuotes(searchTerm == null ? '' : searchTerm) + '%';
        String soql = 'SELECT Id, Name, Serial_Number__c, Model__c, Manufacturer__c, Product_Category__c, Product_Name__c, Location_Address__c, Account__c, Account__r.Name ' +
                      'FROM Asset__c WHERE (Name LIKE :filter OR Serial_Number__c LIKE :filter OR Model__c LIKE :filter OR Product_Name__c LIKE :filter)';
        if (accountId != null) {
            soql += ' AND Account__c = :accountId';
        }
        soql += ' ORDER BY Name ASC LIMIT 50';
        return Database.query(soql);
    }

    /**
     * MULTI-ASSET SUPPORT: Fetch all line items / assets associated with a Work Order
     */
    @AuraEnabled(cacheable=true)
    public static List<Work_Order_Line_Item__c> getWorkOrderLineItems(Id workOrderId) {
        if (workOrderId == null) return new List<Work_Order_Line_Item__c>();
        return [
            SELECT Id, Name, Work_Order__c, Asset__c, Asset__r.Name, Asset__r.Serial_Number__c,
                   Asset__r.Model__c, Asset__r.Product_Name__c, Asset__r.Product_Category__c,
                   Asset__r.Is_Under_Warranty__c, Asset__r.Warranty_Expiry__c,
                   Status__c, Description__c, Sequence__c,
                   Operational_Status__c, Technician_Feedback__c, Asset_Condition__c,
                   Pre_Service_Photo_Id__c, Post_Service_Photo_Id__c,
                   Pre_Service_Photo_URL__c, Post_Service_Photo_URL__c,
                   Is_First_Time_Fix__c, Parts_Used__c, Resolution_Notes__c, CreatedDate
            FROM Work_Order_Line_Item__c
            WHERE Work_Order__c = :workOrderId
            ORDER BY Sequence__c ASC NULLS LAST, CreatedDate ASC
        ];
    }

    /**
     * MULTI-ASSET SUPPORT: Add an Asset line item to a Work Order
     */
    @AuraEnabled
    public static Work_Order_Line_Item__c addLineItem(Id workOrderId, Id assetId, String description, Integer sequence) {
        if (workOrderId == null || assetId == null) {
            throw new AuraHandledException('Work Order ID and Asset ID are required.');
        }

        Work_Order_Line_Item__c woli = new Work_Order_Line_Item__c(
            Work_Order__c = workOrderId,
            Asset__c = assetId,
            Description__c = description,
            Sequence__c = sequence != null ? sequence : 1,
            Status__c = 'New'
        );
        insert woli;

        // If the parent Work Order does not yet have a primary asset, set this asset as primary
        Work_Order__c wo = [SELECT Id, Asset__c FROM Work_Order__c WHERE Id = :workOrderId LIMIT 1];
        if (wo.Asset__c == null) {
            associateAsset(workOrderId, assetId);
        }

        return [
            SELECT Id, Name, Work_Order__c, Asset__c, Asset__r.Name, Asset__r.Serial_Number__c,
                   Asset__r.Product_Name__c, Status__c, Description__c, Sequence__c
            FROM Work_Order_Line_Item__c
            WHERE Id = :woli.Id
            LIMIT 1
        ];
    }

    /**
     * MULTI-ASSET SUPPORT: Update status and completion notes on a specific asset line item
     */
    @AuraEnabled
    public static void updateLineItemStatus(Id lineItemId, String status, String resolutionNotes, Boolean isFirstTimeFix, String partsUsed) {
        if (lineItemId == null) return;
        Work_Order_Line_Item__c woli = new Work_Order_Line_Item__c(
            Id = lineItemId,
            Status__c = status,
            Resolution_Notes__c = resolutionNotes,
            Is_First_Time_Fix__c = isFirstTimeFix == true,
            Parts_Used__c = partsUsed
        );
        update woli;
    }

    /**
     * MULTI-ASSET SUPPORT: Save operational status, condition, and technician assessment feedback
     * Automatically synchronizes an Asset_Feedback__c record across Asset, Case, and Work Order
     */
    @AuraEnabled
    public static void saveAssetAssessment(Id lineItemId, String operationalStatus, String feedback, String condition) {
        if (lineItemId == null) {
            throw new AuraHandledException('Line Item ID is required.');
        }

        Work_Order_Line_Item__c woli = [
            SELECT Id, Asset__c, Work_Order__c, Work_Order__r.Case__c,
                   Pre_Service_Photo_URL__c, Post_Service_Photo_URL__c
            FROM Work_Order_Line_Item__c
            WHERE Id = :lineItemId
            LIMIT 1
        ];

        woli.Operational_Status__c = operationalStatus;
        woli.Technician_Feedback__c = feedback;
        woli.Asset_Condition__c = condition;
        update woli;

        // Auto-synchronize Asset_Feedback__c record for audit trail across Asset, Case, and Work Order
        Id techId = null;
        List<Technician__c> techs = [SELECT Id FROM Technician__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];
        if (!techs.isEmpty()) {
            techId = techs[0].Id;
        }

        List<Asset_Feedback__c> existingFeedbacks = [
            SELECT Id FROM Asset_Feedback__c
            WHERE Work_Order_Line_Item__c = :lineItemId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!existingFeedbacks.isEmpty()) {
            Asset_Feedback__c afb = new Asset_Feedback__c(
                Id = existingFeedbacks[0].Id,
                Operational_Status__c = operationalStatus,
                Asset_Condition__c = condition,
                Feedback_Notes__c = feedback,
                Pre_Service_Photo_URL__c = woli.Pre_Service_Photo_URL__c,
                Post_Service_Photo_URL__c = woli.Post_Service_Photo_URL__c
            );
            if (techId != null) {
                afb.Technician__c = techId;
            }
            update afb;
        } else {
            Asset_Feedback__c afb = new Asset_Feedback__c(
                Asset__c = woli.Asset__c,
                Work_Order__c = woli.Work_Order__c,
                Work_Order_Line_Item__c = woli.Id,
                Case__c = woli.Work_Order__r.Case__c,
                Technician__c = techId,
                Feedback_Type__c = 'Pre-Service Diagnostic',
                Operational_Status__c = operationalStatus,
                Asset_Condition__c = condition,
                Feedback_Notes__c = feedback,
                Pre_Service_Photo_URL__c = woli.Pre_Service_Photo_URL__c,
                Post_Service_Photo_URL__c = woli.Post_Service_Photo_URL__c
            );
            insert afb;
        }
    }

    /**
     * MULTI-ASSET SUPPORT: Save Pre & Post Service Photo URLs
     */
    @AuraEnabled
    public static void saveAssetPhotos(Id lineItemId, String prePhotoUrl, String postPhotoUrl) {
        if (lineItemId == null) {
            throw new AuraHandledException('Line Item ID is required.');
        }
        Work_Order_Line_Item__c woli = new Work_Order_Line_Item__c(
            Id = lineItemId,
            Pre_Service_Photo_URL__c = prePhotoUrl,
            Post_Service_Photo_URL__c = postPhotoUrl
        );
        update woli;

        // Synchronize photo URLs with any existing feedback record
        List<Asset_Feedback__c> relatedFeedbacks = [
            SELECT Id FROM Asset_Feedback__c WHERE Work_Order_Line_Item__c = :lineItemId ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (!relatedFeedbacks.isEmpty()) {
            Asset_Feedback__c fb = new Asset_Feedback__c(
                Id = relatedFeedbacks[0].Id,
                Pre_Service_Photo_URL__c = prePhotoUrl,
                Post_Service_Photo_URL__c = postPhotoUrl
            );
            update fb;
        }
    }

    /**
     * ASSET FEEDBACK: Explicitly create or log an Asset Feedback record linking Asset, Case, and Work Order
     */
    @AuraEnabled
    public static Asset_Feedback__c saveAssetFeedback(
        Id assetId,
        Id workOrderId,
        Id lineItemId,
        String feedbackType,
        String operationalStatus,
        String assetCondition,
        Decimal rating,
        String feedbackNotes,
        String recommendedAction,
        String prePhotoUrl,
        String postPhotoUrl
    ) {
        if (assetId == null && workOrderId == null && lineItemId == null) {
            throw new AuraHandledException('At least one reference (Asset, Work Order, or Line Item) is required.');
        }

        Id resolvedAssetId = assetId;
        Id resolvedCaseId = null;
        Id resolvedWorkOrderId = workOrderId;

        if (lineItemId != null) {
            List<Work_Order_Line_Item__c> items = [
                SELECT Id, Asset__c, Work_Order__c, Work_Order__r.Case__c
                FROM Work_Order_Line_Item__c
                WHERE Id = :lineItemId
                LIMIT 1
            ];
            if (!items.isEmpty()) {
                if (resolvedAssetId == null) {
                    resolvedAssetId = items[0].Asset__c;
                }
                if (resolvedWorkOrderId == null) {
                    resolvedWorkOrderId = items[0].Work_Order__c;
                }
                if (items[0].Work_Order__r.Case__c != null) {
                    resolvedCaseId = items[0].Work_Order__r.Case__c;
                }
            }
        }

        if (resolvedWorkOrderId != null && resolvedCaseId == null) {
            List<Work_Order__c> woList = [
                SELECT Id, Asset__c, Case__c
                FROM Work_Order__c
                WHERE Id = :resolvedWorkOrderId
                LIMIT 1
            ];
            if (!woList.isEmpty()) {
                if (resolvedAssetId == null) {
                    resolvedAssetId = woList[0].Asset__c;
                }
                resolvedCaseId = woList[0].Case__c;
            }
        }

        Id technicianId = null;
        List<Technician__c> techs = [
            SELECT Id FROM Technician__c WHERE User__c = :UserInfo.getUserId() LIMIT 1
        ];
        if (!techs.isEmpty()) {
            technicianId = techs[0].Id;
        }

        Asset_Feedback__c feedback = new Asset_Feedback__c(
            Asset__c = resolvedAssetId,
            Work_Order__c = resolvedWorkOrderId,
            Work_Order_Line_Item__c = lineItemId,
            Case__c = resolvedCaseId,
            Technician__c = technicianId,
            Feedback_Type__c = String.isNotBlank(feedbackType) ? feedbackType : 'Routine Maintenance',
            Operational_Status__c = operationalStatus,
            Asset_Condition__c = assetCondition,
            Rating__c = rating,
            Feedback_Notes__c = feedbackNotes,
            Recommended_Action__c = recommendedAction,
            Pre_Service_Photo_URL__c = prePhotoUrl,
            Post_Service_Photo_URL__c = postPhotoUrl
        );

        insert feedback;
        return feedback;
    }

    /**
     * ASSET FEEDBACK: Fetch feedback records for an Asset, Work Order, Case, or Line Item
     */
    @AuraEnabled(cacheable=true)
    public static List<Asset_Feedback__c> getAssetFeedbacks(Id recordId) {
        if (recordId == null) return new List<Asset_Feedback__c>();

        String sObjName = recordId.getSobjectType().getDescribe().getName();
        String query = 'SELECT Id, Name, Asset__c, Asset__r.Name, Case__c, Case__r.CaseNumber, ' +
                       'Work_Order__c, Work_Order__r.Name, Work_Order_Line_Item__c, ' +
                       'Technician__c, Technician__r.Name, Feedback_Type__c, Operational_Status__c, ' +
                       'Asset_Condition__c, Rating__c, Feedback_Notes__c, Recommended_Action__c, ' +
                       'Pre_Service_Photo_URL__c, Post_Service_Photo_URL__c, CreatedDate ' +
                       'FROM Asset_Feedback__c WHERE ';

        if (sObjName == 'Asset__c') {
            query += 'Asset__c = :recordId';
        } else if (sObjName == 'Work_Order__c') {
            query += 'Work_Order__c = :recordId';
        } else if (sObjName == 'Case') {
            query += 'Case__c = :recordId';
        } else if (sObjName == 'Work_Order_Line_Item__c') {
            query += 'Work_Order_Line_Item__c = :recordId';
        } else {
            return new List<Asset_Feedback__c>();
        }

        query += ' ORDER BY CreatedDate DESC LIMIT 50';
        return Database.query(query);
    }

    /**
     * MULTI-ASSET SUPPORT: Link an uploaded ContentDocument as Pre or Post photo
     */
    @AuraEnabled
    public static Map<String, Object> linkPhotoDocument(Id lineItemId, Id contentDocumentId, String photoType) {
        if (lineItemId == null || contentDocumentId == null) {
            throw new AuraHandledException('Line Item ID and Content Document ID are required.');
        }

        List<ContentVersion> cvList = [
            SELECT Id, Title
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (cvList.isEmpty()) {
            throw new AuraHandledException('No file version found for the uploaded document.');
        }

        ContentVersion cv = cvList[0];
        String downloadUrl = '/sfc/servlet.shepherd/version/download/' + cv.Id;
        Work_Order_Line_Item__c woli = new Work_Order_Line_Item__c(Id = lineItemId);

        if (photoType == 'PRE') {
            woli.Pre_Service_Photo_Id__c = cv.Id;
            woli.Pre_Service_Photo_URL__c = downloadUrl;
        } else if (photoType == 'POST') {
            woli.Post_Service_Photo_Id__c = cv.Id;
            woli.Post_Service_Photo_URL__c = downloadUrl;
        }

        update woli;

        return new Map<String, Object>{
            'success' => true,
            'versionId' => cv.Id,
            'url' => downloadUrl,
            'photoType' => photoType
        };
    }
}
