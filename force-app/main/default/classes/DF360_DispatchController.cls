public with sharing class DF360_DispatchController {

    public class TechScored implements Comparable {
        public Id technicianId;
        public String technicianName;
        public Decimal csat;
        public Decimal ftfr;
        public Decimal activeJobs;
        public Decimal distanceKm;
        public Decimal score;

        public TechScored(Id techId, String techName, Decimal c, Decimal f, Decimal a, Decimal d, Decimal s) {
            this.technicianId = techId;
            this.technicianName = techName;
            this.csat = c;
            this.ftfr = f;
            this.activeJobs = a;
            this.distanceKm = d;
            this.score = s;
        }

        public Integer compareTo(Object compareTo) {
            TechScored other = (TechScored) compareTo;
            if (this.score == other.score) return 0;
            return this.score < other.score ? 1 : -1; // Descending score
        }

        public Map<String,Object> toMap() {
            return new Map<String,Object>{
                'technicianId' => technicianId,
                'technicianName' => technicianName,
                'csat' => csat,
                'ftfr' => ftfr,
                'activeJobs' => activeJobs,
                'distanceKm' => distanceKm != null ? distanceKm.setScale(1) : 0,
                'score' => score != null ? score.setScale(0) : 0
            };
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String,Object>> findAvailableTechnicians(Id jobId) {
        Service_Job__c job = [
            SELECT Zone__c, Priority__c, Product_Category__c,
                   Asset__r.GPS_Location__Latitude__s, Asset__r.GPS_Location__Longitude__s
            FROM Service_Job__c WHERE Id = :jobId LIMIT 1
        ];

        List<Technician__c> techs;
        if (job.Zone__c != null) {
            techs = [
                SELECT Id, Name, CSAT_Avg_30d__c, FTFR_Pct__c, Active_Job_Count__c,
                       Current_GPS_Latitude__c, Current_GPS_Longitude__c,
                       FCM_Token__c, User__c
                FROM Technician__c
                WHERE Zone__c = :job.Zone__c AND Availability_Status__c = 'Available' AND Is_Active__c = true
                LIMIT 50
            ];
        } else {
            techs = [
                SELECT Id, Name, CSAT_Avg_30d__c, FTFR_Pct__c, Active_Job_Count__c,
                       Current_GPS_Latitude__c, Current_GPS_Longitude__c,
                       FCM_Token__c, User__c
                FROM Technician__c
                WHERE Availability_Status__c = 'Available' AND Is_Active__c = true
                LIMIT 50
            ];
        }

        List<TechScored> scoredList = new List<TechScored>();
        for (Technician__c t : techs) {
            Decimal distKm = 10;
            if (job.Asset__r != null && job.Asset__r.GPS_Location__Latitude__s != null && t.Current_GPS_Latitude__c != null) {
                distKm = haversineKm(
                    job.Asset__r.GPS_Location__Latitude__s, job.Asset__r.GPS_Location__Longitude__s,
                    t.Current_GPS_Latitude__c, t.Current_GPS_Longitude__c
                );
            }
            Decimal csatScore = t.CSAT_Avg_30d__c == null ? 4.0 : t.CSAT_Avg_30d__c;
            Decimal workloadScore = t.Active_Job_Count__c == null ? 0 : t.Active_Job_Count__c;
            Decimal totalScore = (csatScore * 20) - (distKm * 2) - (workloadScore * 10);
            
            scoredList.add(new TechScored(
                t.Id, t.Name, csatScore, t.FTFR_Pct__c, workloadScore, distKm, totalScore
            ));
        }

        scoredList.sort();

        List<Map<String,Object>> result = new List<Map<String,Object>>();
        for (TechScored ts : scoredList) {
            result.add(ts.toMap());
        }
        return result;
    }

    @AuraEnabled
    public static void assignTechnician(Id jobId, Id technicianId) {
        Decimal remHrs = 0;
        Service_Job__c job = [SELECT SLA_Deadline__c FROM Service_Job__c WHERE Id = :jobId LIMIT 1];
        if (job.SLA_Deadline__c != null) {
            remHrs = (Decimal.valueOf(job.SLA_Deadline__c.getTime() - DateTime.now().getTime()) / 3600000).setScale(2);
        }
        update new Service_Job__c(Id = jobId, Technician__c = technicianId, Status__c = 'Assigned');
        DF360_SLAController.createSLAEvent(jobId, 'Tech Assigned', remHrs, 'Technician assigned by dispatcher');
        DF360_GPSController.sendJobPushNotification(technicianId, jobId);
    }

    private static Decimal haversineKm(Decimal lat1, Decimal lng1, Decimal lat2, Decimal lng2) {
        if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return 10;
        final Double R = 6371;
        Double dLat = (lat2 - lat1).doubleValue() * 3.14159265 / 180;
        Double dLng = (lng2 - lng1).doubleValue() * 3.14159265 / 180;
        Double a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                   Math.cos(lat1.doubleValue() * 3.14159265 / 180) *
                   Math.cos(lat2.doubleValue() * 3.14159265 / 180) *
                   Math.sin(dLng/2) * Math.sin(dLng/2);
        Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return Decimal.valueOf(R * c);
    }
}
