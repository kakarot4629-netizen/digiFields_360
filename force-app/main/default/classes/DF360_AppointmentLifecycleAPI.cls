@RestResource(urlMapping='/df360/v1/service-appointments/*')
global with sharing class DF360_AppointmentLifecycleAPI {

    /**
     * POST  /services/apexrest/df360/v1/service-appointments/{id}/check-in
     * POST  /services/apexrest/df360/v1/service-appointments/{id}/status
     * POST  /services/apexrest/df360/v1/service-appointments/{id}/complete
     * POST  /services/apexrest/df360/v1/service-appointments/{id}/incomplete
     * POST  /services/apexrest/df360/v1/service-appointments/{id}/photos
     * PATCH works the same as POST on every route.
     *
     * {id} is the Service_Job__c Id or its Name (e.g. SA-0000029).
     * An unknown route returns 404. (Before, anything that did not match fell
     * through to check-in, so a call to /complete or /status checked the job in.)
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
                    try {
                        body = (Map<String, Object>) JSON.deserializeUntyped(bodyStr);
                    } catch (Exception jsonEx) {
                        respond(res, 400, failure('BAD_REQUEST', 'Request body is not valid JSON.'));
                        return;
                    }
                }
            }

            // /df360/v1/service-appointments/{identifier}/{action}
            String sub = String.isBlank(uri) ? '' : uri.substringAfter('/df360/v1/service-appointments/').removeEnd('/');
            String appointmentId = sub.contains('/') ? sub.substringBefore('/') : sub;
            String action = sub.contains('/') ? sub.substringAfter('/').toLowerCase() : '';

            if (String.isBlank(appointmentId)) {
                appointmentId = firstNonBlank(body, new List<String>{ 'appointmentId', 'serviceAppointmentId', 'id' });
            }
            if (String.isBlank(appointmentId)) {
                respond(res, 400, failure('BAD_REQUEST', 'Missing service appointment identifier in URL or request body.'));
                return;
            }
            appointmentId = appointmentId.trim();

            Map<String, Object> result;
            if (action == 'photos' || action == 'photo') {
                result = executePhotoUpload(appointmentId, body);
            } else if (action == 'check-in') {
                result = executeCheckIn(appointmentId, body);
            } else if (action == 'status' || action == '') {
                result = executeStatusUpdate(appointmentId, body);
            } else if (action == 'complete') {
                result = executeComplete(appointmentId, body);
            } else if (action == 'incomplete') {
                result = executeMarkIncomplete(appointmentId, body);
            } else {
                respond(res, 404, failure('UNKNOWN_ROUTE',
                    'Unknown action "' + action + '". Use check-in, status, complete, incomplete or photos.'));
                return;
            }
            respond(res, statusFor(result), result);

        } catch (InputException e) {
            respond(res, 400, failure('BAD_REQUEST', e.getMessage()));
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DF360_AppointmentLifecycleAPI: ' + e.getMessage() + '\n' + e.getStackTraceString());
            respond(res, 500, failure('SERVER_ERROR', e.getMessage()));
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
                'error' => e.getMessage()
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
        Id cleanedIdAsId = asIdOrNull(cleanedId); // Id = :<non-Id text> throws "invalid ID field", so names are matched separately

        // 1. Identify Caller Technician
        Id targetUserId = UserInfo.getUserId();
        String targetUserName = UserInfo.getName();
        String targetUserEmail = UserInfo.getUserEmail();
        Id myTechId = null;

        if (String.isNotBlank(technicianIdParam)) {
            String cleanTech = technicianIdParam.trim();
            Id cleanTechAsId = asIdOrNull(cleanTech);
            List<Technician__c> searchedTechs = [
                SELECT Id, Name, User__c, User__r.Name, User__r.Email
                FROM Technician__c
                WHERE Id = :cleanTechAsId OR Name = :cleanTech OR Employee_Code__c = :cleanTech OR User__c = :cleanTechAsId
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
            WHERE Id = :cleanedIdAsId OR Name = :cleanedId
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
        Id cleanIdAsId = asIdOrNull(cleanId); // Id = :<non-Id text> throws "invalid ID field", so names are matched separately
        List<Service_Job__c> jobs = [
            SELECT Id, Name, Status__c, Before_Photo_URL__c, After_Photo_URL__c
            FROM Service_Job__c
            WHERE Id = :cleanIdAsId OR Name = :cleanId
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
        Id cleanIdAsId = asIdOrNull(cleanId); // Id = :<non-Id text> throws "invalid ID field", so names are matched separately
        List<Service_Job__c> jobs = [
            SELECT Id, Name,
                   Before_Photo_URL__c, Before_Photo_Id__c, Before_Photo_Timestamp__c,
                   After_Photo_URL__c, After_Photo_Id__c, After_Photo_Timestamp__c
            FROM Service_Job__c
            WHERE Id = :cleanIdAsId OR Name = :cleanId
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

    // =====================================================================
    // Service appointment updates from the mobile app
    // =====================================================================

    public class InputException extends Exception {}

    private static final Set<String> ALLOWED_STATUSES = new Set<String>{
        'New', 'Assigned', 'En Route', 'On Site', 'In Progress',
        'Parts Awaited', 'Completed', 'Cancelled', 'In Complete'
    };
    // Once a job is Completed or Cancelled, the app cannot change it any more.
    private static final Set<String> CLOSED_STATUSES = new Set<String>{ 'Completed', 'Cancelled' };
    private static final Integer MAX_CLOCK_SKEW_MINUTES = 5;

    /**
     * Status change: { "status", "notes", "customerNotes", plus the fields of
     * check-in / complete / incomplete when the status is one of those }.
     * Sends On Site / In Progress (first time), Completed and In Complete to
     * their own handlers, so every way of setting a status follows the same rules.
     */
    public static Map<String, Object> executeStatusUpdate(String appointmentIdentifier, Map<String, Object> payload) {
        payload = payload == null ? new Map<String, Object>() : payload;
        String rawStatus = str(payload.get('status'));
        if (String.isBlank(rawStatus)) {
            return failure('BAD_REQUEST', 'status is required.');
        }
        String status = normalizeStatus(rawStatus);
        if (status == null) {
            return failure('BAD_REQUEST', 'Unknown status "' + rawStatus + '". Allowed: '
                + String.join(new List<String>(ALLOWED_STATUSES), ', ') + '.');
        }
        if (status == 'In Complete') return executeMarkIncomplete(appointmentIdentifier, payload);
        if (status == 'Completed') return executeComplete(appointmentIdentifier, payload);

        Service_Job__c job = findJob(appointmentIdentifier);
        if (job == null) return notFound(appointmentIdentifier);

        if ((status == 'On Site' || status == 'In Progress') && job.Check_In_Time__c == null
                && !CLOSED_STATUSES.contains(job.Status__c)) {
            return executeCheckIn(appointmentIdentifier, payload);
        }
        if (job.Status__c == status) {
            // Same status sent again (e.g. offline replay): nothing to change.
            return success('Status is already ' + status + '.', job, job.Status__c);
        }
        if (CLOSED_STATUSES.contains(job.Status__c)) {
            return failure('INVALID_STATUS', 'Appointment is already ' + job.Status__c
                + ' and cannot be changed to ' + status + '.');
        }

        Service_Job__c upd = new Service_Job__c(Id = job.Id, Status__c = status);
        String notes = str(payload.get('notes'));
        if (String.isNotBlank(notes)) upd.Notes__c = appendNote(job.Notes__c, status, notes, 5000);
        String customerNotes = str(payload.get('customerNotes'));
        if (String.isNotBlank(customerNotes)) upd.Customer_Notes__c = appendNote(job.Customer_Notes__c, status, customerNotes, 2000);
        update upd;

        if (status == 'Parts Awaited') {
            logSlaEvent(job, 'Parts Awaited', DateTime.now(), 'Technician is waiting for parts');
        }
        return success('Status updated to ' + status + '.', job, job.Status__c);
    }

    /**
     * Check-in: { "latitude", "longitude", "checkInTime" (ISO, from the phone), "status", "notes" }.
     * Keeps the first arrival time and GPS: a repeat or offline replay does not move them.
     */
    public static Map<String, Object> executeCheckIn(String appointmentIdentifier, Map<String, Object> payload) {
        payload = payload == null ? new Map<String, Object>() : payload;
        Service_Job__c job = findJob(appointmentIdentifier);
        if (job == null) return notFound(appointmentIdentifier);
        if (CLOSED_STATUSES.contains(job.Status__c)) {
            return failure('INVALID_STATUS', 'Cannot check in: appointment is already ' + job.Status__c + '.');
        }

        String targetStatus = 'On Site';
        String requested = str(payload.get('status'));
        if (String.isNotBlank(requested)) {
            String normalized = normalizeStatus(requested);
            if (normalized != 'On Site' && normalized != 'In Progress') {
                return failure('BAD_REQUEST', 'Check-in status must be On Site or In Progress.');
            }
            targetStatus = normalized;
        }

        DateTime checkInTime = readTime(payload, new List<String>{ 'checkInTime', 'timestamp' });
        Decimal lat = readDecimal(payload, new List<String>{ 'latitude', 'checkInLatitude' });
        Decimal lng = readDecimal(payload, new List<String>{ 'longitude', 'checkInLongitude' });

        Boolean firstCheckIn = (job.Check_In_Time__c == null);
        Service_Job__c upd = new Service_Job__c(Id = job.Id, Status__c = targetStatus);
        if (firstCheckIn) {
            upd.Check_In_Time__c = checkInTime;
            if (lat != null && lng != null) {
                upd.Check_In_GPS__Latitude__s = lat;
                upd.Check_In_GPS__Longitude__s = lng;
            }
        }
        String notes = str(payload.get('notes'));
        if (String.isNotBlank(notes)) upd.Notes__c = appendNote(job.Notes__c, 'Check-in', notes, 5000);
        update upd;

        if (firstCheckIn) {
            logSlaEvent(job, 'On Site', checkInTime, 'Technician checked in from the mobile app');
            moveWorkOrderTo(job, new Set<String>{ 'New', 'Assigned' }, 'In Progress');
        }
        Map<String, Object> result = success(
            firstCheckIn ? 'Technician checked in.' : 'Technician was already checked in; status updated.',
            job, job.Status__c);
        result.put('gpsRecorded', firstCheckIn && lat != null && lng != null);
        return result;
    }

    /**
     * Complete: { "completedTime", "resolutionNotes", "resolutionTimeMinutes", "isFirstTimeFix",
     *             "customerNotes", "customerSignerName", "customerSignatureUrl",
     *             "customerRating", "customerFeedbackTags" }
     * (older names "technicianNotes" and "resolutionTimeMin" are still accepted).
     * Then completes the parent work order if no other job on it is still open.
     */
    public static Map<String, Object> executeComplete(String appointmentIdentifier, Map<String, Object> payload) {
        payload = payload == null ? new Map<String, Object>() : payload;
        Service_Job__c job = findJob(appointmentIdentifier);
        if (job == null) return notFound(appointmentIdentifier);
        if (job.Status__c == 'Completed') {
            Map<String, Object> already = success('Appointment was already completed.', job, job.Status__c);
            already.put('alreadyCompleted', true);
            return already;
        }
        if (job.Status__c == 'Cancelled') {
            return failure('INVALID_STATUS', 'A cancelled appointment cannot be completed.');
        }

        DateTime completedTime = readTime(payload, new List<String>{ 'completedTime', 'timestamp' });
        if (job.Check_In_Time__c != null && completedTime < job.Check_In_Time__c) {
            return failure('INVALID_TIMESTAMP', 'Completion time is earlier than the check-in time.');
        }

        Service_Job__c upd = new Service_Job__c(Id = job.Id, Status__c = 'Completed', Completed_Time__c = completedTime);

        if (payload.get('isFirstTimeFix') != null) {
            upd.Is_First_Time_Fix__c = toBoolean(payload.get('isFirstTimeFix'));
        }
        // Left empty, the Service Job trigger works the minutes out from check-in and completion time.
        Decimal minutes = readDecimal(payload, new List<String>{ 'resolutionTimeMinutes', 'resolutionTimeMin' });
        if (minutes != null) {
            if (minutes < 0) return failure('BAD_REQUEST', 'resolutionTimeMinutes cannot be negative.');
            upd.Resolution_Time_Min__c = minutes.round(System.RoundingMode.HALF_UP);
        }
        String signatureUrl = str(payload.get('customerSignatureUrl'));
        if (String.isNotBlank(signatureUrl)) {
            if (!signatureUrl.startsWithIgnoreCase('http')) {
                return failure('BAD_REQUEST', 'customerSignatureUrl must be a link (http/https).');
            }
            upd.Customer_Signature_URL__c = signatureUrl;
        }
        String resolution = firstNonBlank(payload, new List<String>{ 'resolutionNotes', 'technicianNotes', 'notes' });
        if (String.isNotBlank(resolution)) {
            upd.Notes__c = appendNote(job.Notes__c, 'Resolution', resolution, 5000);
        }
        String customerNotes = str(payload.get('customerNotes'));
        String signer = str(payload.get('customerSignerName'));
        String signOff = (String.isNotBlank(customerNotes) ? customerNotes : '')
            + (String.isNotBlank(signer) ? (String.isNotBlank(customerNotes) ? ' ' : '') + '(Signed by ' + signer + ')' : '');
        if (String.isNotBlank(signOff)) {
            upd.Customer_Notes__c = appendNote(job.Customer_Notes__c, 'Sign-off', signOff, 2000);
        }

        // A rating given on the phone at sign-off is saved as the CSAT response.
        // CSAT_Sent__c stops the trigger and the flow from also sending a WhatsApp CSAT request.
        Decimal rating = readDecimal(payload, new List<String>{ 'customerRating', 'rating' });
        if (rating != null) {
            if (rating < 1 || rating > 5) return failure('BAD_REQUEST', 'customerRating must be between 1 and 5.');
            upd.CSAT_Sent__c = true;
        }

        update upd;

        if (rating != null) {
            String tags = str(payload.get('customerFeedbackTags'));
            insert new CSAT__c(
                Service_Job__c = job.Id,
                Rating__c = rating.round(System.RoundingMode.HALF_UP),
                Comment__c = String.isNotBlank(tags) ? tags.abbreviate(2000) : null,
                Is_Responded__c = true,
                Response_Date__c = completedTime,
                Via_WhatsApp__c = false
            );
        }

        logSlaEvent(job, 'Resolved', completedTime, 'Job completed from the mobile app');
        rollupWorkOrder(job.Work_Order__c);
        return success('Appointment completed.', job, job.Status__c);
    }

    /**
     * Incomplete: { "reason", "description", "notes", "latitude", "longitude" }.
     * Writes the picklist value 'In Complete' (the old code wrote 'Incomplete', which is
     * not a value of the picklist). Does not overwrite the check-in GPS.
     */
    public static Map<String, Object> executeMarkIncomplete(String appointmentIdentifier, Map<String, Object> payload) {
        payload = payload == null ? new Map<String, Object>() : payload;
        Service_Job__c job = findJob(appointmentIdentifier);
        if (job == null) return notFound(appointmentIdentifier);
        if (job.Status__c == 'In Complete') {
            return success('Appointment is already marked In Complete.', job, job.Status__c);
        }
        if (CLOSED_STATUSES.contains(job.Status__c)) {
            return failure('INVALID_STATUS', 'Appointment is already ' + job.Status__c + ' and cannot be marked In Complete.');
        }

        String reason = 'Other';
        String inputReason = str(payload.get('reason'));
        Set<String> validReasons = new Set<String>{
            'Customer Request', 'Duplicate Work Order', 'Issue Resolved',
            'Customer Unavailable', 'Required Parts Unavailable', 'Other'
        };
        if (String.isNotBlank(inputReason)) {
            for (String r : validReasons) {
                if (r.equalsIgnoreCase(inputReason)) reason = r;
            }
        }

        String description = firstNonBlank(payload, new List<String>{ 'description', 'incompleteDescription', 'reasonNotes' });
        String notes = str(payload.get('notes'));
        if (String.isBlank(description)) description = String.isNotBlank(notes) ? notes : null;
        if (String.isBlank(description)) {
            return failure('BAD_REQUEST', 'description is required: explain why the appointment could not be completed.');
        }

        Decimal lat = readDecimal(payload, new List<String>{ 'latitude', 'checkInLatitude' });
        Decimal lng = readDecimal(payload, new List<String>{ 'longitude', 'checkInLongitude' });
        DateTime nowTime = DateTime.now();

        String formattedDesc = '<p><strong>[In Complete ' + nowTime.format('yyyy-MM-dd HH:mm') + '] '
            + reason.escapeHtml4() + ':</strong> ' + description.escapeHtml4() + '</p>';
        if (String.isNotBlank(job.Description__c)) formattedDesc = job.Description__c + formattedDesc;

        Service_Job__c upd = new Service_Job__c(
            Id = job.Id,
            Status__c = 'In Complete',
            Reason__c = reason,
            Description__c = formattedDesc
        );
        if (String.isNotBlank(notes)) upd.Notes__c = appendNote(job.Notes__c, 'In Complete', notes, 5000);
        update upd;

        logSlaEvent(job, 'Incomplete', nowTime, 'Marked In Complete. Reason: ' + reason + ' - ' + description);
        moveWorkOrderTo(job, new Set<String>{ 'New', 'Assigned', 'In Progress' }, 'Temporarily Paused');

        try {
            String actDesc = 'Marked In Complete. Reason: ' + reason + '. ' + description;
            if (String.isNotBlank(notes)) actDesc += ' | Notes: ' + notes;
            if (lat != null && lng != null) actDesc += ' | Location: ' + lat + ', ' + lng;
            insert new Job_Activity__c(
                Service_Job__c = job.Id,
                Activity_Type__c = 'Observation',
                Description__c = actDesc.abbreviate(32000)
            );
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'Job_Activity__c not created: ' + ex.getMessage());
        }
        return success('Appointment marked In Complete.', job, job.Status__c);
    }

    /**
     * Completes the work order once every job on it is Completed or Cancelled
     * (and at least one is Completed). Time logged = total resolution minutes.
     * Returns the work order's status. Also used by DF360_ServiceJobController.
     */
    public static String rollupWorkOrder(Id workOrderId) {
        if (workOrderId == null) return null;
        Work_Order__c wo = [SELECT Id, Status__c FROM Work_Order__c WHERE Id = :workOrderId];
        if (CLOSED_STATUSES.contains(wo.Status__c)) return wo.Status__c;

        Integer openJobs = [
            SELECT COUNT() FROM Service_Job__c
            WHERE Work_Order__c = :workOrderId AND Status__c NOT IN :CLOSED_STATUSES
        ];
        if (openJobs > 0) return wo.Status__c;

        AggregateResult agg = [
            SELECT COUNT(Id) completedJobs, SUM(Resolution_Time_Min__c) totalMinutes
            FROM Service_Job__c
            WHERE Work_Order__c = :workOrderId AND Status__c = 'Completed'
        ];
        if ((Integer) agg.get('completedJobs') == 0) return wo.Status__c; // all cancelled: leave it to the dispatcher

        Work_Order__c upd = new Work_Order__c(Id = workOrderId, Status__c = 'Completed', Completed_Date__c = DateTime.now());
        Decimal total = (Decimal) agg.get('totalMinutes');
        if (total != null) upd.Time_Logged_Minutes__c = total;
        update upd;
        return 'Completed';
    }

    // ----------------------------------------------------------------- helpers

    public static String normalizeStatus(String raw) {
        if (String.isBlank(raw)) return null;
        String key = raw.trim().toUpperCase().replace('_', ' ').replace('-', ' ').normalizeSpace();
        Map<String, String> aliases = new Map<String, String>{
            'NEW' => 'New', 'ASSIGNED' => 'Assigned',
            'EN ROUTE' => 'En Route', 'ENROUTE' => 'En Route', 'TRAVELLING' => 'En Route', 'TRAVELING' => 'En Route',
            'ON SITE' => 'On Site', 'ONSITE' => 'On Site', 'ARRIVED' => 'On Site',
            'IN PROGRESS' => 'In Progress', 'INPROGRESS' => 'In Progress', 'STARTED' => 'In Progress',
            'PARTS AWAITED' => 'Parts Awaited', 'WAITING FOR PARTS' => 'Parts Awaited',
            'COMPLETED' => 'Completed', 'COMPLETE' => 'Completed', 'DONE' => 'Completed',
            'CANCELLED' => 'Cancelled', 'CANCELED' => 'Cancelled',
            'IN COMPLETE' => 'In Complete', 'INCOMPLETE' => 'In Complete'
        };
        return aliases.get(key);
    }

    private static Service_Job__c findJob(String identifier) {
        if (String.isBlank(identifier)) return null;
        String clean = identifier.trim();
        Id cleanAsId = asIdOrNull(clean);
        List<Service_Job__c> jobs = [
            SELECT Id, Name, Status__c, Check_In_Time__c, Completed_Time__c, Notes__c, Customer_Notes__c,
                   Description__c, Reason__c, SLA_Deadline__c, CSAT_Sent__c,
                   Work_Order__c, Work_Order__r.Name, Work_Order__r.Status__c
            FROM Service_Job__c
            WHERE Id = :cleanAsId OR Name = :clean
            LIMIT 1
        ];
        return jobs.isEmpty() ? null : jobs[0];
    }

    private static Id asIdOrNull(String value) {
        if (String.isBlank(value)) return null;
        try {
            return Id.valueOf(value.trim());
        } catch (Exception ex) {
            return null;
        }
    }

    private static void moveWorkOrderTo(Service_Job__c job, Set<String> fromStatuses, String toStatus) {
        if (job.Work_Order__c == null || !fromStatuses.contains(job.Work_Order__r.Status__c)) return;
        update new Work_Order__c(Id = job.Work_Order__c, Status__c = toStatus);
    }

    private static void logSlaEvent(Service_Job__c job, String eventType, DateTime at, String note) {
        Decimal remaining = null;
        if (job.SLA_Deadline__c != null && at != null) {
            remaining = (Decimal.valueOf(job.SLA_Deadline__c.getTime() - at.getTime()) / 3600000).setScale(2);
        }
        try {
            DF360_SLAController.createSLAEvent(job.Id, eventType, remaining, note);
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'SLA event not created: ' + ex.getMessage());
        }
    }

    private static String appendNote(String existing, String label, String text, Integer maxLength) {
        String line = '[' + DateTime.now().format('yyyy-MM-dd HH:mm') + ' ' + label + '] ' + text.trim();
        String combined = String.isBlank(existing) ? line : existing + '\n' + line;
        return combined.length() > maxLength ? combined.right(maxLength) : combined; // keep the newest notes
    }

    private static DateTime readTime(Map<String, Object> payload, List<String> keys) {
        DateTime nowTime = DateTime.now();
        for (String k : keys) {
            String v = str(payload.get(k));
            if (String.isBlank(v)) continue;
            DateTime parsed;
            try {
                parsed = (DateTime) JSON.deserialize('"' + v + '"', DateTime.class);
            } catch (Exception ex) {
                throw new InputException('Invalid ISO date-time for ' + k + ': ' + v);
            }
            if (parsed > nowTime.addMinutes(MAX_CLOCK_SKEW_MINUTES)) {
                throw new InputException(k + ' is in the future. Check the phone clock.');
            }
            return parsed;
        }
        return nowTime;
    }

    private static Decimal readDecimal(Map<String, Object> payload, List<String> keys) {
        for (String k : keys) {
            String v = str(payload.get(k));
            if (String.isBlank(v)) continue;
            try {
                return Decimal.valueOf(v);
            } catch (Exception ex) {
                throw new InputException('Invalid number for ' + k + ': ' + v);
            }
        }
        return null;
    }

    private static Boolean toBoolean(Object v) {
        if (v instanceof Boolean) return (Boolean) v;
        return v != null && String.valueOf(v).trim().equalsIgnoreCase('true');
    }

    private static String str(Object v) {
        return v == null ? null : String.valueOf(v).trim();
    }

    private static String firstNonBlank(Map<String, Object> payload, List<String> keys) {
        for (String k : keys) {
            String v = str(payload.get(k));
            if (String.isNotBlank(v)) return v;
        }
        return null;
    }

    /** Re-reads the job after the update, so the app gets what Salesforce actually saved. */
    private static Map<String, Object> success(String message, Service_Job__c before, String previousStatus) {
        Service_Job__c j = [
            SELECT Id, Name, Status__c, Reason__c, Check_In_Time__c, Completed_Time__c,
                   Is_First_Time_Fix__c, Resolution_Time_Min__c, Customer_Signature_URL__c,
                   Work_Order__c, Work_Order__r.Name, Work_Order__r.Status__c
            FROM Service_Job__c WHERE Id = :before.Id
        ];
        Map<String, Object> appointment = new Map<String, Object>{
            'id' => j.Id,
            'name' => j.Name,
            'previousStatus' => previousStatus,
            'status' => j.Status__c,
            'reason' => j.Reason__c,
            'checkInTime' => j.Check_In_Time__c,
            'completedTime' => j.Completed_Time__c,
            'isFirstTimeFix' => j.Is_First_Time_Fix__c,
            'resolutionTimeMinutes' => j.Resolution_Time_Min__c,
            'customerSignatureUrl' => j.Customer_Signature_URL__c
        };
        Map<String, Object> workOrder = j.Work_Order__c == null ? null : new Map<String, Object>{
            'id' => j.Work_Order__c,
            'name' => j.Work_Order__r.Name,
            'status' => j.Work_Order__r.Status__c
        };
        return new Map<String, Object>{
            'success' => true,
            'message' => message,
            'serviceAppointment' => appointment,
            'appointment' => appointment,       // older key, kept for existing callers
            'parentWorkOrder' => workOrder
        };
    }

    private static Map<String, Object> failure(String code, String message) {
        return new Map<String, Object>{ 'success' => false, 'errorCode' => code, 'error' => message };
    }

    private static Map<String, Object> notFound(String identifier) {
        return failure('NOT_FOUND', 'Service appointment not found: ' + identifier);
    }

    private static Integer statusFor(Map<String, Object> result) {
        if (result.get('success') == true) return 200;
        String code = String.valueOf(result.get('errorCode'));
        if (code == 'NOT_FOUND') return 404;
        if (code == 'INVALID_STATUS') return 409;
        String err = String.valueOf(result.get('error'));
        if (code == 'null' && err != null && err.containsIgnoreCase('not found')) return 404;
        return 400;
    }

    private static void respond(RestResponse res, Integer statusCode, Map<String, Object> payload) {
        if (res == null) return;
        res.statusCode = statusCode;
        res.responseBody = Blob.valueOf(JSON.serialize(payload));
    }

    private static void writeResponse(RestResponse res, Object payload) {
        if (res != null) {
            res.responseBody = Blob.valueOf(JSON.serialize(payload));
        }
    }
}