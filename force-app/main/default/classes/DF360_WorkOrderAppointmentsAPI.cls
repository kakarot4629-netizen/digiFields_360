@RestResource(urlMapping='/df360/v1/work-orders/*')
global with sharing class DF360_WorkOrderAppointmentsAPI {

    /**
     * GET /services/apexrest/df360/v1/work-orders/my
     *   -> Returns every Service Appointment where the logged-in technician is an assigned
     *      resource (directly, through a crew, or as the job's lead technician), grouped
     *      under its Work Order. Work orders with no such appointment are not returned.
     *   -> Includes full Assigned Resources team roster (multi-technician / crew).
     *   -> Optional query parameters:
     *        ?status=Assigned             only appointments in that status
     *        ?technicianId=<Id>           act for this technician instead of the logged-in user
     *        ?includeAllAppointments=true also list the work order's other appointments
     *                                     (flagged isMyAppointment = false)
     *        ?format=flat                 serviceAppointments, workOrders, cases and
     *                                     serviceAddresses as separate lists at the same level
     *                                     as technician, joined by Ids (see FlatResult)
     *
     * GET /services/apexrest/df360/v1/work-orders/assigned
     *   -> Convenient shortcut that returns only assigned records (Status = 'Assigned').
     *
     * GET /services/apexrest/df360/v1/work-orders/{workOrderId}/service-appointments
     *   -> Returns specific Work Order details and its child Service Appointments.
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
            String workOrderId = (req != null && req.params != null) ? req.params.get('workOrderId') : null;
            String statusParam = (req != null && req.params != null) ? req.params.get('status') : null;
            String techParam = (req != null && req.params != null) ? req.params.get('technicianId') : null;
            Boolean includeAll = (req != null && req.params != null
                && 'true'.equalsIgnoreCase(req.params.get('includeAllAppointments')));
            Boolean flatFormat = (req != null && req.params != null
                && 'flat'.equalsIgnoreCase(req.params.get('format')));

            if (String.isBlank(workOrderId) && String.isNotBlank(uri)) {
                String sub = uri.substringAfter('/df360/v1/work-orders/');
                if (String.isNotBlank(sub)) {
                    if (sub.contains('/')) {
                        workOrderId = sub.substringBefore('/');
                    } else {
                        workOrderId = sub;
                    }
                }
            }

            // Route 1: Logged-in Technician's Assigned Work Orders & Appointments
            if (String.isBlank(workOrderId) || workOrderId.equalsIgnoreCase('my') || workOrderId.equalsIgnoreCase('assigned')) {
                if (String.isBlank(statusParam) && String.isNotBlank(workOrderId) && workOrderId.equalsIgnoreCase('assigned')) {
                    statusParam = 'Assigned';
                }
                Map<String, Object> myResults = getMyWorkOrdersWithAppointments(statusParam, techParam, includeAll, flatFormat);
                if (res != null) res.statusCode = 200;
                writeResponse(res, myResults);
                return;
            }

            // Route: Direct Briefing Query (/df360/v1/work-orders/{id}/briefing)
            if (String.isNotBlank(uri) && uri.endsWith('/briefing')) {
                Map<String, Object> bRes = getWorkOrderBriefing(workOrderId);
                if (res != null) res.statusCode = (bRes.get('success') == true ? 200 : 404);
                writeResponse(res, bRes);
                return;
            }

            // Route 2: Specific Work Order Query by ID or Number
            Map<String, Object> result = getWorkOrderWithAppointments(workOrderId, statusParam, techParam);

            if (result.get('success') == false) {
                if (res != null) res.statusCode = 404;
            } else {
                if (res != null) res.statusCode = 200;
            }
            writeResponse(res, result);

        } catch (Exception e) {
            if (res != null) res.statusCode = 500;
            writeResponse(res, new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage()
            });
        }
    }

    private static void writeResponse(RestResponse res, Object payload) {
        if (res != null) {
            res.responseBody = Blob.valueOf(JSON.serialize(payload));
        }
    }

    /**
     * Dynamic Logged-in Technician Query:
     * Returns ONLY Work Orders and Service Appointments assigned to the authenticated user/technician.
     * Supports both direct assignment and multi-resource crew assignment.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getMyWorkOrdersWithAppointments(String statusFilter) {
        return getMyWorkOrdersWithAppointments(statusFilter, null);
    }

    public static Map<String, Object> getMyWorkOrdersWithAppointments(String statusFilter, String technicianIdParam) {
        return getMyWorkOrdersWithAppointments(statusFilter, technicianIdParam, false);
    }

    /**
     * Service appointments where the technician is an assigned resource, grouped under
     * their work orders. The technician counts as assigned when any of these is true:
     *   1. an Assigned_Resource__c record names the technician;
     *   2. an Assigned_Resource__c record names a crew the technician is a member of;
     *   3. the technician is the job's lead technician (Service_Job__c.Technician__c).
     *      The Assigned Resource trigger keeps this in step with the lead resource, and
     *      jobs created without Assigned_Resource__c records only have this.
     *
     * Each work order lists only those appointments. With includeAllAppointments = true it
     * also lists the work order's other appointments, flagged isMyAppointment = false.
     * Work orders where the technician has no appointment are not returned (before, every
     * work order whose Assigned_Technician__c was the user came back, often with no
     * appointments at all).
     */
    public static Map<String, Object> getMyWorkOrdersWithAppointments(String statusFilter, String technicianIdParam, Boolean includeAllAppointments) {
        return getMyWorkOrdersWithAppointments(statusFilter, technicianIdParam, includeAllAppointments, false);
    }

    public static Map<String, Object> getMyWorkOrdersWithAppointments(String statusFilter, String technicianIdParam, Boolean includeAllAppointments, Boolean flatFormat) {
        Id targetUserId = UserInfo.getUserId();
        String targetUserName = UserInfo.getName();
        String targetUserEmail = UserInfo.getUserEmail();

        Technician__c tech = resolveTechnician(technicianIdParam);
        Id myTechId = tech != null ? tech.Id : null;
        if (tech != null && tech.User__c != null) {
            targetUserId = tech.User__c;
            if (tech.User__r != null && String.isNotBlank(tech.User__r.Name)) {
                targetUserName = tech.User__r.Name;
                targetUserEmail = tech.User__r.Email;
            }
        }

        // ---- 1. Appointments where the technician is an assigned resource
        Map<Id, Service_Crew_Member__c> myCrewMap = new Map<Id, Service_Crew_Member__c>();
        Set<Id> myJobIds = new Set<Id>();
        if (myTechId != null) {
            for (Service_Crew_Member__c m : [
                SELECT Id, Service_Crew__c, Service_Crew__r.Name, Is_Leader__c
                FROM Service_Crew_Member__c
                WHERE Technician__c = :myTechId
            ]) {
                myCrewMap.put(m.Service_Crew__c, m);
            }

            for (Assigned_Resource__c ar : [
                SELECT Service_Job__c FROM Assigned_Resource__c
                WHERE Technician__c = :myTechId AND Service_Job__c != null
                LIMIT 2000
            ]) {
                myJobIds.add(ar.Service_Job__c);
            }

            if (!myCrewMap.isEmpty()) {
                for (Assigned_Resource__c ar : [
                    SELECT Service_Job__c FROM Assigned_Resource__c
                    WHERE Service_Crew__c IN :myCrewMap.keySet() AND Service_Job__c != null
                    LIMIT 2000
                ]) {
                    myJobIds.add(ar.Service_Job__c);
                }
            }

            for (Service_Job__c j : [
                SELECT Id FROM Service_Job__c WHERE Technician__c = :myTechId LIMIT 2000
            ]) {
                myJobIds.add(j.Id);
            }
        }

        // ---- 2. Keep those on a work order (and in the requested status)
        Set<Id> matchingJobIds = new Set<Id>();
        Set<Id> woIds = new Set<Id>();
        if (!myJobIds.isEmpty()) {
            List<Service_Job__c> myJobs = String.isNotBlank(statusFilter)
                ? [SELECT Id, Work_Order__c FROM Service_Job__c
                   WHERE Id IN :myJobIds AND Work_Order__c != null AND Status__c = :statusFilter]
                : [SELECT Id, Work_Order__c FROM Service_Job__c
                   WHERE Id IN :myJobIds AND Work_Order__c != null];
            for (Service_Job__c j : myJobs) {
                matchingJobIds.add(j.Id);
                woIds.add(j.Work_Order__c);
            }
        }

        // ---- 3. Work orders with their appointments
        List<Map<String, Object>> woList = new List<Map<String, Object>>();
        FlatResult flat = new FlatResult();
        Integer appointmentTotal = 0;
        if (!woIds.isEmpty()) {
            for (Work_Order__c wo : queryWorkOrdersWithAllJobs(woIds)) {
                Map<String, Object> formatted = formatWorkOrderRecord(wo, myTechId, myCrewMap);
                List<Map<String, Object>> appts = (List<Map<String, Object>>) formatted.get('serviceAppointments');

                List<Map<String, Object>> kept = new List<Map<String, Object>>();
                for (Map<String, Object> appt : appts) {
                    Boolean mine = matchingJobIds.contains((Id) appt.get('id'));
                    // Assigned only as lead technician: the roster check in formatWorkOrderRecord
                    // already marks it as "Direct"; make sure every kept appointment says it is mine.
                    if (mine) {
                        appt.put('isMyAppointment', true);
                        appt.put('isAssignedToMe', true);
                    }
                    if (mine || includeAllAppointments == true) {
                        kept.add(appt);
                    }
                }
                appointmentTotal += kept.size();

                if (flatFormat == true) {
                    flat.add(wo, formatted, kept);
                } else {
                    formatted.put('serviceAppointments', kept);
                    formatted.put('serviceAppointmentsCount', kept.size());
                    woList.add(formatted);
                }
            }
        }

        Map<String, Object> technicianInfo = new Map<String, Object>{
            'userId' => targetUserId,
            'name' => targetUserName,
            'email' => targetUserEmail,
            'technicianId' => myTechId
        };

        if (flatFormat == true) {
            List<Map<String, Object>> sortedAppointments = flat.sortedAppointments();
            return new Map<String, Object>{
                'success' => true,
                'format' => 'flat',
                'technician' => technicianInfo,
                'statusFilter' => statusFilter,
                'technicianFilter' => technicianIdParam,
                'includeAllAppointments' => (includeAllAppointments == true),
                'totalServiceAppointments' => sortedAppointments.size(),
                'totalWorkOrders' => flat.workOrders.size(),
                'totalCases' => flat.cases.size(),
                'totalServiceAddresses' => flat.addresses.size(),
                'serviceAppointments' => sortedAppointments,
                'workOrders' => flat.workOrders,
                'cases' => flat.cases.values(),
                'serviceAddresses' => flat.addresses.values()
            };
        }

        return new Map<String, Object>{
            'success' => true,
            'technician' => technicianInfo,
            'statusFilter' => statusFilter,
            'technicianFilter' => technicianIdParam,
            'includeAllAppointments' => (includeAllAppointments == true),
            'totalWorkOrders' => woList.size(),
            'count' => woList.size(),
            'totalServiceAppointments' => appointmentTotal,
            'workOrders' => woList
        };
    }

    /**
     * Builds the flat response: appointments, work orders, cases and service addresses
     * as four lists at the same level, joined by Ids (appointment.workOrderId ->
     * workOrder.id, workOrder.caseId -> case.id, serviceAddressId -> serviceAddress.id).
     * Each case and address appears once, however many appointments point to it.
     */
    private class FlatResult {
        public List<Map<String, Object>> appointments = new List<Map<String, Object>>();
        public List<Map<String, Object>> workOrders = new List<Map<String, Object>>();
        public Map<Id, Map<String, Object>> cases = new Map<Id, Map<String, Object>>();
        public Map<Id, Map<String, Object>> addresses = new Map<Id, Map<String, Object>>();

        public void add(Work_Order__c wo, Map<String, Object> formatted, List<Map<String, Object>> kept) {
            Id caseId = wo.Case__c;
            Id addressId = (caseId != null) ? wo.Case__r.Customer_Address__c : null;

            Map<String, Object> address = (Map<String, Object>) formatted.get('serviceAddress');
            if (addressId != null && address != null && !addresses.containsKey(addressId)) {
                addresses.put(addressId, address.clone());
            }

            Map<String, Object> caseInfo = (Map<String, Object>) formatted.get('case');
            if (caseId != null && caseInfo != null && !cases.containsKey(caseId)) {
                Map<String, Object> c = caseInfo.clone();
                c.remove('serviceAddress');
                c.put('serviceAddressId', addressId);
                cases.put(caseId, c);
            }

            List<Id> appointmentIds = new List<Id>();
            for (Map<String, Object> appt : kept) {
                Map<String, Object> a = appt.clone();
                a.remove('serviceAddress');
                // Same values as checkInTime / completedTime: left out of the flat format
                a.remove('startTime');
                a.remove('endTime');
                a.remove('actualStartTime');
                a.remove('actualEndTime');
                a.put('workOrderId', wo.Id);
                a.put('workOrderName', wo.Name);
                a.put('caseId', caseId);
                a.put('serviceAddressId', addressId);
                appointments.add(a);
                appointmentIds.add((Id) appt.get('id'));
            }

            Map<String, Object> w = ((Map<String, Object>) formatted.get('workOrder')).clone();
            w.remove('serviceAddress');
            w.remove('case');
            w.put('caseId', caseId);
            w.put('serviceAddressId', addressId);
            w.put('serviceAppointmentIds', appointmentIds);
            w.put('serviceAppointmentsCount', appointmentIds.size());
            workOrders.add(w);
        }

        /** All appointments, closest SLA deadline first (no deadline last). */
        public List<Map<String, Object>> sortedAppointments() {
            List<AppointmentSort> wrappers = new List<AppointmentSort>();
            for (Integer i = 0; i < appointments.size(); i++) {
                wrappers.add(new AppointmentSort(appointments[i], i));
            }
            wrappers.sort();
            List<Map<String, Object>> result = new List<Map<String, Object>>();
            for (AppointmentSort w : wrappers) {
                result.add(w.appointment);
            }
            return result;
        }
    }

    private class AppointmentSort implements Comparable {
        public Map<String, Object> appointment;
        public Integer originalIndex;
        public AppointmentSort(Map<String, Object> appointment, Integer originalIndex) {
            this.appointment = appointment;
            this.originalIndex = originalIndex;
        }
        public Integer compareTo(Object other) {
            AppointmentSort o = (AppointmentSort) other;
            DateTime mine = (DateTime) appointment.get('slaDeadline');
            DateTime theirs = (DateTime) o.appointment.get('slaDeadline');
            if (mine != null && theirs != null && mine != theirs) return mine < theirs ? -1 : 1;
            if (mine != null && theirs == null) return -1;
            if (mine == null && theirs != null) return 1;
            return originalIndex - o.originalIndex; // keep the original order for ties
        }
    }

    /** Work orders by Id, each with all its appointments and their assigned resources. */
    private static List<Work_Order__c> queryWorkOrdersWithAllJobs(Set<Id> woIds) {
        return [
            SELECT Id, Name, Subject__c, Status__c, Priority__c, Scheduled_Date__c, Completed_Date__c,
                   Description__c, Site_Address__c, Equipment_ID__c, Equipment_Type__c,
                   Time_Logged_Minutes__c, Technician_Notes__c, Parts_Used__c, AI_Pre_Job_Briefing__c, Briefing_Generated__c,
                   Account__c, Account__r.Name,
                   Asset__c, Asset__r.Name, Asset__r.Serial_Number__c, Asset__r.Product_Name__c, Asset__r.Product_Category__c,
                   Case__c, Case__r.CaseNumber, Case__r.Subject, Case__r.Status, Case__r.Priority,
                   Case__r.Customer_Address__c, Case__r.Customer_Address__r.Name,
                   Case__r.Customer_Address__r.Address_Type__c, Case__r.Customer_Address__r.Street_Address__c,
                   Case__r.Customer_Address__r.City__c, Case__r.Customer_Address__r.State__c,
                   Case__r.Customer_Address__r.Postal_Code__c, Case__r.Customer_Address__r.Country__c,
                   Case__r.Customer_Address__r.Landmark__c,
                   Case__r.Customer_Address__r.Latitude__c, Case__r.Customer_Address__r.Longitude__c,
                   Case__r.Customer_Address__r.Contact_Person_Name__c,
                   Case__r.Customer_Address__r.Contact_Phone__c,
                   Assigned_Technician__c, Assigned_Technician__r.Name,
                   (
                       SELECT Id, Name, Status__c, Priority__c, Job_Type__c, SLA_Deadline__c, SLA_Status__c,
                              Scheduled_Start_Time__c, Scheduled_End_Time__c,
                              Check_In_Time__c, Completed_Time__c, Resolution_Time_Min__c,
                              Notes__c, Customer_Notes__c, Customer_Signature_URL__c, Is_First_Time_Fix__c,
                              Technician__c, Technician__r.Name, Zone__c, Zone__r.Name,
                              (
                                  SELECT Id, Name, Technician__c, Technician__r.Name,
                                         Service_Crew__c, Service_Crew__r.Name,
                                         Resource_Type__c, Role__c, Is_Leader__c,
                                         Status__c, Check_In_Time__c, Actual_Hours__c
                                  FROM Assigned_Resources__r
                              )
                       FROM Service_Jobs__r
                       ORDER BY SLA_Deadline__c ASC NULLS LAST, CreatedDate DESC
                   )
            FROM Work_Order__c
            WHERE Id IN :woIds
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }

    /**
     * The technician given by Id, user Id, name or employee code; or, when none is given,
     * the technician linked to the logged-in user. Returns null if none is found.
     */
    private static Technician__c resolveTechnician(String technicianIdParam) {
        List<Technician__c> techs;
        if (String.isNotBlank(technicianIdParam)) {
            String clean = technicianIdParam.trim();
            Id cleanAsId = asIdOrNull(clean); // Id = :<text> fails for names / employee codes
            techs = [
                SELECT Id, Name, User__c, User__r.Name, User__r.Email
                FROM Technician__c
                WHERE Id = :cleanAsId OR User__c = :cleanAsId OR Name = :clean OR Employee_Code__c = :clean
                LIMIT 1
            ];
        } else {
            techs = [
                SELECT Id, Name, User__c, User__r.Name, User__r.Email
                FROM Technician__c
                WHERE User__c = :UserInfo.getUserId()
                LIMIT 1
            ];
        }
        return techs.isEmpty() ? null : techs[0];
    }

    private static Id asIdOrNull(String value) {
        if (String.isBlank(value)) return null;
        try {
            return Id.valueOf(value.trim());
        } catch (Exception ex) {
            return null;
        }
    }

    /**
     * Unified Query Method for single Work Order by ID or Number
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getWorkOrderWithAppointments(String workOrderIdentifier, String statusFilter) {
        return getWorkOrderWithAppointments(workOrderIdentifier, statusFilter, null);
    }

    public static Map<String, Object> getWorkOrderWithAppointments(String workOrderIdentifier, String statusFilter, String technicianIdParam) {
        if (String.isBlank(workOrderIdentifier)) {
            return new Map<String, Object>{
                'success' => false,
                'error' => 'Work Order Identifier is required'
            };
        }

        String cleanedId = workOrderIdentifier.trim();
        Id cleanedIdAsId = asIdOrNull(cleanedId); // Id = :<text> fails for numbers like WO-0001014

        List<Work_Order__c> wos;
        if (String.isNotBlank(statusFilter)) {
            wos = [
                SELECT Id, Name, Subject__c, Status__c, Priority__c, Scheduled_Date__c, Completed_Date__c,
                       Description__c, Site_Address__c, Equipment_ID__c, Equipment_Type__c,
                       Time_Logged_Minutes__c, Technician_Notes__c, Parts_Used__c, AI_Pre_Job_Briefing__c, Briefing_Generated__c,
                       Account__c, Account__r.Name,
                       Asset__c, Asset__r.Name, Asset__r.Serial_Number__c, Asset__r.Product_Name__c, Asset__r.Product_Category__c,
                       Case__c, Case__r.CaseNumber, Case__r.Subject, Case__r.Status, Case__r.Priority,
                       Case__r.Customer_Address__c, Case__r.Customer_Address__r.Name,
                       Case__r.Customer_Address__r.Address_Type__c, Case__r.Customer_Address__r.Street_Address__c,
                       Case__r.Customer_Address__r.City__c, Case__r.Customer_Address__r.State__c,
                       Case__r.Customer_Address__r.Postal_Code__c, Case__r.Customer_Address__r.Country__c,
                       Case__r.Customer_Address__r.Landmark__c,
                       Case__r.Customer_Address__r.Latitude__c, Case__r.Customer_Address__r.Longitude__c,
                       Case__r.Customer_Address__r.Contact_Person_Name__c,
                       Case__r.Customer_Address__r.Contact_Phone__c,
                       Assigned_Technician__c, Assigned_Technician__r.Name,
                       (
                           SELECT Id, Name, Status__c, Priority__c, Job_Type__c, SLA_Deadline__c, SLA_Status__c,
                                  Scheduled_Start_Time__c, Scheduled_End_Time__c,
                                  Check_In_Time__c, Completed_Time__c, Resolution_Time_Min__c,
                                  Notes__c, Customer_Notes__c, Customer_Signature_URL__c, Is_First_Time_Fix__c,
                                  Technician__c, Technician__r.Name, Zone__c, Zone__r.Name,
                                  (
                                      SELECT Id, Name, Technician__c, Technician__r.Name,
                                             Service_Crew__c, Service_Crew__r.Name,
                                             Resource_Type__c, Role__c, Is_Leader__c,
                                             Status__c, Check_In_Time__c, Actual_Hours__c
                                      FROM Assigned_Resources__r
                                  )
                           FROM Service_Jobs__r
                           WHERE Status__c = :statusFilter
                           ORDER BY SLA_Deadline__c ASC NULLS LAST, CreatedDate DESC
                       )
                FROM Work_Order__c
                WHERE Id = :cleanedIdAsId OR Name = :cleanedId
                LIMIT 1
            ];
        } else {
            wos = [
                SELECT Id, Name, Subject__c, Status__c, Priority__c, Scheduled_Date__c, Completed_Date__c,
                       Description__c, Site_Address__c, Equipment_ID__c, Equipment_Type__c,
                       Time_Logged_Minutes__c, Technician_Notes__c, Parts_Used__c, AI_Pre_Job_Briefing__c, Briefing_Generated__c,
                       Account__c, Account__r.Name,
                       Asset__c, Asset__r.Name, Asset__r.Serial_Number__c, Asset__r.Product_Name__c, Asset__r.Product_Category__c,
                       Case__c, Case__r.CaseNumber, Case__r.Subject, Case__r.Status, Case__r.Priority,
                       Case__r.Customer_Address__c, Case__r.Customer_Address__r.Name,
                       Case__r.Customer_Address__r.Address_Type__c, Case__r.Customer_Address__r.Street_Address__c,
                       Case__r.Customer_Address__r.City__c, Case__r.Customer_Address__r.State__c,
                       Case__r.Customer_Address__r.Postal_Code__c, Case__r.Customer_Address__r.Country__c,
                       Case__r.Customer_Address__r.Landmark__c,
                       Case__r.Customer_Address__r.Latitude__c, Case__r.Customer_Address__r.Longitude__c,
                       Case__r.Customer_Address__r.Contact_Person_Name__c,
                       Case__r.Customer_Address__r.Contact_Phone__c,
                       Assigned_Technician__c, Assigned_Technician__r.Name,
                       (
                           SELECT Id, Name, Status__c, Priority__c, Job_Type__c, SLA_Deadline__c, SLA_Status__c,
                                  Scheduled_Start_Time__c, Scheduled_End_Time__c,
                                  Check_In_Time__c, Completed_Time__c, Resolution_Time_Min__c,
                                  Notes__c, Customer_Notes__c, Customer_Signature_URL__c, Is_First_Time_Fix__c,
                                  Technician__c, Technician__r.Name, Zone__c, Zone__r.Name,
                                  (
                                      SELECT Id, Name, Technician__c, Technician__r.Name,
                                             Service_Crew__c, Service_Crew__r.Name,
                                             Resource_Type__c, Role__c, Is_Leader__c,
                                             Status__c, Check_In_Time__c, Actual_Hours__c
                                      FROM Assigned_Resources__r
                                  )
                           FROM Service_Jobs__r
                           ORDER BY SLA_Deadline__c ASC NULLS LAST, CreatedDate DESC
                       )
                FROM Work_Order__c
                WHERE Id = :cleanedIdAsId OR Name = :cleanedId
                LIMIT 1
            ];
        }

        if (wos.isEmpty()) {
            return new Map<String, Object>{
                'success' => false,
                'error' => 'Work Order not found for identifier: ' + workOrderIdentifier
            };
        }

        Technician__c tech = resolveTechnician(technicianIdParam);
        Id myTechId = tech != null ? tech.Id : null;
        Map<Id, Service_Crew_Member__c> myCrewMap = new Map<Id, Service_Crew_Member__c>();
        if (myTechId != null) {
            for (Service_Crew_Member__c m : [SELECT Id, Service_Crew__c, Service_Crew__r.Name, Is_Leader__c FROM Service_Crew_Member__c WHERE Technician__c = :myTechId]) {
                myCrewMap.put(m.Service_Crew__c, m);
            }
        }
        Map<String, Object> formatted = formatWorkOrderRecord(wos[0], myTechId, myCrewMap);
        List<Object> appts = (List<Object>) formatted.get('serviceAppointments');

        return new Map<String, Object>{
            'success' => true,
            'statusFilter' => statusFilter,
            'workOrder' => formatted.get('workOrder'),
            'count' => appts != null ? appts.size() : 0,
            'serviceAppointmentsCount' => appts != null ? appts.size() : 0,
            'serviceAppointments' => appts
        };
    }

    private static Map<String, Object> formatWorkOrderRecord(Work_Order__c wo) {
        return formatWorkOrderRecord(wo, null, null);
    }

    private static Map<String, Object> formatWorkOrderRecord(Work_Order__c wo, Id myTechId) {
        return formatWorkOrderRecord(wo, myTechId, null);
    }

    /**
     * Shared formatting utility
     */
    private static Map<String, Object> formatWorkOrderRecord(Work_Order__c wo, Id myTechId, Map<Id, Service_Crew_Member__c> myCrewMap) {
        Map<String, Object> serviceAddressMap = (wo.Case__c != null && wo.Case__r.Customer_Address__c != null) ? new Map<String, Object>{
            'id' => wo.Case__r.Customer_Address__c,
            'name' => wo.Case__r.Customer_Address__r.Name,
            'addressType' => wo.Case__r.Customer_Address__r.Address_Type__c,
            'streetAddress' => wo.Case__r.Customer_Address__r.Street_Address__c,
            'city' => wo.Case__r.Customer_Address__r.City__c,
            'state' => wo.Case__r.Customer_Address__r.State__c,
            'postalCode' => wo.Case__r.Customer_Address__r.Postal_Code__c,
            'country' => wo.Case__r.Customer_Address__r.Country__c,
            'landmark' => wo.Case__r.Customer_Address__r.Landmark__c,
            'latitude' => wo.Case__r.Customer_Address__r.Latitude__c,
            'longitude' => wo.Case__r.Customer_Address__r.Longitude__c,
            'contactPerson' => wo.Case__r.Customer_Address__r.Contact_Person_Name__c,
            'contactPhone' => wo.Case__r.Customer_Address__r.Contact_Phone__c
        } : null;

        Map<String, Object> caseMap = wo.Case__c != null ? new Map<String, Object>{
            'id' => wo.Case__c,
            'caseNumber' => wo.Case__r.CaseNumber,
            'subject' => wo.Case__r.Subject,
            'status' => wo.Case__r.Status,
            'priority' => wo.Case__r.Priority,
            'serviceAddress' => serviceAddressMap
        } : null;

        Map<String, Object> woMap = new Map<String, Object>{
            'id' => wo.Id,
            'name' => wo.Name,
            'subject' => wo.Subject__c,
            'status' => wo.Status__c,
            'priority' => wo.Priority__c,
            'scheduledDate' => wo.Scheduled_Date__c,
            'completedDate' => wo.Completed_Date__c,
            'siteAddress' => wo.Site_Address__c,
            'serviceAddress' => serviceAddressMap,
            'description' => wo.Description__c,
            'equipmentId' => wo.Equipment_ID__c,
            'equipmentType' => wo.Equipment_Type__c,
            'timeLoggedMinutes' => wo.Time_Logged_Minutes__c,
            'technicianNotes' => wo.Technician_Notes__c,
            'partsUsed' => wo.Parts_Used__c,
            'aiPreJobBriefing' => wo.AI_Pre_Job_Briefing__c,
            'briefingGenerated' => wo.Briefing_Generated__c,
            'account' => wo.Account__c != null ? new Map<String, Object>{
                'id' => wo.Account__c,
                'name' => wo.Account__r.Name
            } : null,
            'asset' => wo.Asset__c != null ? new Map<String, Object>{
                'id' => wo.Asset__c,
                'name' => wo.Asset__r.Name,
                'serialNumber' => wo.Asset__r.Serial_Number__c,
                'productName' => wo.Asset__r.Product_Name__c,
                'productCategory' => wo.Asset__r.Product_Category__c
            } : null,
            'case' => caseMap,
            'assignedTechnician' => wo.Assigned_Technician__c != null ? new Map<String, Object>{
                'id' => wo.Assigned_Technician__c,
                'name' => wo.Assigned_Technician__r.Name
            } : null
        };

        List<Map<String, Object>> appointmentsList = new List<Map<String, Object>>();
        if (wo.Service_Jobs__r != null) {
            for (Service_Job__c job : wo.Service_Jobs__r) {
                Boolean isDirect = (myTechId != null && job.Technician__c == myTechId);
                Boolean isCrew = false;
                Map<String, Object> myCrewInfo = null;

                // Format assigned resources roster & detect crew matching
                List<Map<String, Object>> teamList = new List<Map<String, Object>>();
                if (job.Assigned_Resources__r != null) {
                    for (Assigned_Resource__c ar : job.Assigned_Resources__r) {
                        if (myTechId != null && ar.Technician__c == myTechId) {
                            isDirect = true;
                        }
                        if (ar.Service_Crew__c != null && myCrewMap != null && myCrewMap.containsKey(ar.Service_Crew__c)) {
                            isCrew = true;
                            Service_Crew_Member__c scm = myCrewMap.get(ar.Service_Crew__c);
                            myCrewInfo = new Map<String, Object>{
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
                            'technician' => ar.Technician__c != null ? new Map<String, Object>{
                                'id' => ar.Technician__c,
                                'name' => ar.Technician__r.Name
                            } : null,
                            'crew' => ar.Service_Crew__c != null ? new Map<String, Object>{
                                'id' => ar.Service_Crew__c,
                                'name' => ar.Service_Crew__r.Name
                            } : null,
                            'role' => ar.Role__c,
                            'isLeader' => ar.Is_Leader__c,
                            'status' => ar.Status__c,
                            'checkInTime' => ar.Check_In_Time__c,
                            'actualHours' => ar.Actual_Hours__c
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

                appointmentsList.add(new Map<String, Object>{
                    'id' => job.Id,
                    'name' => job.Name,
                    'status' => job.Status__c,
                    'priority' => job.Priority__c,
                    'jobType' => job.Job_Type__c,
                    'isAssignedToMe' => (myTechId == null ? true : isAssignedToMe),
                    'isMyAppointment' => isAssignedToMe,
                    'assignmentType' => assignmentType,
                    'isCrewAssigned' => isCrew,
                    'myCrewAssignment' => myCrewInfo,
                    'slaDeadline' => job.SLA_Deadline__c,
                    'slaStatus' => job.SLA_Status__c,
                    'scheduledStartTime' => job.Scheduled_Start_Time__c,
                    'scheduledEndTime' => job.Scheduled_End_Time__c,
                    'checkInTime' => job.Check_In_Time__c,
                    'completedTime' => job.Completed_Time__c,
                    'startTime' => job.Check_In_Time__c,
                    'endTime' => job.Completed_Time__c,
                    'actualStartTime' => job.Check_In_Time__c,
                    'actualEndTime' => job.Completed_Time__c,
                    'resolutionTimeMinutes' => job.Resolution_Time_Min__c,
                    'isFirstTimeFix' => job.Is_First_Time_Fix__c,
                    'notes' => job.Notes__c,
                    'customerNotes' => job.Customer_Notes__c,
                    'customerSignatureUrl' => job.Customer_Signature_URL__c,
                    'serviceAddress' => serviceAddressMap,
                    'technician' => job.Technician__c != null ? new Map<String, Object>{
                        'id' => job.Technician__c,
                        'name' => job.Technician__r.Name
                    } : null,
                    'zone' => job.Zone__c != null ? new Map<String, Object>{
                        'id' => job.Zone__c,
                        'name' => job.Zone__r.Name
                    } : null,
                    'assignedTeamCount' => teamList.size(),
                    'assignedTeam' => teamList
                });
            }
        }

        return new Map<String, Object>{
            'id' => wo.Id,
            'name' => wo.Name,
            'subject' => wo.Subject__c,
            'status' => wo.Status__c,
            'priority' => wo.Priority__c,
            'siteAddress' => wo.Site_Address__c,
            'serviceAddress' => serviceAddressMap,
            'case' => woMap.get('case'),
            'workOrder' => woMap,
            'aiPreJobBriefing' => wo.AI_Pre_Job_Briefing__c,
            'briefingGenerated' => wo.Briefing_Generated__c,
            'serviceAppointmentsCount' => appointmentsList.size(),
            'serviceAppointments' => appointmentsList
        };
    }

    /**
     * Dedicated Job Briefing Query Method
     * GET /services/apexrest/df360/v1/work-orders/{workOrderId}/briefing
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getWorkOrderBriefing(String workOrderIdentifier) {
        if (String.isBlank(workOrderIdentifier)) {
            return new Map<String, Object>{ 'success' => false, 'error' => 'Work Order Identifier required' };
        }
        String cleanedId = workOrderIdentifier.trim();
        Id cleanedIdAsId = asIdOrNull(cleanedId); // Id = :<text> fails for numbers like WO-0001014
        List<Work_Order__c> wos = [
            SELECT Id, Name, Subject__c, Equipment_ID__c, Equipment_Type__c, Site_Address__c,
                   AI_Pre_Job_Briefing__c, Briefing_Generated__c
            FROM Work_Order__c
            WHERE Id = :cleanedIdAsId OR Name = :cleanedId
            LIMIT 1
        ];
        if (wos.isEmpty()) {
            return new Map<String, Object>{ 'success' => false, 'error' => 'Work Order not found for identifier: ' + workOrderIdentifier };
        }
        Work_Order__c wo = wos[0];
        return new Map<String, Object>{
            'success' => true,
            'workOrderId' => wo.Id,
            'workOrderName' => wo.Name,
            'subject' => wo.Subject__c,
            'equipmentId' => wo.Equipment_ID__c,
            'equipmentType' => wo.Equipment_Type__c,
            'siteAddress' => wo.Site_Address__c,
            'briefing' => wo.AI_Pre_Job_Briefing__c,
            'briefingGenerated' => wo.Briefing_Generated__c
        };
    }
}