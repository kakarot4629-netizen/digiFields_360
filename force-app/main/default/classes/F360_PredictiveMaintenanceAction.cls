/**
 * FIELD360 AI — Feature 6: Predictive Maintenance Alert Agent
 *
 * Runs nightly as a Scheduled Agentforce background agent.
 * Analyses job history per equipment to predict which machines
 * are likely to fail in the next 30–60 days. Creates a
 * Maintenance_Alert__c record which the service manager
 * reviews and converts to a proactive work order.
 *
 * Requires 2–3 months of job history to be meaningful.
 * Score is based on: failure frequency, time since last service,
 * and increasing fault severity trend.
 *
 * Agentforce Action: "Run Predictive Maintenance Analysis"
 * Topic: Preventive Maintenance (runs as background agent)
 */
public with sharing class F360_PredictiveMaintenanceAction {
  public class MaintenanceRequest {
    @InvocableVariable(
      label='Account ID'
      description='Optional: limit analysis to one customer. Leave blank to analyse all.'
    )
    public Id accountId;

    @InvocableVariable(
      label='Look Back Days'
      description='Days of history to analyse (default 90)'
    )
    public Integer lookBackDays;

    @InvocableVariable(
      label='Risk Threshold'
      description='Minimum risk score to create alert (0-100, default 65)'
    )
    public Integer riskThreshold;
  }

  public class MaintenanceResult {
    @InvocableVariable(label='Alerts Created')
    public Integer alertsCreated;

    @InvocableVariable(label='Equipment Analysed')
    public Integer equipmentAnalysed;

    @InvocableVariable(label='High Risk Equipment Summary')
    public String highRiskSummary;

    @InvocableVariable(label='Success')
    public Boolean success;

    @InvocableVariable(label='Error Message')
    public String errorMessage;
  }

  @InvocableMethod(
    label='Run Predictive Maintenance Analysis'
    description='Analyses equipment job history to predict failures in the next 30-60 days. Creates maintenance alerts for high-risk equipment so the team can proactively schedule visits before a breakdown occurs.'
    category='Field360 AI'
  )
  public static List<MaintenanceResult> analyseEquipment(
    List<MaintenanceRequest> requests
  ) {
    List<MaintenanceResult> results = new List<MaintenanceResult>();

    for (MaintenanceRequest req : requests) {
      MaintenanceResult res = new MaintenanceResult();
      try {
        Integer days = req.lookBackDays != null ? req.lookBackDays : 90;
        Integer threshold = req.riskThreshold != null ? req.riskThreshold : 65;
        Date lookBackDate = Date.today().addDays(-days);

        List<AggregateResult> equipmentStats = [
          SELECT
            Equipment_ID__c equipId,
            Equipment_Type__c equipType,
            COUNT(Id) jobCount,
            MIN(Job_Date__c) firstJob,
            MAX(Job_Date__c) lastJob,
            SUM(Duration_Minutes__c) totalMins,
            COUNT_DISTINCT(Work_Order__c) distinctWOs
          FROM Job_History__c
          WHERE Job_Date__c >= :lookBackDate AND Equipment_ID__c != NULL
          GROUP BY Equipment_ID__c, Equipment_Type__c
          ORDER BY COUNT(Id) DESC
          LIMIT 200
        ];

        res.equipmentAnalysed = equipmentStats.size();

        List<String> highRiskItems = new List<String>();
        Integer alertsCreated = 0;

        for (AggregateResult ar : equipmentStats) {
          String equipId = (String) ar.get('equipId');
          String equipType = (String) ar.get('equipType');
          Integer jobCount = (Integer) ar.get('jobCount');
          Date lastJob = (Date) ar.get('lastJob');

          // Risk scoring algorithm
          Decimal riskScore = 0;

          // Factor 1: Job frequency (max 40 pts) — more jobs = higher risk
          riskScore += Math.min(jobCount * 8, 40);

          // Factor 2: Days since last service (max 30 pts)
          Integer daysSinceLast = lastJob != null
            ? lastJob.daysBetween(Date.today())
            : 90;
          if (daysSinceLast > 60)
            riskScore += 30;
          else if (daysSinceLast > 30)
            riskScore += 15;

          // Factor 3: Repeat failures (same equipment, multiple WOs = escalating issue)
          Integer distinctWOs = (Integer) ar.get('distinctWOs');
          if (distinctWOs >= 3)
            riskScore += 20;
          else if (distinctWOs == 2)
            riskScore += 10;

          // Factor 4: Job duration trend (long jobs = complex faults)
          Decimal totalMins = (Decimal) ar.get('totalMins');
          if (totalMins != null && jobCount > 0) {
            Decimal avgMins = totalMins / jobCount;
            if (avgMins > 180)
              riskScore += 10;
          }

          if (riskScore >= threshold) {
            String explanation = generateRiskExplanation(
              equipId,
              equipType,
              jobCount,
              daysSinceLast,
              riskScore.intValue()
            );

            Id equipmentAccountId = null;
            try {
              Equipment__c equip = [
                SELECT Id, Account__c, Equipment_Type__c, Status__c
                FROM Equipment__c
                WHERE Equipment_ID__c = :equipId
                LIMIT 1
              ];
              equipmentAccountId = equip.Account__c;
            } catch (Exception e) {
              // Equipment record optional
            }

            // Create Maintenance_Recommendation__c record
            Maintenance_Recommendation__c rec = new Maintenance_Recommendation__c();
            rec.Maintenance_Type__c = 'Predictive';
            rec.Recommended_Action__c =
              'Schedule preventive maintenance for ' + equipType;
            rec.Priority__c = riskScore >= 80
              ? 'Critical'
              : riskScore >= 65 ? 'High' : 'Medium';
            rec.Status__c = 'New';
            rec.Trigger_Source__c = 'AI Predictive Maintenance';
            rec.Risk_Score__c = riskScore;
            rec.Recommended_Date__c = Date.today();
            rec.AI_Explanation__c = explanation;
            if (equipmentAccountId != null) {
              rec.Account__c = equipmentAccountId;
            }
            insert rec;

            highRiskItems.add(
              equipType +
                ' [' +
                equipId +
                '] — Risk: ' +
                riskScore.setScale(0) +
                '/100 (' +
                jobCount +
                ' jobs in ' +
                days +
                ' days, last ' +
                daysSinceLast +
                ' days ago)'
            );
            alertsCreated++;
          }
        }

        res.alertsCreated = alertsCreated;
        res.highRiskSummary = alertsCreated > 0
          ? String.join(highRiskItems, '\n')
          : 'No high-risk equipment identified in this period.';
        res.success = true;
      } catch (Exception e) {
        res.success = false;
        res.errorMessage = e.getMessage();
      }
      results.add(res);
    }
    return results;
  }

  private static String generateRiskExplanation(
    String equipId,
    String equipType,
    Integer jobCount,
    Integer daysSinceLast,
    Integer score
  ) {
    try {
      ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
      input.isPreview = false;

      Map<String, ConnectApi.WrappedValue> params = new Map<String, ConnectApi.WrappedValue>();
      ConnectApi.WrappedValue p = new ConnectApi.WrappedValue();
      p.value = new Map<String, Object>{
        'equipmentType' => equipType,
        'equipmentId' => equipId,
        'jobCount' => jobCount,
        'daysSinceLast' => daysSinceLast,
        'riskScore' => score
      };
      params.put('Input:EquipmentData', p);
      input.inputParams = params;
      input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
      input.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

      ConnectApi.EinsteinPromptTemplateGenerationsRepresentation res = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
        'F360_MaintenanceAlert',
        input
      );
      return res.generations[0].text;
    } catch (Exception e) {
      return 'Risk score ' +
        score +
        '/100 — ' +
        jobCount +
        ' jobs in analysis period.';
    }
  }
}
