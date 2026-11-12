@RestResource(urlMapping='/df360/v1/auth/*')
global with sharing class DF360_AuthAPI {

    /**
     * GET /services/apexrest/df360/v1/auth/me
     * or GET /services/apexrest/df360/v1/auth/profile
     * 
     * Returns the authenticated User and linked Technician__c record
     */
    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        if (res != null) {
            res.addHeader('Content-Type', 'application/json');
        }

        try {
            Id currentUserId = UserInfo.getUserId();
            String currentUserName = UserInfo.getName();
            String currentUserEmail = UserInfo.getUserEmail();

            // Look up technician linked to this user
            List<Technician__c> techs = [
                SELECT Id, Name, Employee_Code__c, Is_Active__c, Availability_Status__c,
                       Zone__c, Zone__r.Name, User__c
                FROM Technician__c
                WHERE User__c = :currentUserId
                LIMIT 1
            ];

            // Fallback if current user has no direct link (e.g. platform admin)
            if (techs.isEmpty()) {
                techs = [
                    SELECT Id, Name, Employee_Code__c, Is_Active__c, Availability_Status__c,
                           Zone__c, Zone__r.Name, User__c
                    FROM Technician__c
                    WHERE Is_Active__c = true
                    ORDER BY CreatedDate ASC
                    LIMIT 1
                ];
            }

            Map<String, Object> techMap = null;
            if (!techs.isEmpty()) {
                Technician__c t = techs[0];
                techMap = new Map<String, Object>{
                    'id' => t.Id,
                    'name' => t.Name,
                    'employeeCode' => t.Employee_Code__c,
                    'isActive' => t.Is_Active__c,
                    'availabilityStatus' => t.Availability_Status__c,
                    'zone' => t.Zone__c != null ? new Map<String, Object>{
                        'id' => t.Zone__c,
                        'name' => t.Zone__r.Name
                    } : null
                };
            }

            if (res != null) res.statusCode = 200;
            if (res != null) {
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'success' => true,
                    'user' => new Map<String, Object>{
                        'id' => currentUserId,
                        'name' => currentUserName,
                        'email' => currentUserEmail
                    },
                    'technician' => techMap
                }));
            }

        } catch (Exception e) {
            if (res != null) res.statusCode = 500;
            if (res != null) {
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error' => e.getMessage()
                }));
            }
        }
    }
}
