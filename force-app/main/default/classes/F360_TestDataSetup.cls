public without sharing class F360_TestDataSetup {
  @AuraEnabled
  public static String createSampleData() {
    try {
      // 1. Update current User preferred language to Hindi ('hi')
      User currentUser = [
        SELECT
          Id,
          FirstName,
          LastName,
          Preferred_Language__c,
          Skills__c,
          Is_Active__c
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];
      currentUser.Preferred_Language__c = 'hi';
      currentUser.Skills__c = 'HVAC, Compressor, Generator';
      currentUser.Is_Active__c = true;
      update currentUser;

      // 2. Create Account
      Account acc;
      List<Account> accs = [
        SELECT Id
        FROM Account
        WHERE Name = 'Tata Motors Test'
        LIMIT 1
      ];
      if (accs.isEmpty()) {
        acc = new Account(Name = 'Tata Motors Test');
        insert acc;
      } else {
        acc = accs[0];
      }

      // 3. Create Equipment record HVAC-100
      Equipment__c equip;
      List<Equipment__c> equips = [
        SELECT Id
        FROM Equipment__c
        WHERE Name = 'HVAC-100'
        LIMIT 1
      ];
      if (equips.isEmpty()) {
        equip = new Equipment__c(Name = 'HVAC-100');
        Database.insert(equip, false);
      } else {
        equip = equips[0];
      }

      // 4. Create 3 Job_History__c records for HVAC-100
      List<Job_History__c> histories = new List<Job_History__c>();
      histories.add(
        new Job_History__c(
          Equipment_ID__c = 'HVAC-100',
          Equipment_Type__c = 'HVAC',
          Fault_Description__c = 'Low cooling efficiency, compressor overheating during peak afternoon load.',
          Resolution__c = 'Replaced compressor expansion valve and refilled R-410A refrigerant.',
          Parts_Used__c = 'Compressor Expansion Valve (EV-410), Refrigerant Gas 5kg',
          Duration_Minutes__c = 180,
          First_Time_Fix__c = true,
          Technician__c = currentUser.Id,
          Account__c = acc.Id
        )
      );

      histories.add(
        new Job_History__c(
          Equipment_ID__c = 'HVAC-100',
          Equipment_Type__c = 'HVAC',
          Fault_Description__c = 'Blower fan vibration noise and air filter blockage error alert.',
          Resolution__c = 'Cleaned intake filters, tightened blower fan belt, lubricated motor bearings.',
          Parts_Used__c = 'Blower Belt V-32, Bearing Lube Grade-A',
          Duration_Minutes__c = 90,
          First_Time_Fix__c = true,
          Technician__c = currentUser.Id,
          Account__c = acc.Id
        )
      );

      histories.add(
        new Job_History__c(
          Equipment_ID__c = 'HVAC-100',
          Equipment_Type__c = 'HVAC',
          Fault_Description__c = 'Thermostat sensor calibration fault causing automatic shutdown.',
          Resolution__c = 'Replaced digital thermostat sensor and re-calibrated central control panel.',
          Parts_Used__c = 'Digital Temp Sensor TS-10',
          Duration_Minutes__c = 60,
          First_Time_Fix__c = true,
          Technician__c = currentUser.Id,
          Account__c = acc.Id
        )
      );
      Database.insert(histories, false);

      // 5. Create Work_Order__c referencing HVAC-100 with Status = New
      Work_Order__c wo = new Work_Order__c(
        Subject__c = 'Urgent HVAC Cooling Failure - Plant Floor 2',
        Equipment_ID__c = 'HVAC-100',
        Equipment_Type__c = 'HVAC',
        Status__c = 'New',
        Priority__c = 'High',
        Account__c = acc.Id,
        Description__c = 'HVAC-100 stopped cooling at 10 AM. Blower fan running but no chill airflow. Requires immediate inspection.',
        Site_Address__c = 'Tata Motors Plant 2, Bhosari MIDC, Pune'
      );
      Database.insert(wo, false);

      return 'SUCCESS: Setup executed for User (Preferred Language: hi), Equipment (HVAC-100), Job History, and Work Order (New).';
    } catch (Exception e) {
      return 'ERROR: ' + e.getMessage();
    }
  }
}
