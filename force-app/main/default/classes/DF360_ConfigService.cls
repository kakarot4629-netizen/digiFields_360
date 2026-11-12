public without sharing class DF360_ConfigService {
    private static Map<String,String> cache = new Map<String,String>{
        'MAX_GPS_ACCURACY_METERS' => '100',
        'AUTO_DISPATCH_TIMEOUT_SECONDS' => '60',
        'DEFAULT_SLA_ACK_MINUTES' => '30',
        'HIGH_VALUE_PART_THRESHOLD' => '5000'
    };

    public static void setOverride(String key, String value) {
        cache.put(key, value);
    }

    public static String get(String key, String defVal) {
        if (cache.containsKey(key)) {
            return cache.get(key);
        }
        return defVal;
    }

    public static Decimal getDec(String key, Decimal defVal) {
        String val = get(key, null);
        if (val == null) return defVal;
        try { 
            return Decimal.valueOf(val); 
        } catch(Exception e) { 
            return defVal; 
        }
    }

    public static Integer getInt(String key, Integer defVal) {
        Decimal d = getDec(key, defVal);
        return d != null ? d.intValue() : defVal;
    }
}
