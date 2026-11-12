/**
 * FIELD360 AI — Invocable Action: Work Order Pause & SLA Management
 *
 * Called by Agentforce agent when dispatchers, supervisors, or technicians
 * request to pause, resume, or query temporarily paused work orders.
 */
public with sharing class DF360_WorkOrderPauseInvocableAction {

    public class PauseRequest {
        @InvocableVariable(label='Action Type' required=true description='Action: PAUSE, RESUME, or GET_PAUSED_SUMMARY')
        public String actionType;

        @InvocableVariable(label='Work Order ID' description='ID of the target Work Order')
        public Id workOrderId;

        @InvocableVariable(label='Pause Reason' description='Reason: Waiting for Part, Waiting for Approval, Waiting for Customer, Waiting for Site Access, Safety Issue, Vendor Dependency, Waiting for Information, Other')
        public String reason;

        @InvocableVariable(label='Pause Description' description='Detailed description of the pause blocker')
        public String description;

        @InvocableVariable(label='Dependency' description='External dependency tracking ID (e.g. PR-00492, Permit #)')
        public String dependency;

        @InvocableVariable(label='Responsible Team' description='Accountable team: Field Tech, Procurement, Customer Care, Safety, Vendor')
        public String responsibleTeam;

        @InvocableVariable(label='Resume Comments' description='Comments provided when resuming the Work Order')
        public String resumeComments;
    }

    public class PauseResult {
        @InvocableVariable(label='Status Message')
        public String statusMessage;

        @InvocableVariable(label='Is Paused')
        public Boolean isPaused;

        @InvocableVariable(label='Total Paused Count')
        public Integer totalPausedCount;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Manage Work Order Pause & Resume'
        description='Pauses or resumes a Work Order with reason tracking, or returns a summary of all paused orders for Agentforce.'
        category='Field360 AI'
    )
    public static List<PauseResult> managePause(List<PauseRequest> requests) {
        List<PauseResult> results = new List<PauseResult>();

        for (PauseRequest req : requests) {
            PauseResult res = new PauseResult();
            try {
                String act = String.isNotBlank(req.actionType) ? req.actionType.toUpperCase().trim() : 'GET_PAUSED_SUMMARY';

                if (act == 'PAUSE') {
                    if (req.workOrderId == null) {
                        res.success = false;
                        res.errorMessage = 'Work Order ID is required to pause.';
                        results.add(res);
                        continue;
                    }
                    String r = String.isNotBlank(req.reason) ? req.reason : 'Waiting for Part';
                    Map<String, Object> pauseRes = DF360_WorkOrderPauseController.pauseWorkOrder(
                        req.workOrderId,
                        r,
                        req.description,
                        req.dependency,
                        Datetime.now().addDays(1),
                        req.responsibleTeam
                    );
                    res.isPaused = true;
                    res.statusMessage = 'Work Order paused successfully. Reason: ' + r + ' (Responsible: ' + (req.responsibleTeam != null ? req.responsibleTeam : 'Field Tech') + ')';
                    res.success = true;

                } else if (act == 'RESUME') {
                    if (req.workOrderId == null) {
                        res.success = false;
                        res.errorMessage = 'Work Order ID is required to resume.';
                        results.add(res);
                        continue;
                    }
                    String comments = String.isNotBlank(req.resumeComments) ? req.resumeComments : 'Resumed via Agentforce assistant';
                    Map<String, Object> resumeRes = DF360_WorkOrderPauseController.resumeWorkOrder(req.workOrderId, comments);
                    res.isPaused = false;
                    res.statusMessage = 'Work Order resumed to In Progress. Paused duration logged: ' + resumeRes.get('durationMinutes') + ' minutes.';
                    res.success = true;

                } else {
                    // GET_PAUSED_SUMMARY
                    Map<String, Object> dash = DF360_WorkOrderPauseController.getPausedWorkOrdersDashboard();
                    Integer total = (Integer) dash.get('totalPaused');
                    Integer overdue = (Integer) dash.get('overdueCount');
                    List<Map<String, Object>> recs = (List<Map<String, Object>>) dash.get('records');

                    String summary = 'Currently, there are ' + total + ' temporarily paused Work Orders (' + overdue + ' SLA overdue).\n';
                    if (recs != null && !recs.isEmpty()) {
                        for (Map<String, Object> r : recs) {
                            summary += '- ' + r.get('name') + ' (' + r.get('subject') + '): Paused for "' + r.get('reason') + '" by team "' + r.get('team') + '" (Aging: ' + r.get('agingHours') + ' hrs)\n';
                        }
                    }
                    res.totalPausedCount = total;
                    res.statusMessage = summary;
                    res.success = true;
                }

            } catch (Exception ex) {
                res.success = false;
                res.errorMessage = ex.getMessage();
            }
            results.add(res);
        }
        return results;
    }
}
