public with sharing class DF360_WorkOrderPauseController {

    @AuraEnabled
    public static Map<String, Object> pauseWorkOrder(
        Id workOrderId,
        String reason,
        String description,
        String dependency,
        Datetime expectedResumeDate,
        String responsibleTeam
    ) {
        if (workOrderId == null) {
            throw new AuraHandledException('Work Order ID is required.');
        }
        if (String.isBlank(reason)) {
            throw new AuraHandledException('A valid pause reason must be selected.');
        }

        Work_Order__c wo = [
            SELECT Id, Name, Status__c, Current_Pause_Reason__c, Paused_DateTime__c,
                   Expected_Resume_Date__c, Total_Paused_Minutes__c,
                   Account__c, Account__r.Name, Account__r.Phone
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        if (wo.Status__c == 'Completed' || wo.Status__c == 'Cancelled') {
            throw new AuraHandledException('Cannot pause a Work Order that is already ' + wo.Status__c);
        }

        Datetime nowTime = Datetime.now();

        wo.Status__c = 'Temporarily Paused';
        wo.Current_Pause_Reason__c = reason;
        wo.Current_Pause_Description__c = description;
        wo.Current_Pause_Dependency__c = dependency;
        wo.Paused_DateTime__c = nowTime;
        wo.Expected_Resume_Date__c = expectedResumeDate;
        wo.Paused_Owner_Team__c = String.isNotBlank(responsibleTeam) ? responsibleTeam : 'Field Tech';

        update wo;

        // Proactive WhatsApp notification if waiting for customer or site access
        if ((reason == 'Waiting for Customer' || reason == 'Waiting for Site Access') &&
            wo.Account__c != null && String.isNotBlank(wo.Account__r.Phone)) {
            try {
                DF360_WhatsAppService.sendAsync(
                    wo.Account__r.Phone,
                    'df360_service_delay_notification',
                    JSON.serialize(new List<String>{ wo.Name, reason, description != null ? description : 'Awaiting access' })
                );
            } catch (Exception waEx) {
                System.debug('WhatsApp pause alert handled: ' + waEx.getMessage());
            }
        }

        // Create detailed audit log record
        Work_Order_Pause_Log__c log = new Work_Order_Pause_Log__c(
            Work_Order__c = wo.Id,
            Pause_Reason__c = reason,
            Description__c = description,
            Dependency__c = dependency,
            Paused_At__c = nowTime,
            Expected_Resume_Date__c = expectedResumeDate,
            Responsible_Team__c = wo.Paused_Owner_Team__c
        );
        insert log;

        return new Map<String, Object>{
            'success' => true,
            'workOrderId' => wo.Id,
            'status' => wo.Status__c,
            'pauseLogId' => log.Id,
            'pausedAt' => nowTime
        };
    }

    @AuraEnabled
    public static Map<String, Object> resumeWorkOrder(Id workOrderId, String resumeComments) {
        if (workOrderId == null) {
            throw new AuraHandledException('Work Order ID is required.');
        }

        Work_Order__c wo = [
            SELECT Id, Name, Status__c, Paused_DateTime__c, Total_Paused_Minutes__c
            FROM Work_Order__c
            WHERE Id = :workOrderId
            LIMIT 1
        ];

        if (wo.Status__c != 'Temporarily Paused') {
            throw new AuraHandledException('Work Order is not currently in Temporarily Paused status.');
        }

        Datetime resumeTime = Datetime.now();
        Long durationMinutes = 0;
        if (wo.Paused_DateTime__c != null) {
            durationMinutes = (resumeTime.getTime() - wo.Paused_DateTime__c.getTime()) / (1000 * 60);
        }

        wo.Status__c = 'In Progress';
        wo.Last_Resume_DateTime__c = resumeTime;
        wo.Last_Resume_Comments__c = resumeComments;
        wo.Total_Paused_Minutes__c = (wo.Total_Paused_Minutes__c == null ? 0 : wo.Total_Paused_Minutes__c) + durationMinutes;

        update wo;

        // Close the open pause log
        List<Work_Order_Pause_Log__c> openLogs = [
            SELECT Id, Paused_At__c, Resumed_At__c, Duration_Minutes__c
            FROM Work_Order_Pause_Log__c
            WHERE Work_Order__c = :workOrderId AND Resumed_At__c = null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!openLogs.isEmpty()) {
            openLogs[0].Resumed_At__c = resumeTime;
            openLogs[0].Resume_Comments__c = resumeComments;
            openLogs[0].Duration_Minutes__c = durationMinutes;
            update openLogs[0];
        }

        return new Map<String, Object>{
            'success' => true,
            'workOrderId' => wo.Id,
            'status' => wo.Status__c,
            'resumedAt' => resumeTime,
            'durationMinutes' => durationMinutes,
            'totalPausedMinutes' => wo.Total_Paused_Minutes__c
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPausedWorkOrdersDashboard() {
        List<Work_Order__c> pausedOrders = [
            SELECT Id, Name, Subject__c, Priority__c, Current_Pause_Reason__c,
                   Current_Pause_Description__c, Current_Pause_Dependency__c,
                   Paused_DateTime__c, Expected_Resume_Date__c, Paused_Owner_Team__c,
                   Total_Paused_Minutes__c, Assigned_Technician__r.Name,
                   Asset__r.Name, Asset__r.Product_Name__c, Account__r.Name
            FROM Work_Order__c
            WHERE Status__c = 'Temporarily Paused'
            ORDER BY Paused_DateTime__c ASC
            LIMIT 200
        ];

        Integer totalPaused = pausedOrders.size();
        Integer overdueCount = 0;
        Map<String, Integer> reasonCount = new Map<String, Integer>();
        Map<String, Integer> teamCount = new Map<String, Integer>();

        List<Map<String, Object>> records = new List<Map<String, Object>>();
        Datetime nowTime = Datetime.now();

        for (Work_Order__c wo : pausedOrders) {
            Boolean isOverdue = (wo.Expected_Resume_Date__c != null && wo.Expected_Resume_Date__c < nowTime);
            if (isOverdue) overdueCount++;

            Decimal agingHours = 0;
            if (wo.Paused_DateTime__c != null) {
                agingHours = ((Decimal)(nowTime.getTime() - wo.Paused_DateTime__c.getTime()) / 3600000.0).setScale(1, RoundingMode.HALF_UP);
            }

            String r = String.isNotBlank(wo.Current_Pause_Reason__c) ? wo.Current_Pause_Reason__c : 'Other';
            reasonCount.put(r, reasonCount.containsKey(r) ? reasonCount.get(r) + 1 : 1);

            String t = String.isNotBlank(wo.Paused_Owner_Team__c) ? wo.Paused_Owner_Team__c : 'Field Tech';
            teamCount.put(t, teamCount.containsKey(t) ? teamCount.get(t) + 1 : 1);

            records.add(new Map<String, Object>{
                'id' => wo.Id,
                'name' => wo.Name,
                'subject' => wo.Subject__c,
                'priority' => wo.Priority__c,
                'reason' => wo.Current_Pause_Reason__c,
                'description' => wo.Current_Pause_Description__c,
                'dependency' => wo.Current_Pause_Dependency__c,
                'pausedAt' => wo.Paused_DateTime__c,
                'expectedResume' => wo.Expected_Resume_Date__c,
                'team' => wo.Paused_Owner_Team__c,
                'agingHours' => agingHours,
                'isOverdue' => isOverdue,
                'techName' => wo.Assigned_Technician__r?.Name,
                'assetName' => wo.Asset__r?.Product_Name__c != null ? wo.Asset__r.Product_Name__c : wo.Asset__r?.Name,
                'accountName' => wo.Account__r?.Name
            });
        }

        return new Map<String, Object>{
            'totalPaused' => totalPaused,
            'overdueCount' => overdueCount,
            'reasonCount' => reasonCount,
            'teamCount' => teamCount,
            'records' => records
        };
    }
}
