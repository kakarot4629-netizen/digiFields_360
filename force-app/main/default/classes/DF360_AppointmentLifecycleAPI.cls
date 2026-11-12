@RestResource(urlMapping='/df360/v1/service-appointments/*')
global with sharing class DF360_AppointmentLifecycleAPI {

    /**
     * POST  /services/apexrest/df360/v1/service-appointments/{id}/check-in
     * POST  /services/apexrest/df360/v1/service-appointments/{id}/photos
     * POST  /services/apexrest/df360/v1/service-appointments/{id}/incomplete
     * PATCH /services/apexrest/df360/v1/service-appointments/{id}/incomplete
     */
    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        if (res != null) {
            res.addHeader('Content-Type', 'application/json');
        }

        try {
            String uri = req != null ? req.requestURI : '';
            Map<String, Object> body = new Map<String, Object>();
            if (req != null && req.requestBody != null && req.requestBody.size() > 0) {
                String bodyStr = req.requestBody.toString().trim();
                if (String.isNotBlank(bodyStr)) {
                    body = (Map<String, Object>) JSON.deserializeUntyped(bodyStr);
                }
            }

            // Extract Appointment identifier from URI
            // e.g. /df360/v1/service-appointments/{identifier}/check-in
            // or   /df360/v1/service-appointments/{identifier}/photos
            // or   /df360/v1/service-appointments/{identifier}/incomplete
            String appointmentId = null;
            Boolean isPhotosRoute = false;
            Boolean isIncompleteRoute = false;
            if (String.isNotBlank(uri)) {
                String sub = uri.substringAfter('/df360/v1/service-appointments/');
                if (String.isNotBlank(sub)) {
                    if (sub.endsWithIgnoreCase('/photos') || sub.endsWithIgnoreCase('/photo')) {
                        isPhotosRoute = true;
                        appointmentId = sub.substringBefore('/');
                    } else if (sub.endsWithIgnoreCase('/incomplete')) {
                        isIncompleteRoute = true;
                        appointmentId = sub.substringBefore('/');
                    } else if (sub.contains('/')) {
                        appointmentId = sub.substringBefore('/');
                    } else if (!sub.equalsIgnoreCase('check-in')) {
                        appointmentId = sub;
                    }
                }
            }

            // Fallback to body param if not in URI
            if (String.isBlank(appointmentId)) {
                if (body.containsKey('appointmentId')) {
                    appointmentId = String.valueOf(body.get('appointmentId'));
                } else if (body.containsKey('id')) {
                    appointmentId = String.valueOf(body.get('id'));
                } else if (body.containsKey('serviceAppointmentId')) {
                    appointmentId = String.valueOf(body.get('serviceAppointmentId'));
                }
            }

            if (String.isBlank(appointmentId)) {
                if (res != null) res.statusCode = 400;
                writeResponse(res, new Map<String, Object>{
                    'success' => false,
                    'error' => 'Missing service appointment identifier in URL or request body.'
                });
                return;
            }

            // Route 1: Photo Evidence Upload
            if (isPhotosRoute || body.containsKey('photoType') || body.containsKey('imageBase64') || body.containsKey('photoUrl')) {
                Map<String, Object> photoResult = executePhotoUpload(appointmentId.trim(), body);
                if (photoResult.get('success') == true) {
                    if (res != null) res.statusCode = 200;
                } else {
                    if (res != null) res.statusCode = 400;
                }
                writeResponse(res, photoResult);
                return;
            }

            // Route 2: Mark Incomplete Execution
            if (isIncompleteRoute ||
                (body.containsKey('status') && String.valueOf(body.get('status')).equalsIgnoreCase('Incomplete')) ||
                (body.containsKey('action') && String.valueOf(body.get('action')).equalsIgnoreCase('incomplete'))) {
                Map<String, Object> incompleteResult = executeMarkIncomplete(appointmentId.trim(), body);
                if (incompleteResult.get('success') == true) {
                    if (res != null) res.statusCode = 200;
                } else {
                    String errMsg = String.valueOf(incompleteResult.get('error'));
                    if (res != null) {
                        res.statusCode = (errMsg != null && errMsg.contains('not found')) ? 404 : 400;
                    }
                }
                writeResponse(res, incompleteResult);
                return;
            }

            // Route 3: Check-In Execution
            Map<String, Object> checkInResult = executeCheckIn(appointmentId.trim(), body);
            if (checkInResult.get('success') == true) {
                if (res != null) res.statusCode = 200;
            } else {
                if (res != null) res.statusCode = 404;
            }
            writeResponse(res, checkInResult);

        } catch (Exception e) {
            if (res != null) res.statusCode = 500;
            writeResponse(res, new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage(),
                'stackTrace' => e.getStackTraceString()
            });
        }
    }

    @HttpPatch
    global static void doPatch() {
        doPost();
    }

    /**
     * GET /services/apexrest/df360/v1/service-appointments/{id}
     * GET /services/apexrest/df360/v1/service-appointments/{id}/photos
     */
    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        if (res != null) {
            res.addHeader('Content-Type', 'application/json');
        }

        try {
            String uri = req != null ? req.requestURI : '';
            String appointmentId = null;
            Boolean isPhotosRoute = false;

            if (String.isNotBlank(uri)) {
                String sub = uri.substringAfter('/df360/v1/service-appointments/');
                if (String.isNotBlank(sub)) {
                    if (sub.endsWithIgnoreCase('/photos') || sub.endsWithIgnoreCase('/photo')) {
                        isPhotosRoute = true;
                        appointmentId = sub.substringBefore('/');
                    } else if (sub.contains('/')) {
                        appointmentId = sub.substringBefore('/');
                    } else {
                        appointmentId = sub;
                    }
                }
            }

            if (String.isBlank(appointmentId)) {
                if (res != null) res.statusCode = 400;
                writeResponse(res, new Map<String, Object>{
                    'success' => false,
                    'error' => 'Missing service appointment identifier in request URL.'
                });
                return;
            }

            // Route 1: Photo Gallery Query
            if (isPhotosRoute) {
                Map<String, Object> photoGallery = getServiceAppointmentPhotos(appointmentId.trim());
                if (photoGallery.get('success') == true) {
                    if (res != null) res.statusCode = 200;
                } else {
                    if (res != null) res.statusCode = 404;
                }
                writeResponse(res, photoGallery);
                return;
            }

            // Route 2: 360-Degree Detail Query
            String techParam = (req != null && req.params != null) ? req.params.get('technicianId') : null;
            Map<String, Object> details = getServiceAppointmentDetails(appointmentId.trim(), techParam);
            if (details.get('success') == true) {
                if (res != null) res.statusCode = 200;
            } else {
                if (res != null) res.statusCode = 404;
            }
            writeResponse(res, details);

        } catch (Exception e) {
            if (res != null) res.statusCode = 500;
            writeResponse(res, new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage(),
                'stackTrace' => e.getStackTraceString()
            });
        }
    }

    /**
     * Unified 360-Degree Service Appointment Detail Method
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getServiceAppointmentDetails(String appointmentIdentifier, String technicianIdParam) {
        if (String.isBlank(appointmentIdentifier)) {
            return new Map<String, Object>{
                'success' => false,
                'error' => 'Appointment identifier is required.'
            };
        }

        String cleanedId = appointmentIdentifier.trim();

        // 1. Identify Caller Technician
        Id targetUserId = UserInfo.getUserId();
        String targetUserName = UserInfo.getName();
        String targetUserEmail = UserInfo.getUserEmail();
        Id myTechId = null;

        if (String.isNotBlank(technicianIdParam)) {
            String cleanTech = technicianIdParam.trim();
            List<Technician__c> searchedTechs = [
                SELECT Id, Name, User__c, User__r.Name, User__r.Email
                FROM Technician__c
                WHERE Id = :cleanTech OR Name = :cleanTech OR Employee_Code__c = :cleanTech OR User__c = :cleanTech
                LIMIT 1
            ];
            if (!searchedTechs.isEmpty()) {
                myTechId = searchedTechs[0].Id;
                if (searchedTechs[0].User__c != null) targetUserId = searchedTechs[0].User__c;
                if (searchedTechs[0].User__r != null) {
                    targetUserName = searchedTechs[0].User__r.Name;
                    targetUserEmail = searchedTechs[0].User__r.Email;
                }
            }
        }

        if (myTechId == null) {
            List<Technician__c> myTechs = [SELECT Id, Name, User__c FROM Technician__c WHERE User__c = :targetUserId LIMIT 1];
            if (!myTechs.isEmpty()) {
                myTechId = myTechs[0].Id;
            }
        }

        // 2. Pre-fetch Caller's Active Crew Memberships
        Map<Id, Service_Crew_Member__c> myCrewMap = new Map<Id, Service_Crew_Member__c>();
        if (myTechId != null) {
            for (Service_Crew_Member__c m : [
                SELECT Id, Service_Crew__c, Service_Crew__r.Name, Is_Leader__c
                FROM Service_Crew_Member__c
                WHERE Technician__c = :myTechId
            ]) {
                myCrewMap.put(m.Service_Crew__c, m);
            }
        }

        // 3. Query Service Appointment
        List<Service_Job__c> jobs = [
            SELECT Id, Name, Status__c, Priority__c, Job_Type__c,
                   Scheduled_Start_Time__c, Scheduled_End_Time__c,
                   Check_In_Time__c, Completed_Time__c, Resolution_Time_Min__c,
                   Check_In_GPS__Latitude__s, Check_In_GPS__Longitude__s,
                   SLA_Deadline__c, SLA_Status__c,
                   Notes__c, Customer_Notes__c, Customer_Signature_URL__c, Is_First_Time_Fix__c,
                   Reason__c, Description__c,
                   Zone__c, Zone__r.Name,
                   Before_Photo_URL__c, Before_Photo_Id__c, Before_Photo_Timestamp__c,
                   After_Photo_URL__c, After_Photo_Id__c, After_Photo_Timestamp__c,
                   Technician__c, Technician__r.Name, Technician__r.Employee_Code__c, Technician__r.Mobile__c,
                   Work_Order__c, Work_Order__r.Name, Work_Order__r.Subject__c, Work_Order__r.Status__c, Work_Order__r.Priority__c,
                   Work_Order__r.Description__c, Work_Order__r.Site_Address__c, Work_Order__r.AI_Pre_Job_Briefing__c,
                   Work_Order__r.Account__c, Work_Order__r.Account__r.Name,
                   Work_Order__r.Asset__c, Work_Order__r.Asset__r.Name, Work_Order__r.Asset__r.Serial_Number__c,
                   Work_Order__r.Asset__r.Product_Name__c, Work_Order__r.Asset__r.Product_Category__c,
                   Work_Order__r.Case__c, Work_Order__r.Case__r.Customer_Address__c,
                   Work_Order__r.Case__r.Customer_Address__r.Name,
                   Work_Order__r.Case__r.Customer_Address__r.Contact_Person_Name__c,
                   Work_Order__r.Case__r.Customer_Address__r.Contact_Phone__c,
                   Work_Order__r.Case__r.Customer_Address__r.Street_Address__c,
                   Work_Order__r.Case__r.Customer_Address__r.City__c,
                   Work_Order__r.Case__r.Customer_Address__r.State__c,
                   Work_Order__r.Case__r.Customer_Address__r.Postal_Code__c,
                   Work_Order__r.Case__r.Customer_Address__r.Country__c,
                   Work_Order__r.Case__r.Customer_Address__r.Latitude__c,
                   Work_Order__r.Case__r.Customer_Address__r.Longitude__c,
                   Work_Order__r.Case__r.Customer_Address__r.Landmark__c,
                   (SELECT Id, Name, Resource_Type__c, Role__c, Is_Leader__c, Status__c, Check_In_Time__c, Actual_Hours__c,
                           Technician__c, Technician__r.Name, Technician__r.Employee_Code__c, Technician__r.Mobile__c,
                           Service_Crew__c, Service_Crew__r.Name
                    FROM Assigned_Resources__r),
                   (SELECT Id, Name, Activity_Type__c, Description__c, Duration_Min__c, Photo_URL__c,
                           Part__c, Part__r.Name, Quantity_Used__c
                    FROM Job_Activities__r)
            FROM Service_Job__c
            WHERE Id = :cleanedId OR Name = :cleanedId
            LIMIT 1
        ];

        if (jobs.isEmpty()) {
            return new Map<String, Object>{
                'success' => false,
                'error' => 'Service Appointment not found for identifier: ' + appointmentIdentifier
            };
        }

        Service_Job__c job = jobs[0];

        // 4. Query Multi-Asset Line Items under Parent Work Order
        List<Map<String, Object>> lineItemList = new List<Map<String, Object>>();
        if (job.Work_Order__c != null) {
            for (Work_Order_Line_Item__c woli : [
                SELECT Id, Name, Sequence__c, Status__c, Description__c, Resolution_Notes__c,
                       Technician_Feedback__c, Asset_Condition__c, Operational_Status__c,
                       Is_First_Time_Fix__c, Pre_Service_Photo_URL__c, Post_Service_Photo_URL__c,
                       Asset__c, Asset__r.Name, Asset__r.Serial_Number__c,
                       Asset__r.Product_Name__c, Asset__r.Product_Category__c
                FROM Work_Order_Line_Item__c
                WHERE Work_Order__c = :job.Work_Order__c
                ORDER BY Sequence__c ASC NULLS LAST, CreatedDate ASC
            ]) {
                lineItemList.add(new Map<String, Object>{
                    'id' => woli.Id,
                    'name' => woli.Name,
                    'sequence' => woli.Sequence__c,
                    'status' => woli.Status__c,
                    'description' => woli.Description__c,
                    'resolutionNotes' => woli.Resolution_Notes__c,
                    'technicianFeedback' => woli.Technician_Feedback__c,
                    'assetCondition' => woli.Asset_Condition__c,
                    'operationalStatus' => woli.Operational_Status__c,
                    'isFirstTimeFix' => woli.Is_First_Time_Fix__c,
                    'preServicePhotoUrl' => woli.Pre_Service_Photo_URL__c,
                    'postServicePhotoUrl' => woli.Post_Service_Photo_URL__c,
                    'asset' => woli.Asset__c != null ? new Map<String, Object>{
                        'id' => woli.Asset__c,
                        'name' => woli.Asset__r.Name,
                        'serialNumber' => woli.Asset__r.Serial_Number__c,
                        'productName' => woli.Asset__r.Product_Name__c,
                        'productCategory' => woli.Asset__r.Product_Category__c
                    } : null
                });
            }
        }

        // 5. Query Parts Requests associated with this Appointment or Parent Work Order
        List<Map<String, Object>> partsList = new List<Map<String, Object>>();
        for (Parts_Request__c pr : [
            SELECT Id, Name, Part__c, Part__r.Name, Part__r.Part_Code__c, Part__r.Category__c,
                   Part__r.Unit_Cost__c, Part__r.ERP_SKU__c, Quantity__c, Status__c, Is_Warranty__c,
                   Depot__c, Depot__r.Name, Approved_At__c, Dispatched_At__c, Delivered_At__c, Rejection_Reason__c
            FROM Parts_Request__c
            WHERE Service_Job__c = :job.Id OR (Work_Order__c != null AND Work_Order__c = :job.Work_Order__c)
            ORDER BY CreatedDate DESC
        ]) {
            partsList.add(new Map<String, Object>{
                'id' => pr.Id,
                'name' => pr.Name,
                'partId' => pr.Part__c,
                'partName' => pr.Part__r != null ? pr.Part__r.Name : null,
                'partCode' => pr.Part__r != null ? pr.Part__r.Part_Code__c : null,
                'category' => pr.Part__r != null ? pr.Part__r.Category__c : null,
                'erpSku' => pr.Part__r != null ? pr.Part__r.ERP_SKU__c : null,
                'unitCost' => pr.Part__r != null ? pr.Part__r.Unit_Cost__c : null,
                'quantity' => pr.Quantity__c,
                'status' => pr.Status__c,
                'isWarranty' => pr.Is_Warranty__c,
                'depotName' => pr.Depot__r != null ? pr.Depot__r.Name : null,
                'approvedAt' => pr.Approved_At__c,
                'dispatchedAt' => pr.Dispatched_At__c,
                'deliveredAt' => pr.Delivered_At__c,
                'rejectionReason' => pr.Rejection_Reason__c
            });
        }

        // 6. Match Caller Technician (Piyush Channe) Assignment & Crew Tag
        Boolean isDirect = (myTechId != null && job.Technician__c == myTechId);
        Boolean isCrew = false;
        Map<String, Object> myCrewAssignmentInfo = null;

        List<Map<String, Object>> teamList = new List<Map<String, Object>>();
        if (job.Assigned_Resources__r != null) {
            for (Assigned_Resource__c ar : job.Assigned_Resources__r) {
                Boolean isResourceMe = (myTechId != null && ar.Technician__c == myTechId);
                if (isResourceMe) isDirect = true;

                Boolean isCrewMe = (ar.Service_Crew__c != null && myCrewMap.containsKey(ar.Service_Crew__c));
                if (isCrewMe) {
                    isCrew = true;
                    Service_Crew_Member__c scm = myCrewMap.get(ar.Service_Crew__c);
                    myCrewAssignmentInfo = new Map<String, Object>{
                        'crewId' => ar.Service_Crew__c,
                        'crewName' => ar.Service_Crew__r != null ? ar.Service_Crew__r.Name : (scm.Service_Crew__r != null ? scm.Service_Crew__r.Name : 'Service Crew'),
                        'isMember' => true,
                        'isLeader' => (scm.Is_Leader__c == true || ar.Is_Leader__c == true),
                        'role' => ar.Role__c != null ? ar.Role__c : 'Crew Member'
                    };
                }

                teamList.add(new Map<String, Object>{
                    'id' => ar.Id,
                    'name' => ar.Name,
                    'resourceType' => ar.Resource_Type__c,
                    'role' => ar.Role__c,
                    'isLeader' => ar.Is_Leader__c,
                    'status' => ar.Status__c,
                    'checkInTime' => ar.Check_In_Time__c,
                    'actualHours' => ar.Actual_Hours__c,
                    'technician' => ar.Technician__c != null ? new Map<String, Object>{
                        'id' => ar.Technician__c,
                        'name' => ar.Technician__r.Name,
                        'employeeCode' => ar.Technician__r.Employee_Code__c,
                        'mobile' => ar.Technician__r.Mobile__c
                    } : null,
                    'crew' => ar.Service_Crew__c != null ? new Map<String, Object>{
                        'id' => ar.Service_Crew__c,
                        'name' => ar.Service_Crew__r.Name
                    } : null
                });
            }
        }

        Boolean isAssignedToMe = (isDirect || isCrew);
        String assignmentType = 'Other';
        if (isDirect && isCrew) {
            assignmentType = 'Direct & Crew';
        } else if (isDirect) {
            assignmentType = 'Direct';
        } else if (isCrew) {
            assignmentType = 'Crew';
        } else if (job.Technician__c == null && (job.Assigned_Resources__r == null || job.Assigned_Resources__r.isEmpty())) {
            assignmentType = 'Unassigned';
        }

        // 7. Format On-Site Activities
        List<Map<String, Object>> activitiesList = new List<Map<String, Object>>();
        if (job.Job_Activities__r != null) {
            for (Job_Activity__c act : job.Job_Activities__r) {
                activitiesList.add(new Map<String, Object>{
                    'id' => act.Id,
                    'name' => act.Name,
                    'activityType' => act.Activity_Type__c,
                    'description' => act.Description__c,
                    'durationMinutes' => act.Duration_Min__c,
                    'photoUrl' => act.Photo_URL__c,
                    'partName' => act.Part__r != null ? act.Part__r.Name : null,
                    'quantityUsed' => act.Quantity_Used__c
                });
            }
        }

        // 8. SLA Calculations
        Decimal remHrs = null;
        Boolean isBreached = false;
        if (job.SLA_Deadline__c != null) {
            Long diffMs = job.SLA_Deadline__c.getTime() - DateTime.now().getTime();
            remHrs = (Decimal.valueOf(diffMs) / 3600000).setScale(2);
            if (remHrs < 0) isBreached = true;
        }

        // 9. Customer Service Address
        Map<String, Object> serviceAddressMap = null;
        if (job.Work_Order__c != null && job.Work_Order__r.Case__c != null && job.Work_Order__r.Case__r.Customer_Address__c != null) {
            Customer_Address__c ca = job.Work_Order__r.Case__r.Customer_Address__r;
            serviceAddressMap = new Map<String, Object>{
                'id' => ca.Id,
                'name' => ca.Name,
                'contactPerson' => ca.Contact_Person_Name__c,
                'contactPhone' => ca.Contact_Phone__c,
                'streetAddress' => ca.Street_Address__c,
                'city' => ca.City__c,
                'state' => ca.State__c,
                'postalCode' => ca.Postal_Code__c,
                'country' => ca.Country__c,
                'landmark' => ca.Landmark__c,
                'latitude' => ca.Latitude__c,
                'longitude' => ca.Longitude__c
            };
        }

        // 10. Construct Final 360 Payload
        return new Map<String, Object>{
            'success' => true,
            'serviceAppointment' => new Map<String, Object>{
                'id' => job.Id,
                'name' => job.Name,
                'status' => job.Status__c,
                'priority' => job.Priority__c,
                'jobType' => job.Job_Type__c,
                'zone' => job.Zone__r != null ? job.Zone__r.Name : null,

                // Caller Technician & Crew Match
                'isAssignedToMe' => isAssignedToMe,
                'isMyAppointment' => isAssignedToMe,
                'assignmentType' => assignmentType,
                'isCrewAssigned' => isCrew,
                'myCrewAssignment' => myCrewAssignmentInfo,

                // Before and After Photo Evidence
                'beforePhoto' => job.Before_Photo_URL__c != null ? new Map<String, Object>{
                    'url' => job.Before_Photo_URL__c,
                    'id' => job.Before_Photo_Id__c,
                    'timestamp' => job.Before_Photo_Timestamp__c
                } : null,
                'afterPhoto' => job.After_Photo_URL__c != null ? new Map<String, Object>{
                    'url' => job.After_Photo_URL__c,
                    'id' => job.After_Photo_Id__c,
                    'timestamp' => job.After_Photo_Timestamp__c
                } : null,

                // Scheduling & Actual Execution Timestamps
                'scheduledStartTime' => job.Scheduled_Start_Time__c,
                'scheduledEndTime' => job.Scheduled_End_Time__c,
                'startTime' => job.Check_In_Time__c,
                'endTime' => job.Completed_Time__c,
                'actualStartTime' => job.Check_In_Time__c,
                'actualEndTime' => job.Completed_Time__c,
                'checkInTime' => job.Check_In_Time__c,
                'completedTime' => job.Completed_Time__c,
                'checkInLocation' => new Map<String, Object>{
                    'latitude' => job.Check_In_GPS__Latitude__s,
                    'longitude' => job.Check_In_GPS__Longitude__s
                },

                // Resolution & Customer Feedback
                'resolutionTimeMinutes' => job.Resolution_Time_Min__c,
                'isFirstTimeFix' => job.Is_First_Time_Fix__c,
                'customerSignatureUrl' => job.Customer_Signature_URL__c,
                'reason' => job.Reason__c,
                'description' => job.Description__c,
                'notes' => job.Notes__c,
                'customerNotes' => job.Customer_Notes__c,

                // SLA Tracking
                'sla' => new Map<String, Object>{
                    'status' => job.SLA_Status__c,
                    'deadline' => job.SLA_Deadline__c,
                    'remainingHours' => remHrs,
                    'isBreached' => isBreached
                },

                // Primary Asset on Work Order
                'primaryAsset' => (job.Work_Order__c != null && job.Work_Order__r.Asset__c != null) ? new Map<String, Object>{
                    'id' => job.Work_Order__r.Asset__c,
                    'name' => job.Work_Order__r.Asset__r.Name,
                    'serialNumber' => job.Work_Order__r.Asset__r.Serial_Number__c,
                    'productName' => job.Work_Order__r.Asset__r.Product_Name__c,
                    'category' => job.Work_Order__r.Asset__r.Product_Category__c
                } : null,

                // Multi-Assets / Work Order Line Items
                'multiAssetLineItemsCount' => lineItemList.size(),
                'multiAssetLineItems' => lineItemList,

                // Parts Requests
                'partsRequestsCount' => partsList.size(),
                'partsRequests' => partsList,

                // Assigned Team & Crew Roster
                'assignedTeamCount' => teamList.size(),
                'assignedTeam' => teamList,

                // On-Site Activities
                'activitiesCount' => activitiesList.size(),
                'activities' => activitiesList,

                // Customer Site & Address
                'siteAddress' => job.Work_Order__r != null ? job.Work_Order__r.Site_Address__c : null,
                'serviceAddress' => serviceAddressMap,

                // Parent Work Order
                'parentWorkOrder' => job.Work_Order__c != null ? new Map<String, Object>{
                    'id' => job.Work_Order__c,
                    'name' => job.Work_Order__r.Name,
                    'subject' => job.Work_Order__r.Subject__c,
                    'status' => job.Work_Order__r.Status__c,
                    'priority' => job.Work_Order__r.Priority__c,
                    'description' => job.Work_Order__r.Description__c,
                    'account' => job.Work_Order__r.Account__c != null ? new Map<String, Object>{
                        'id' => job.Work_Order__r.Account__c,
                        'name' => job.Work_Order__r.Account__r.Name
                    } : null
                } : null,

                // AI Safety Briefing
                'aiPreJobBriefing' => job.Work_Order__r != null ? job.Work_Order__r.AI_Pre_Job_Briefing__c : null,

                // Direct Technician details
                'technician' => job.Technician__c != null ? new Map<String, Object>{
                    'id' => job.Technician__c,
                    'name' => job.Technician__r.Name,
                    'employeeCode' => job.Technician__r.Employee_Code__c,
                    'mobile' => job.Technician__r.Mobile__c
                } : null
            }
        };
    }

    /**
     * Photo Upload Logic: Supports Base64 file upload (Salesforce Files) and Direct Hosted URLs
     */
    public static Map<String, Object> executePhotoUpload(String appointmentIdentifier, Map<String, Object> payload) {
        String cleanId = appointmentIdentifier.trim();
        List<Service_Job__c> jobs = [
            SELECT Id, Name, Status__c, Before_Photo_URL__c, After_Photo_URL__c
            FROM Service_Job__c
            WHERE Id = :cleanId OR Name = :cleanId
            LIMIT 1
        ];

        if (jobs.isEmpty()) {
            return new Map<String, Object>{
                'success' => false,
                'error' => 'Service Appointment not found for identifier: ' + appointmentIdentifier
            };
        }

        Service_Job__c job = jobs[0];

        // Determine photo type: 'Before' or 'After'
        String photoType = 'Before';
        if (payload.containsKey('photoType') && String.isNotBlank(String.valueOf(payload.get('photoType')))) {
            String pt = String.valueOf(payload.get('photoType')).trim();
            if (pt.equalsIgnoreCase('After') || pt.equalsIgnoreCase('Post')) {
                photoType = 'After';
            }
        }

        String imageBase64 = payload.containsKey('imageBase64') ? String.valueOf(payload.get('imageBase64')) : null;
        String photoUrl = payload.containsKey('photoUrl') ? String.valueOf(payload.get('photoUrl')) : null;
        String fileName = payload.containsKey('fileName') ? String.valueOf(payload.get('fileName')) : null;
        String notes = payload.containsKey('notes') ? String.valueOf(payload.get('notes')) : null;
        String lineItemId = payload.containsKey('lineItemId') ? String.valueOf(payload.get('lineItemId')) : null;
        String photoId = null;

        // Process Base64 File Upload
        if (String.isNotBlank(imageBase64)) {
            String rawBase64 = imageBase64.trim();
            if (rawBase64.contains(',')) {
                rawBase64 = rawBase64.substringAfter(',');
            }
            Blob fileBlob = EncodingUtil.base64Decode(rawBase64);

            String fTitle = String.isNotBlank(fileName) ? fileName.trim() : (photoType.toUpperCase() + '_' + job.Name + '.jpg');
            String fPath = fTitle.contains('.') ? fTitle : (fTitle + '.jpg');

            ContentVersion cv = new ContentVersion(
                Title = fTitle,
                PathOnClient = fPath,
                VersionData = fileBlob,
                IsMajorVersion = true
            );
            insert cv;

            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
            photoId = cv.Id;

            // Link to Service Appointment
            insert new ContentDocumentLink(
                LinkedEntityId = job.Id,
                ContentDocumentId = cv.ContentDocumentId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            );

            // Construct accessible URL
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            photoUrl = baseUrl + '/sfc/servlet.shepherd/version/download/' + cv.Id;
        } else if (String.isBlank(photoUrl)) {
            return new Map<String, Object>{
                'success' => false,
                'error' => 'Either imageBase64 or photoUrl must be provided.'
            };
        }

        DateTime nowTime = DateTime.now();
        Service_Job__c sjUpdate = new Service_Job__c(Id = job.Id);
        if (photoType == 'Before') {
            sjUpdate.Before_Photo_URL__c = photoUrl;
            sjUpdate.Before_Photo_Id__c = photoId;
            sjUpdate.Before_Photo_Timestamp__c = nowTime;
        } else {
            sjUpdate.After_Photo_URL__c = photoUrl;
            sjUpdate.After_Photo_Id__c = photoId;
            sjUpdate.After_Photo_Timestamp__c = nowTime;
        }
        update sjUpdate;

        // Optional Multi-Asset line item sync
        Map<String, Object> woliSummary = null;
        if (String.isNotBlank(lineItemId)) {
            List<Work_Order_Line_Item__c> wolis = [SELECT Id, Name, Pre_Service_Photo_URL__c, Post_Service_Photo_URL__c FROM Work_Order_Line_Item__c WHERE Id = :lineItemId.trim() LIMIT 1];
            if (!wolis.isEmpty()) {
                Work_Order_Line_Item__c woli = wolis[0];
                if (photoType == 'Before') {
                    woli.Pre_Service_Photo_URL__c = photoUrl;
                    woli.Pre_Service_Photo_Id__c = photoId;
                } else {
                    woli.Post_Service_Photo_URL__c = photoUrl;
                    woli.Post_Service_Photo_Id__c = photoId;
                }
                update woli;
                woliSummary = new Map<String, Object>{
                    'id' => woli.Id,
                    'name' => woli.Name,
                    'updatedField' => (photoType == 'Before' ? 'Pre_Service_Photo_URL__c' : 'Post_Service_Photo_URL__c')
                };
            }
        }

        // Log Job Activity
        try {
            insert new Job_Activity__c(
                Service_Job__c = job.Id,
                Activity_Type__c = 'Photo Capture',
                Photo_URL__c = photoUrl,
                Description__c = photoType + ' service photo recorded. ' + (String.isNotBlank(notes) ? notes : '')
            );
        } catch (Exception ex) {
            System.debug('Warning: Could not create Job_Activity__c for photo: ' + ex.getMessage());
        }

        return new Map<String, Object>{
            'success' => true,
            'message' => photoType + ' photo recorded successfully.',
            'photo' => new Map<String, Object>{
                'photoType' => photoType,
                'photoUrl' => photoUrl,
                'contentVersionId' => photoId,
                'timestamp' => nowTime,
                'notes' => notes,
                'serviceAppointment' => new Map<String, Object>{
                    'id' => job.Id,
                    'name' => job.Name
                },
                'workOrderLineItem' => woliSummary
            }
        };
    }

    /**
     * Query all photo evidence for an appointment
     */
    public static Map<String, Object> getServiceAppointmentPhotos(String appointmentIdentifier) {
        String cleanId = appointmentIdentifier.trim();
        List<Service_Job__c> jobs = [
            SELECT Id, Name,
                   Before_Photo_URL__c, Before_Photo_Id__c, Before_Photo_Timestamp__c,
                   After_Photo_URL__c, After_Photo_Id__c, After_Photo_Timestamp__c
            FROM Service_Job__c
            WHERE Id = :cleanId OR Name = :cleanId
            LIMIT 1
        ];

        if (jobs.isEmpty()) {
            return new Map<String, Object>{
                'success' => false,
                'error' => 'Service Appointment not found for identifier: ' + appointmentIdentifier
            };
        }

        Service_Job__c job = jobs[0];

        // Query linked Salesforce files
        List<Map<String, Object>> gallery = new List<Map<String, Object>>();
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId, ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :job.Id
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 50
        ]) {
            gallery.add(new Map<String, Object>{
                'documentId' => cdl.ContentDocumentId,
                'versionId' => cdl.ContentDocument.LatestPublishedVersionId,
                'title' => cdl.ContentDocument.Title,
                'createdDate' => cdl.ContentDocument.CreatedDate,
                'downloadUrl' => baseUrl + '/sfc/servlet.shepherd/version/download/' + cdl.ContentDocument.LatestPublishedVersionId
            });
        }

        return new Map<String, Object>{
            'success' => true,
            'appointmentId' => job.Id,
            'appointmentName' => job.Name,
            'beforePhoto' => job.Before_Photo_URL__c != null ? new Map<String, Object>{
                'url' => job.Before_Photo_URL__c,
                'id' => job.Before_Photo_Id__c,
                'timestamp' => job.Before_Photo_Timestamp__c
            } : null,
            'afterPhoto' => job.After_Photo_URL__c != null ? new Map<String, Object>{
                'url' => job.After_Photo_URL__c,
                'id' => job.After_Photo_Id__c,
                'timestamp' => job.After_Photo_Timestamp__c
            } : null,
            'evidenceGalleryCount' => gallery.size(),
            'evidenceGallery' => gallery
        };
    }

    /**
     * Core Check-In logic
     */
    public static Map<String, Object> executeCheckIn(String appointmentIdentifier, Map<String, Object> payload) {
        String cleanId = appointmentIdentifier.trim();
        List<Service_Job__c> jobs = [
            SELECT Id, Name, Status__c, Priority__c, Job_Type__c,
                   Scheduled_Start_Time__c, Scheduled_End_Time__c,
                   Check_In_Time__c, SLA_Deadline__c, SLA_Status__c,
                   Work_Order__c, Work_Order__r.Name, Work_Order__r.Status__c,
                   Technician__c, Technician__r.Name
            FROM Service_Job__c
            WHERE Id = :cleanId OR Name = :cleanId
            LIMIT 1
        ];

        if (jobs.isEmpty()) {
            return new Map<String, Object>{
                'success' => false,
                'error' => 'Service Appointment not found for identifier: ' + appointmentIdentifier
            };
        }

        Service_Job__c job = jobs[0];

        // Determine target status (defaults to 'In Progress')
        String targetStatus = 'In Progress';
        if (payload != null && payload.containsKey('status') && String.isNotBlank(String.valueOf(payload.get('status')))) {
            targetStatus = String.valueOf(payload.get('status'));
        }

        // Determine effective check-in time
        DateTime effectiveCheckInTime = DateTime.now();
        if (payload != null && payload.containsKey('checkInTime') && String.isNotBlank(String.valueOf(payload.get('checkInTime')))) {
            try {
                effectiveCheckInTime = (DateTime) JSON.deserialize('"' + String.valueOf(payload.get('checkInTime')) + '"', DateTime.class);
            } catch (Exception ex) {
                effectiveCheckInTime = DateTime.now();
            }
        }

        // Extract optional GPS coordinates
        Decimal lat = null;
        Decimal lng = null;
        if (payload != null) {
            if (payload.containsKey('latitude') && payload.get('latitude') != null) {
                lat = Decimal.valueOf(String.valueOf(payload.get('latitude')));
            } else if (payload.containsKey('checkInLatitude') && payload.get('checkInLatitude') != null) {
                lat = Decimal.valueOf(String.valueOf(payload.get('checkInLatitude')));
            }
            if (payload.containsKey('longitude') && payload.get('longitude') != null) {
                lng = Decimal.valueOf(String.valueOf(payload.get('longitude')));
            } else if (payload.containsKey('checkInLongitude') && payload.get('checkInLongitude') != null) {
                lng = Decimal.valueOf(String.valueOf(payload.get('checkInLongitude')));
            }
        }

        // Update Service Job
        Service_Job__c toUpdate = new Service_Job__c(
            Id = job.Id,
            Status__c = targetStatus,
            Check_In_Time__c = effectiveCheckInTime
        );
        if (lat != null && lng != null) {
            toUpdate.Check_In_GPS__Latitude__s = lat;
            toUpdate.Check_In_GPS__Longitude__s = lng;
        }
        update toUpdate;

        // SLA remaining calculation
        Decimal remHrs = null;
        if (job.SLA_Deadline__c != null) {
            Long diffMs = job.SLA_Deadline__c.getTime() - effectiveCheckInTime.getTime();
            remHrs = (Decimal.valueOf(diffMs) / 3600000).setScale(2);
        }

        // SLA event creation (graceful failure)
        try {
            DF360_SLAController.createSLAEvent(job.Id, targetStatus, remHrs, 'Technician checked in via Mobile Check-In API');
        } catch (Exception ex) {
            System.debug('Warning: SLA event logging skipped: ' + ex.getMessage());
        }

        // Parent Work Order synchronization
        String parentWorkOrderStatus = null;
        if (job.Work_Order__c != null) {
            parentWorkOrderStatus = job.Work_Order__r.Status__c;
            if (job.Work_Order__r.Status__c == 'Assigned' || job.Work_Order__r.Status__c == 'New') {
                try {
                    update new Work_Order__c(
                        Id = job.Work_Order__c,
                        Status__c = 'In Progress'
                    );
                    parentWorkOrderStatus = 'In Progress';
                } catch (Exception ex) {
                    System.debug('Warning: Could not update parent Work Order: ' + ex.getMessage());
                }
            }
        }

        return new Map<String, Object>{
            'success' => true,
            'message' => 'Technician checked in successfully.',
            'appointment' => new Map<String, Object>{
                'id' => job.Id,
                'name' => job.Name,
                'status' => targetStatus,
                'checkInTime' => effectiveCheckInTime,
                'startTime' => effectiveCheckInTime,
                'endTime' => null,
                'scheduledStartTime' => job.Scheduled_Start_Time__c,
                'scheduledEndTime' => job.Scheduled_End_Time__c,
                'latitude' => lat,
                'longitude' => lng,
                'gpsRecorded' => (lat != null && lng != null),
                'slaRemainingHours' => remHrs
            },
            'parentWorkOrder' => job.Work_Order__c != null ? new Map<String, Object>{
                'id' => job.Work_Order__c,
                'name' => job.Work_Order__r.Name,
                'status' => parentWorkOrderStatus
            } : null
        };
    }

    /**
     * Mark Service Appointment Incomplete with Description and Reason
     */
    public static Map<String, Object> executeMarkIncomplete(String appointmentIdentifier, Map<String, Object> payload) {
        if (String.isBlank(appointmentIdentifier)) {
            return new Map<String, Object>{
                'success' => false,
                'error' => 'Service appointment identifier is required.'
            };
        }

        String cleanId = appointmentIdentifier.trim();
        List<Service_Job__c> jobs = [
            SELECT Id, Name, Status__c, Priority__c, Job_Type__c,
                   Scheduled_Start_Time__c, Scheduled_End_Time__c,
                   Description__c, Notes__c, Reason__c, SLA_Deadline__c,
                   Work_Order__c, Work_Order__r.Name, Work_Order__r.Status__c,
                   Technician__c, Technician__r.Name
            FROM Service_Job__c
            WHERE Id = :cleanId OR Name = :cleanId
            LIMIT 1
        ];

        if (jobs.isEmpty()) {
            return new Map<String, Object>{
                'success' => false,
                'error' => 'Service Appointment not found for identifier: ' + appointmentIdentifier
            };
        }

        Service_Job__c job = jobs[0];

        // Extract and validate description
        String description = null;
        if (payload != null) {
            if (payload.containsKey('description') && payload.get('description') != null) {
                description = String.valueOf(payload.get('description')).trim();
            } else if (payload.containsKey('incompleteDescription') && payload.get('incompleteDescription') != null) {
                description = String.valueOf(payload.get('incompleteDescription')).trim();
            } else if (payload.containsKey('reasonNotes') && payload.get('reasonNotes') != null) {
                description = String.valueOf(payload.get('reasonNotes')).trim();
            }
        }

        if (String.isBlank(description)) {
            return new Map<String, Object>{
                'success' => false,
                'error' => 'Missing required parameter: description explaining why the appointment is incomplete.'
            };
        }

        // Extract and validate reason picklist
        String reason = 'Other';
        Set<String> validReasons = new Set<String>{
            'Customer Request',
            'Duplicate Work Order',
            'Issue Resolved',
            'Customer Unavailable',
            'Required Parts Unavailable',
            'Other'
        };
        if (payload != null && payload.containsKey('reason') && payload.get('reason') != null) {
            String inputReason = String.valueOf(payload.get('reason')).trim();
            for (String r : validReasons) {
                if (r.equalsIgnoreCase(inputReason)) {
                    reason = r;
                    break;
                }
            }
        }

        // Extract optional notes
        String notes = null;
        if (payload != null && payload.containsKey('notes') && payload.get('notes') != null) {
            notes = String.valueOf(payload.get('notes')).trim();
        }

        // Extract optional GPS coordinates
        Decimal lat = null;
        Decimal lng = null;
        if (payload != null) {
            if (payload.containsKey('latitude') && payload.get('latitude') != null) {
                lat = Decimal.valueOf(String.valueOf(payload.get('latitude')));
            } else if (payload.containsKey('checkInLatitude') && payload.get('checkInLatitude') != null) {
                lat = Decimal.valueOf(String.valueOf(payload.get('checkInLatitude')));
            }
            if (payload.containsKey('longitude') && payload.get('longitude') != null) {
                lng = Decimal.valueOf(String.valueOf(payload.get('longitude')));
            } else if (payload.containsKey('checkInLongitude') && payload.get('checkInLongitude') != null) {
                lng = Decimal.valueOf(String.valueOf(payload.get('checkInLongitude')));
            }
        }

        DateTime nowTime = DateTime.now();

        // Format Description (rich text)
        String formattedDesc = '<p><strong>[Incomplete at ' + nowTime.format('yyyy-MM-dd HH:mm:ss') + ']</strong>: ' + description.escapeHtml4() + '</p>';
        if (String.isNotBlank(job.Description__c)) {
            formattedDesc = job.Description__c + formattedDesc;
        }

        // Format Notes
        String updatedNotes = job.Notes__c;
        if (String.isNotBlank(notes)) {
            String appendNotes = '[' + nowTime.format('yyyy-MM-dd HH:mm') + ' Incomplete Note]: ' + notes;
            updatedNotes = String.isNotBlank(updatedNotes) ? (updatedNotes + '\n' + appendNotes) : appendNotes;
        }

        // Update Service Job
        Service_Job__c sjUpdate = new Service_Job__c(
            Id = job.Id,
            Status__c = 'Incomplete',
            Reason__c = reason,
            Description__c = formattedDesc,
            Notes__c = updatedNotes
        );
        if (lat != null && lng != null) {
            sjUpdate.Check_In_GPS__Latitude__s = lat;
            sjUpdate.Check_In_GPS__Longitude__s = lng;
        }
        update sjUpdate;

        // SLA remaining calculation & SLA event
        Decimal remHrs = null;
        if (job.SLA_Deadline__c != null) {
            Long diffMs = job.SLA_Deadline__c.getTime() - nowTime.getTime();
            remHrs = (Decimal.valueOf(diffMs) / 3600000).setScale(2);
        }
        try {
            DF360_SLAController.createSLAEvent(job.Id, 'Incomplete', remHrs, 'Technician marked appointment Incomplete. Reason: ' + reason + ' - ' + description);
        } catch (Exception ex) {
            System.debug('Warning: SLA event logging skipped: ' + ex.getMessage());
        }

        // Sync Parent Work Order
        String parentWoStatus = null;
        if (job.Work_Order__c != null) {
            parentWoStatus = job.Work_Order__r.Status__c;
            if (parentWoStatus == 'In Progress' || parentWoStatus == 'Assigned' || parentWoStatus == 'New') {
                try {
                    update new Work_Order__c(
                        Id = job.Work_Order__c,
                        Status__c = 'Temporarily Paused'
                    );
                    parentWoStatus = 'Temporarily Paused';
                } catch (Exception ex) {
                    System.debug('Warning: Could not update parent Work Order to Temporarily Paused: ' + ex.getMessage());
                }
            }
        }

        // Create Job_Activity__c record for audit trail
        try {
            String actDesc = 'Marked Incomplete. Reason: ' + reason + '. ' + description;
            if (String.isNotBlank(notes)) actDesc += ' | Notes: ' + notes;
            insert new Job_Activity__c(
                Service_Job__c = job.Id,
                Activity_Type__c = 'Observation',
                Description__c = actDesc
            );
        } catch (Exception ex) {
            System.debug('Warning: Job_Activity__c creation failed: ' + ex.getMessage());
        }

        return new Map<String, Object>{
            'success' => true,
            'message' => 'Service Appointment marked as Incomplete successfully.',
            'serviceAppointment' => new Map<String, Object>{
                'id' => job.Id,
                'name' => job.Name,
                'previousStatus' => job.Status__c,
                'status' => 'Incomplete',
                'reason' => reason,
                'description' => description,
                'internalNotes' => notes,
                'updatedAt' => nowTime,
                'parentWorkOrder' => (job.Work_Order__c != null ? new Map<String, Object>{
                    'id' => job.Work_Order__c,
                    'name' => job.Work_Order__r.Name,
                    'status' => parentWoStatus
                } : null),
                'latitude' => lat,
                'longitude' => lng
            }
        };
    }

    private static void writeResponse(RestResponse res, Object payload) {
        if (res != null) {
            res.responseBody = Blob.valueOf(JSON.serialize(payload));
        }
    }
}
