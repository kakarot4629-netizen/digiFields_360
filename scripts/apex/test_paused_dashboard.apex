Map<String, Object> dash = DF360_WorkOrderPauseController.getPausedWorkOrdersDashboard();
System.debug('=== LIVE PAUSED DASHBOARD METRICS ===');
System.debug('Total Paused: ' + dash.get('totalPaused'));
System.debug('Overdue Count: ' + dash.get('overdueCount'));
System.debug('Records: ' + JSON.serializePretty(dash.get('records')));
