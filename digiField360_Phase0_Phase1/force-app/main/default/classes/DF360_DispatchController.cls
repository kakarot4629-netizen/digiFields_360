public with sharing class DF360_DispatchController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> findAvailableTechnicians(Id jobId) {
        Service_Job__c job = [
            SELECT Zone__c, Priority__c, Product_Category__c,
                   Asset__r.GPS_Location__Latitude__s, Asset__r.GPS_Location__Longitude__s
            FROM Service_Job__c WHERE Id = :jobId LIMIT 1
        ];
        List<Technician__c> techs = [
            SELECT Id, Name__c, CSAT_Avg_30d__c, FTFR_Pct__c, Active_Job_Count__c,
                   Current_GPS_Latitude__c, Current_GPS_Longitude__c,
                   FCM_Token__c, User__c
            FROM Technician__c
            WHERE Zone__c = :job.Zone__c AND Availability_Status__c = 'Available' AND Is_Active__c = true
            LIMIT 50
        ];
        List<Map<String,Object>> scored = new List<Map<String,Object>>();
        for (Technician__c t : techs) {
            Decimal distScore = 100;
            if (job.Asset__r != null && t.Current_GPS_Latitude__c != null) {
                distScore = haversineKm(
                    job.Asset__r.GPS_Location__Latitude__s, job.Asset__r.GPS_Location__Longitude__s,
                    t.Current_GPS_Latitude__c, t.Current_GPS_Longitude__c
                );
            }
            Decimal csatScore = t.CSAT_Avg_30d__c == null ? 3 : t.CSAT_Avg_30d__c;
            Decimal workloadScore = t.Active_Job_Count__c == null ? 0 : t.Active_Job_Count__c;
            Decimal totalScore = (csatScore * 20) - (distScore * 2) - (workloadScore * 10);
            scored.add(new Map<String,Object>{
                'technicianId'=>t.Id,'technicianName'=>t.Name,
                'csat'=>csatScore,'ftfr'=>t.FTFR_Pct__c,
                'activeJobs'=>t.Active_Job_Count__c,'distanceKm'=>distScore.setScale(1),
                'score'=>totalScore.setScale(0)
            });
        }
        scored.sort(new ScoreComparator());
        return scored;
    }

    @AuraEnabled
    public static void assignTechnician(Id jobId, Id technicianId) {
        Decimal remHrs = 0;
        Service_Job__c job = [SELECT SLA_Deadline__c FROM Service_Job__c WHERE Id = :jobId LIMIT 1];
        if (job.SLA_Deadline__c != null)
            remHrs = (Decimal.valueOf(job.SLA_Deadline__c.getTime() - DateTime.now().getTime()) / 3600000).setScale(2);
        update new Service_Job__c(Id = jobId, Technician__c = technicianId, Status__c = 'Assigned');
        DF360_SLAController.createSLAEvent(jobId, 'Tech Assigned', remHrs, 'Technician assigned by dispatcher');
        // Fire push notification to technician
        DF360_GPSController.sendJobPushNotification(technicianId, jobId);
    }

    private static Decimal haversineKm(Decimal lat1, Decimal lng1, Decimal lat2, Decimal lng2) {
        if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return 999;
        final Decimal R = 6371;
        Decimal dLat = (lat2 - lat1) * 3.14159265 / 180;
        Decimal dLng = (lng2 - lng1) * 3.14159265 / 180;
        Decimal a = (Decimal)Math.sin((Double)(dLat/2)) * (Decimal)Math.sin((Double)(dLat/2))
            + (Decimal)Math.cos((Double)(lat1*3.14159265/180))
            * (Decimal)Math.cos((Double)(lat2*3.14159265/180))
            * (Decimal)Math.sin((Double)(dLng/2)) * (Decimal)Math.sin((Double)(dLng/2));
        return (R * 2 * (Decimal)Math.atan2(Math.sqrt((Double)a), Math.sqrt(1-(Double)a))).setScale(2);
    }

    private class ScoreComparator implements Comparable {
        public Integer compareTo(Object other) { return 0; }
    }
}
