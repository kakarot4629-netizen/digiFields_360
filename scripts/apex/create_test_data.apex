// Execute script to create test user setup, Equipment HVAC-100, 3 Job Histories, and Work Order
User currentUser = [SELECT Id, FirstName, LastName, ProfileId, UserRoleId, Preferred_Language__c, Is_Active__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
currentUser.Preferred_Language__c = 'hi';
currentUser.Skills__c = 'HVAC, Compressor, Generator';
currentUser.Is_Active__c = true;
update currentUser;

Account acc;
List<Account> accs = [SELECT Id FROM Account WHERE Name = 'Tata Motors Test' LIMIT 1];
if (accs.isEmpty()) {
    acc = new Account(Name = 'Tata Motors Test');
    insert acc;
} else {
    acc = accs[0];
}

Equipment__c equip;
List<Equipment__c> equips = [SELECT Id FROM Equipment__c WHERE Name = 'Industrial HVAC Unit 100' LIMIT 1];
if (equips.isEmpty()) {
    equip = new Equipment__c(
        Name = 'Industrial HVAC Unit 100'
    );
    insert equip;
} else {
    equip = equips[0];
}

List<Job_History__c> histories = new List<Job_History__c>();
histories.add(new Job_History__c(
    Fault_Description__c = 'Low cooling efficiency, compressor overheating during peak afternoon load.',
    Resolution__c = 'Replaced compressor expansion valve and refilled R-410A refrigerant.',
    Parts_Used__c = 'Compressor Expansion Valve (EV-410), Refrigerant Gas 5kg',
    Duration_Minutes__c = 180,
    First_Time_Fix__c = true,
    Technician__c = currentUser.Id,
    Account__c = acc.Id
));

histories.add(new Job_History__c(
    Fault_Description__c = 'Blower fan vibration noise and air filter blockage error alert.',
    Resolution__c = 'Cleaned intake filters, tightened blower fan belt, lubricated motor bearings.',
    Parts_Used__c = 'Blower Belt V-32, Bearing Lube Grade-A',
    Duration_Minutes__c = 90,
    First_Time_Fix__c = true,
    Technician__c = currentUser.Id,
    Account__c = acc.Id
));

histories.add(new Job_History__c(
    Fault_Description__c = 'Thermostat sensor calibration fault causing automatic shutdown.',
    Resolution__c = 'Replaced digital thermostat sensor and re-calibrated central control panel.',
    Parts_Used__c = 'Digital Temp Sensor TS-10',
    Duration_Minutes__c = 60,
    First_Time_Fix__c = true,
    Technician__c = currentUser.Id,
    Account__c = acc.Id
));
insert histories;

Work_Order__c wo = new Work_Order__c(
    Subject__c = 'Urgent HVAC Cooling Failure - Plant Floor 2',
    Status__c = 'New',
    Priority__c = 'High',
    Account__c = acc.Id,
    Description__c = 'HVAC-100 stopped cooling at 10 AM. Blower fan running but no chill airflow. Requires immediate inspection.',
    Site_Address__c = 'Tata Motors Plant 2, Bhosari MIDC, Pune'
);
insert wo;

System.debug('TEST_DATA_CREATED_SUCCESSFULLY: Work Order ID = ' + wo.Id + ', Equipment = HVAC-100');
