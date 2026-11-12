public class DF360_ContractExpiryBatch implements Database.Batchable<SObject>, Schedulable {
    public void execute(SchedulableContext sc) { Database.executeBatch(new DF360_ContractExpiryBatch(), 200); }
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date alertDate = Date.today().addDays(30);
        return Database.getQueryLocator([SELECT Id, Account__c, Account__r.Name, End_Date__c, Contract_Type__c
            FROM Service_Contract__c WHERE Status__c = 'Active' AND End_Date__c <= :alertDate AND End_Date__c >= :Date.today()]);
    }
    public void execute(Database.BatchableContext bc, List<Service_Contract__c> contracts) {
        for (Service_Contract__c c : contracts) {
            ConnectApi.FeedItemInput fi = new ConnectApi.FeedItemInput();
            fi.body = new ConnectApi.MessageBodyInput();
            fi.body.messageSegments = new List<ConnectApi.MessageSegmentInput>();
            ConnectApi.TextSegmentInput txt = new ConnectApi.TextSegmentInput();
            txt.text = 'CONTRACT EXPIRY ALERT: ' + c.Contract_Type__c + ' for ' + c.Account__r.Name + ' expires on ' + c.End_Date__c.format() + '. Please renew.';
            fi.body.messageSegments.add(txt);
            fi.subjectId = c.Account__c;
            ConnectApi.ChatterFeeds.postFeedElement(Network.getNetworkId(), fi);
        }
    }
    public void finish(Database.BatchableContext bc) { }
}
