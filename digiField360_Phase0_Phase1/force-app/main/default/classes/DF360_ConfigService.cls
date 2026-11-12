public without sharing class DF360_ConfigService {
    private static Map<String,String> cache = new Map<String,String>();
    public static String get(String key, String defVal) {
        if (!cache.containsKey(key)) {
            List<DF360_Config__mdt> rows = [SELECT Value__c FROM DF360_Config__mdt WHERE DeveloperName = :key LIMIT 1];
            cache.put(key, rows.isEmpty() ? defVal : rows[0].Value__c);
        }
        return cache.get(key);
    }
    public static Decimal getDec(String key, Decimal defVal) {
        String val = get(key, null);
        if (val == null) return defVal;
        try { return Decimal.valueOf(val); } catch(Exception e) { return defVal; }
    }
    public static Integer getInt(String key, Integer defVal) {
        return (Integer) getDec(key, defVal);
    }
}
