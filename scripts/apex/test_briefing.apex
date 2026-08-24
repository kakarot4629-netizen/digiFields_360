Work_Order__c wo = [SELECT Id FROM Work_Order__c ORDER BY CreatedDate DESC LIMIT 1];
F360_PreJobBriefingAction.BriefingRequest req = new F360_PreJobBriefingAction.BriefingRequest();
req.workOrderId = wo.Id;
req.languageCode = 'hi';
List<F360_PreJobBriefingAction.BriefingResult> res = F360_PreJobBriefingAction.generateBriefing(new List<F360_PreJobBriefingAction.BriefingRequest>{req});
System.debug('BRIEFING_RESULT_SUCCESS: ' + res[0].success);
System.debug('BRIEFING_RESULT_ERROR: ' + res[0].errorMessage);
System.debug('BRIEFING_RESULT_TEXT: ' + res[0].briefingText);
