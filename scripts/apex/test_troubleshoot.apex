F360_TroubleshootingAction.TroubleshootRequest req = new F360_TroubleshootingAction.TroubleshootRequest();
req.problemDescription = 'Compressor making humming noise, low pressure gauge, no cooling airflow';
req.equipmentType = 'HVAC';
req.languageCode = 'hi';

List<F360_TroubleshootingAction.TroubleshootResult> results = 
    F360_TroubleshootingAction.getTroubleshootingGuidance(new List<F360_TroubleshootingAction.TroubleshootRequest>{req});

System.debug('TROUBLESHOOT_SUCCESS: ' + results[0].success);
System.debug('TROUBLESHOOT_LIKELY_CAUSE: ' + results[0].likelyCause);
System.debug('TROUBLESHOOT_DIAGNOSIS:\n' + results[0].diagnosisText);
