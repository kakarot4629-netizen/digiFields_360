public with sharing class F360_CustomerNotificationAction {
  public static void notify(
    Id workOrderId,
    String notificationType,
    String content
  ) {
    try {
      Work_Order__c workOrder = [
        SELECT Account__r.Phone
        FROM Work_Order__c
        WHERE Id = :workOrderId
        WITH USER_MODE
        LIMIT 1
      ];
      if (
        workOrder.Account__r != null &&
        String.isNotBlank(workOrder.Account__r.Phone)
      ) {
        System.debug(
          '[F360 Notify] ' +
            notificationType +
            ' to ' +
            workOrder.Account__r.Phone
        );
      }
    } catch (Exception error) {
      System.debug('[F360 Notify Error] ' + error.getMessage());
    }
  }
}
