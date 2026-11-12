trigger DF360_GPSLogTrigger on GPS_Log__c (after insert) {
    // Update Technician current GPS from latest log
    Map<Id,GPS_Log__c> latestPerTech = new Map<Id,GPS_Log__c>();
    for (GPS_Log__c log : Trigger.new) {
        if (!latestPerTech.containsKey(log.Technician__c) ||
            log.Log_Timestamp__c > latestPerTech.get(log.Technician__c).Log_Timestamp__c) {
            latestPerTech.put(log.Technician__c, log);
        }
    }
    List<Technician__c> updates = new List<Technician__c>();
    for (Id techId : latestPerTech.keySet()) {
        GPS_Log__c log = latestPerTech.get(techId);
        updates.add(new Technician__c(
            Id = techId,
            Current_GPS_Latitude__c = log.Latitude__c,
            Current_GPS_Longitude__c = log.Longitude__c
        ));
    }
    if (!updates.isEmpty()) update updates;
}
