public with sharing class DF360_WhatsAppService {

    // 6 approved templates: job_confirmation, tech_enroute, tech_arrived, job_completed, sla_apology, parts_delay
    @InvocableMethod(label='Send Field360 WhatsApp' description='Send a WhatsApp template to a customer for a service job')
    public static List<String> sendFromFlow(List<SendRequest> requests) {
        List<String> results = new List<String>();
        for (SendRequest req : requests) {
            try {
                send(req.toMobile, req.templateName, req.paramsJson, req.languageCode);
                results.add('OK');
            } catch(Exception ex) { results.add('ERROR: ' + ex.getMessage()); }
        }
        return results;
    }

    public class SendRequest {
        @InvocableVariable(required=true label='To Mobile') public String toMobile;
        @InvocableVariable(required=true label='Template Name') public String templateName;
        @InvocableVariable(label='Params JSON') public String paramsJson;
        @InvocableVariable(label='Language Code') public String languageCode;
        @InvocableVariable(label='Service Job Id') public Id serviceJobId;
    }

    public static void send(String toMobile, String templateName, String paramsJson, String languageCode) {
        if (String.isBlank(toMobile)) throw new AuraHandledException('toMobile is required');
        String lang = String.isBlank(languageCode) ? 'en' : languageCode;
        List<Object> paramList = String.isNotBlank(paramsJson)
            ? (List<Object>) JSON.deserializeUntyped(paramsJson) : new List<Object>();
        List<Map<String,Object>> components = new List<Map<String,Object>>();
        if (!paramList.isEmpty()) {
            List<Map<String,Object>> params = new List<Map<String,Object>>();
            for (Object rawItem : paramList) {
                params.add(new Map<String,Object>{ 'type'=>'text', 'text'=> String.valueOf(rawItem) });
            }
            components.add(new Map<String,Object>{ 'type'=>'body', 'parameters'=> params });
        }
        Map<String,Object> payload = new Map<String,Object>{
            'messaging_product' => 'whatsapp',
            'to' => toMobile,
            'type' => 'template',
            'template' => new Map<String,Object>{
                'name' => templateName,
                'language' => new Map<String,Object>{ 'code' => lang },
                'components' => components
            }
        };
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:DF360_MetaWhatsApp/messages');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(10000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300)
            throw new AuraHandledException('WhatsApp API error: ' + res.getStatus());
    }

    public static void sendAsync(String toMobile, String templateName, String paramsJson) {
        sendAsyncFuture(toMobile, templateName, paramsJson, 'en');
    }

    @future(callout=true)
    public static void sendAsyncFuture(String toMobile, String templateName, String paramsJson, String lang) {
        try { send(toMobile, templateName, paramsJson, lang); } catch(Exception ex) { System.debug(ex.getMessage()); }
    }
}
