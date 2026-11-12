// Schedule all recurring digiField360 Batches and Monitors
System.debug('=== SCHEDULING DIGIFIELD360 CRON JOBS ===');

// 1. SLA Monitor Batch (Runs every 15 minutes)
try {
    System.schedule('DF360 SLA Monitor - 00m', '0 0 * * * ?', new DF360_SLAMonitorBatch());
    System.schedule('DF360 SLA Monitor - 15m', '0 15 * * * ?', new DF360_SLAMonitorBatch());
    System.schedule('DF360 SLA Monitor - 30m', '0 30 * * * ?', new DF360_SLAMonitorBatch());
    System.schedule('DF360 SLA Monitor - 45m', '0 45 * * * ?', new DF360_SLAMonitorBatch());
} catch(Exception e) {
    System.debug('SLA Monitor schedule note: ' + e.getMessage());
}

// 2. CSAT Rollup Batch (Runs nightly at 00:30 AM)
try {
    System.schedule('DF360 CSAT Nightly Rollup', '0 30 0 * * ?', new DF360_CSATRollupBatch());
} catch(Exception e) {
    System.debug('CSAT Rollup schedule note: ' + e.getMessage());
}

// 3. Contract Expiry Batch (Runs daily at 06:00 AM)
try {
    System.schedule('DF360 Contract Expiry Audit', '0 0 6 * * ?', new DF360_ContractExpiryBatch());
} catch(Exception e) {
    System.debug('Contract Expiry schedule note: ' + e.getMessage());
}

// 4. Certification Expiry Batch (Runs daily at 07:00 AM)
try {
    System.schedule('DF360 Certification Expiry Audit', '0 0 7 * * ?', new DF360_CertExpiryBatch());
} catch(Exception e) {
    System.debug('Cert Expiry schedule note: ' + e.getMessage());
}

// 5. GPS Log Retention Batch (Runs every Sunday at 02:00 AM)
try {
    System.schedule('DF360 GPS Log Retention Weekly', '0 0 2 ? * SUN', new DF360_GPSLogRetentionBatch());
} catch(Exception e) {
    System.debug('GPS Retention schedule note: ' + e.getMessage());
}

System.debug('=== DIGIFIELD360 CRON JOBS SCHEDULED SUCCESSFULLY! ===');
