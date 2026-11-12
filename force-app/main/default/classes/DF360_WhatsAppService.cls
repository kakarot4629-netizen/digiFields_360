public with sharing class DF360_WhatsAppService {

    public class SendRequest {
        @InvocableVariable(required=false label='Recipient Mobile')
        public String toMobile;
        @InvocableVariable(required=true label='Template Name')
        public String templateName;
        @InvocableVariable(required=false label='Parameters JSON')
        public String paramsJson;
        @InvocableVariable(required=false label='Language Code')
        public String languageCode;
        @InvocableVariable(required=false label='Lang Code')
        public String langCode;
    }

    @InvocableMethod(label='Send WhatsApp Message' description='Sends a WhatsApp template message via Meta Cloud API')
    public static void sendFromFlow(List<SendRequest> requests) {
        for (SendRequest r : requests) {
            if (String.isBlank(r.toMobile)) {
                continue;
            }
            String lang = String.isNotBlank(r.languageCode) ? r.languageCode : (String.isNotBlank(r.langCode) ? r.langCode : 'en');
            sendAsync(r.toMobile, r.templateName, r.paramsJson, lang);
        }
    }

    public static void send(String toMobile, String templateName, String paramsJson, String lang) {
        if (String.isBlank(toMobile)) return;
        if (String.isBlank(lang)) lang = 'en';

        List<Object> bodyParams = new List<Object>();
        if (String.isNotBlank(paramsJson)) {
            try {
                List<Object> rawList = (List<Object>) JSON.deserializeUntyped(paramsJson);
                for (Object item : rawList) {
                    bodyParams.add(new Map<String,Object>{ 'type' => 'text', 'text' => String.valueOf(item) });
                }
            } catch(Exception parseEx) {
                System.debug('JSON params parse fallback: ' + parseEx.getMessage());
            }
        }
        List<Object> components = new List<Object>();
        if (!bodyParams.isEmpty()) {
            components.add(new Map<String,Object>{ 'type' => 'body', 'parameters' => bodyParams });
        }
        Map<String,Object> payload = new Map<String,Object>{
            'messaging_product' => 'whatsapp',
            'to' => toMobile.replaceAll('[^0-9+]', ''),
            'type' => 'template',
            'template' => new Map<String,Object>{
                'name' => templateName,
                'language' => new Map<String,Object>{ 'code' => lang },
                'components' => components
            }
        };
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:DF360_MetaWhatsApp/messages');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(payload));
            req.setTimeout(10000);
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                System.debug('WhatsApp API response: ' + res.getStatus());
            }
        } catch(Exception e) {
            System.debug('WhatsApp callout simulated in test/offline: ' + e.getMessage());
        }
    }

    public static void sendAsync(String toMobile, String templateName, String paramsJson) {
        sendAsync(toMobile, templateName, paramsJson, 'en');
    }

    public static void sendAsync(String toMobile, String templateName, String paramsJson, String lang) {
        if (System.isFuture() || System.isBatch()) {
            send(toMobile, templateName, paramsJson, lang);
        } else {
            sendAsyncFuture(toMobile, templateName, paramsJson, lang);
        }
    }

    @future(callout=true)
    public static void sendAsyncFuture(String toMobile, String templateName, String paramsJson, String lang) {
        try { 
            send(toMobile, templateName, paramsJson, lang); 
        } catch(Exception ex) { 
            System.debug('WhatsApp future error: ' + ex.getMessage()); 
        }
    }
}
