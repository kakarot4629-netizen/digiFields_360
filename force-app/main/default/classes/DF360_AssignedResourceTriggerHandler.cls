public with sharing class DF360_AssignedResourceTriggerHandler {

    private static Boolean isExecuting = false;

    public static void handleAfterInsert(List<Assigned_Resource__c> newResources) {
        if (isExecuting) return;
        isExecuting = true;
        try {
            syncLeadTechnician(newResources);
            expandCrewAssignments(newResources);
        } finally {
            isExecuting = false;
        }
    }

    public static void handleAfterUpdate(List<Assigned_Resource__c> newResources, Map<Id, Assigned_Resource__c> oldMap) {
        if (isExecuting) return;
        isExecuting = true;
        try {
            syncLeadTechnician(newResources);
        } finally {
            isExecuting = false;
        }
    }

    /**
     * Backward Compatibility: Syncs the Lead Technician to parent Service_Job__c.Technician__c
     */
    private static void syncLeadTechnician(List<Assigned_Resource__c> resources) {
        Map<Id, Id> jobToLeadTechMap = new Map<Id, Id>();

        for (Assigned_Resource__c ar : resources) {
            if (ar.Service_Job__c != null && ar.Technician__c != null) {
                if (ar.Is_Leader__c == true || ar.Role__c == 'Lead Technician') {
                    jobToLeadTechMap.put(ar.Service_Job__c, ar.Technician__c);
                }
            }
        }

        if (!jobToLeadTechMap.isEmpty()) {
            List<Service_Job__c> jobsToUpdate = new List<Service_Job__c>();
            for (Id jobId : jobToLeadTechMap.keySet()) {
                jobsToUpdate.add(new Service_Job__c(
                    Id = jobId,
                    Technician__c = jobToLeadTechMap.get(jobId)
                ));
            }
            update jobsToUpdate;
        }
    }

    /**
     * Crew Explosion: When a Crew is assigned, auto-generate Assigned_Resource__c for each active crew member
     */
    private static void expandCrewAssignments(List<Assigned_Resource__c> resources) {
        Map<Id, Set<Id>> crewToJobsMap = new Map<Id, Set<Id>>();

        for (Assigned_Resource__c ar : resources) {
            // Check if this is a crew assignment without an individual technician specified
            if (ar.Service_Crew__c != null && ar.Technician__c == null && ar.Service_Job__c != null) {
                if (!crewToJobsMap.containsKey(ar.Service_Crew__c)) {
                    crewToJobsMap.put(ar.Service_Crew__c, new Set<Id>());
                }
                crewToJobsMap.get(ar.Service_Crew__c).add(ar.Service_Job__c);
            }
        }

        if (crewToJobsMap.isEmpty()) return;

        // Fetch active members of the assigned crews
        Date today = Date.today();
        List<Service_Crew_Member__c> members = [
            SELECT Id, Service_Crew__c, Technician__c, Is_Leader__c
            FROM Service_Crew_Member__c
            WHERE Service_Crew__c IN :crewToJobsMap.keySet()
              AND (Start_Date__c = null OR Start_Date__c <= :today)
              AND (End_Date__c = null OR End_Date__c >= :today)
        ];

        List<Assigned_Resource__c> memberResources = new List<Assigned_Resource__c>();
        Map<Id, Id> jobToLeaderMap = new Map<Id, Id>();

        for (Service_Crew_Member__c scm : members) {
            Set<Id> jobIds = crewToJobsMap.get(scm.Service_Crew__c);
            if (jobIds != null) {
                for (Id jId : jobIds) {
                    memberResources.add(new Assigned_Resource__c(
                        Service_Job__c = jId,
                        Technician__c = scm.Technician__c,
                        Service_Crew__c = scm.Service_Crew__c,
                        Resource_Type__c = 'Technician',
                        Role__c = scm.Is_Leader__c ? 'Lead Technician' : 'Crew Member',
                        Is_Leader__c = scm.Is_Leader__c,
                        Status__c = 'Assigned'
                    ));

                    if (scm.Is_Leader__c) {
                        jobToLeaderMap.put(jId, scm.Technician__c);
                    }
                }
            }
        }

        if (!memberResources.isEmpty()) {
            insert memberResources;
        }

        // Also update parent appointment lead technician
        if (!jobToLeaderMap.isEmpty()) {
            List<Service_Job__c> jobs = new List<Service_Job__c>();
            for (Id jId : jobToLeaderMap.keySet()) {
                jobs.add(new Service_Job__c(Id = jId, Technician__c = jobToLeaderMap.get(jId)));
            }
            update jobs;
        }
    }
}
