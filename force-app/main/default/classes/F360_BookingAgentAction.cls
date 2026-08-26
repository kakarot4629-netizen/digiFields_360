/**
 * FIELD360 AI — Feature 7: Customer Self-Service Booking Agent
 *
 * Called by the Agentforce WhatsApp channel agent when a customer
 * wants to book or reschedule a field service visit.
 *
 * Agentforce Action: "Book Field Service Appointment"
 * Topic: Customer Booking
 */
public with sharing class F360_BookingAgentAction {
  public class AvailabilityRequest {
    @InvocableVariable(
      label='Job Description'
      required=true
      description='What the customer described — used to classify job type'
    )
    public String jobDescription;

    @InvocableVariable(label='Customer Phone' required=true)
    public String customerPhone;

    @InvocableVariable(label='Customer Account ID')
    public Id accountId;

    @InvocableVariable(
      label='Preferred Date'
      description='Optional customer preferred date (YYYY-MM-DD)'
    )
    public String preferredDate;

    @InvocableVariable(
      label='Equipment Type'
      description='Equipment type if already identified by the agent'
    )
    public String equipmentType;
  }

  public class AvailabilityResult {
    @InvocableVariable(
      label='Available Slots JSON'
      description='JSON array of available slots to offer to the customer'
    )
    public String availableSlotsJson;

    @InvocableVariable(label='Slot 1 Summary')
    public String slot1Summary;

    @InvocableVariable(label='Slot 2 Summary')
    public String slot2Summary;

    @InvocableVariable(label='Slot 3 Summary')
    public String slot3Summary;

    @InvocableVariable(label='Has Slots')
    public Boolean hasSlots;

    @InvocableVariable(label='Success')
    public Boolean success;

    @InvocableVariable(label='Error Message')
    public String errorMessage;
  }

  @InvocableMethod(
    label='Get Available Booking Slots'
    description='Checks technician availability for the next 3 business days and returns 2-3 slot options to offer the customer for booking a field service visit.'
    category='Field360 AI'
  )
  public static List<AvailabilityResult> getAvailableSlots(
    List<AvailabilityRequest> requests
  ) {
    List<AvailabilityResult> results = new List<AvailabilityResult>();

    for (AvailabilityRequest req : requests) {
      AvailabilityResult res = new AvailabilityResult();
      try {
        // Look at next 3 business days
        List<Date> workingDays = getNextWorkingDays(3);
        Date startDate = workingDays[0];
        Date endDate = workingDays[workingDays.size() - 1];

        // Count jobs per technician per day
        Map<Id, Map<Date, Integer>> techDayLoad = new Map<Id, Map<Date, Integer>>();
        for (AggregateResult ar : [
          SELECT Assigned_Technician__c techId, COUNT(Id) cnt
          FROM Work_Order__c
          WHERE
            Scheduled_Date__c >= :startDate
            AND Scheduled_Date__c <= :endDate
            AND Status__c NOT IN ('Completed', 'Cancelled')
            AND Assigned_Technician__c != NULL
          GROUP BY Assigned_Technician__c
        ]) {
          Id techId = (Id) ar.get('techId');
          Integer count = (Integer) ar.get('cnt');

          if (!techDayLoad.containsKey(techId)) {
            techDayLoad.put(techId, new Map<Date, Integer>());
          }
          for (Date workingDay : workingDays) {
            techDayLoad.get(techId).put(workingDay, count);
          }
        }

        // Get active technicians
        List<User> techs = [
          SELECT Id, Name, Skills__c, First_Time_Fix_Rate__c
          FROM User
          WHERE Is_Active__c = TRUE AND IsActive = TRUE
          LIMIT 20
        ];

        // Find available slots (tech with < 5 jobs that day)
        List<Map<String, Object>> slots = new List<Map<String, Object>>();
        Integer MAX_DAILY_JOBS = 5;

        for (Date d : workingDays) {
          String[] timeSlots = new List<String>{ '09:00', '13:00', '16:00' };
          for (String timeSlot : timeSlots) {
            if (slots.size() >= 3)
              break;
            for (User tech : techs) {
              Integer load = techDayLoad.containsKey(tech.Id) &&
                techDayLoad.get(tech.Id).containsKey(d)
                ? techDayLoad.get(tech.Id).get(d)
                : 0;
              if (load < MAX_DAILY_JOBS) {
                slots.add(
                  new Map<String, Object>{
                    'date' => String.valueOf(d),
                    'time' => timeSlot,
                    'technicianId' => tech.Id,
                    'technicianName' => tech.Name,
                    'displayLabel' => formatSlotLabel(d, timeSlot),
                    'currentLoad' => load
                  }
                );
                break;
              }
            }
          }
          if (slots.size() >= 3)
            break;
        }

        res.hasSlots = !slots.isEmpty();
        res.availableSlotsJson = JSON.serialize(slots);

        if (slots.size() >= 1)
          res.slot1Summary = (String) slots[0].get('displayLabel');
        if (slots.size() >= 2)
          res.slot2Summary = (String) slots[1].get('displayLabel');
        if (slots.size() >= 3)
          res.slot3Summary = (String) slots[2].get('displayLabel');

        res.success = true;
      } catch (Exception e) {
        res.success = false;
        res.errorMessage = e.getMessage();
        res.hasSlots = false;
      }
      results.add(res);
    }
    return results;
  }

  // ── Confirm booking — called after customer selects a slot ─────────────
  public class ConfirmRequest {
    @InvocableVariable(
      label='Slot JSON'
      required=true
      description='The slot object JSON the customer selected'
    )
    public String selectedSlotJson;

    @InvocableVariable(label='Customer Phone' required=true)
    public String customerPhone;

    @InvocableVariable(label='Job Description' required=true)
    public String jobDescription;

    @InvocableVariable(label='Account ID')
    public Id accountId;

    @InvocableVariable(label='Equipment Type')
    public String equipmentType;
  }

  public class ConfirmResult {
    @InvocableVariable(label='Work Order ID')
    public Id workOrderId;

    @InvocableVariable(label='Work Order Number')
    public String workOrderNumber;

    @InvocableVariable(
      label='Confirmation Message'
      description='Customer-facing confirmation text to send via WhatsApp'
    )
    public String confirmationMessage;

    @InvocableVariable(label='Success')
    public Boolean success;

    @InvocableVariable(label='Error Message')
    public String errorMessage;
  }

  public static List<ConfirmResult> confirmBooking(
    List<ConfirmRequest> requests
  ) {
    List<ConfirmResult> results = new List<ConfirmResult>();

    for (ConfirmRequest req : requests) {
      ConfirmResult res = new ConfirmResult();
      try {
        Map<String, Object> slot = (Map<String, Object>) JSON.deserializeUntyped(
          req.selectedSlotJson
        );

        Date slotDate = Date.valueOf((String) slot.get('date'));
        String slotTime = (String) slot.get('time');
        Id techId = (Id) slot.get('technicianId');
        String techName = (String) slot.get('technicianName');

        // Parse slot time into Date
        Work_Order__c wo = new Work_Order__c();
        wo.Subject__c = 'Customer Request: ' + req.jobDescription;
        wo.Description__c = req.jobDescription;
        wo.Status__c = 'Assigned';
        wo.Priority__c = 'Medium';
        wo.Account__c = req.accountId;
        wo.Assigned_Technician__c = techId;
        wo.Scheduled_Date__c = slotDate;
        wo.Equipment_Type__c = req.equipmentType;
        insert wo;

        // Refetch to get auto-number
        Work_Order__c inserted = [
          SELECT Name
          FROM Work_Order__c
          WHERE Id = :wo.Id
          LIMIT 1
        ];

        res.workOrderId = wo.Id;
        res.workOrderNumber = inserted.Name;
        res.confirmationMessage =
          'Booking confirmed! Reference: ' +
          inserted.Name +
          '\n' +
          'Date: ' +
          formatSlotLabel(slotDate, slotTime) +
          '\n' +
          'Technician: ' +
          techName +
          '\n' +
          'You will receive a reminder 30 minutes before the visit.';
        res.success = true;
      } catch (Exception e) {
        res.success = false;
        res.errorMessage = e.getMessage();
      }
      results.add(res);
    }
    return results;
  }

  // ── Utilities ──────────────────────────────────────────────────────────
  private static List<Date> getNextWorkingDays(Integer count) {
    List<Date> days = new List<Date>();
    Date d = Date.today().addDays(1);
    while (days.size() < count) {
      Integer dow = Math.mod(Date.newInstance(1900, 1, 7).daysBetween(d), 7);
      if (dow != 0 && dow != 6)
        days.add(d);
      d = d.addDays(1);
    }
    return days;
  }

  private static String formatSlotLabel(Date d, String timeText) {
    return d.format() + ' at ' + timeText + ' hrs';
  }
}
