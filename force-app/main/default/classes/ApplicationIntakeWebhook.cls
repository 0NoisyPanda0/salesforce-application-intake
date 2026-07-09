@RestResource(urlMapping='/application/*')
global with sharing class ApplicationIntakeWebhook {

    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        res.addHeader('Content-Type', 'application/json');

        try {
            Map<String, Object> payload =
                (Map<String, Object>) JSON.deserializeUntyped(
                    req.requestBody.toString()
                );

            ApplicationIntakeService.ApplicationRequest appReq =
                new ApplicationIntakeService.ApplicationRequest();

            appReq.companyName      = (String)  safeGet(payload, 'companyName');
            appReq.email            = (String)  safeGet(payload, 'email');
            appReq.phone            = (String)  safeGet(payload, 'phone');
            appReq.contactFirstName = (String)  safeGet(payload, 'contactFirstName');
            appReq.contactLastName  = (String)  safeGet(payload, 'contactLastName');
            appReq.federalTaxId     = (String)  safeGet(payload, 'federalTaxId');
            appReq.annualRevenue    = safeGetDecimal(payload, 'annualRevenue');
            appReq.source           = 'Webhook';

            ApplicationIntakeService.ApplicationResult result =
                ApplicationIntakeService.process(appReq);

            res.statusCode = result.success ? 200 : 400;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new Map<String, Object>{
                    'success'      => result.success,
                    'recordId'     => result.recordId,
                    'recordType'   => result.recordType,
                    'errorMessage' => result.errorMessage
                })
            );

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(
                JSON.serialize(new Map<String, Object>{
                    'success'      => false,
                    'errorMessage' => e.getMessage()
                })
            );
        }
    }

    private static Object safeGet(Map<String, Object> m, String key) {
        return m != null && m.containsKey(key) ? m.get(key) : null;
    }

    private static Decimal safeGetDecimal(Map<String, Object> m, String key) {
        Object val = safeGet(m, key);
        if (val == null) return null;
        try {
            return Decimal.valueOf(String.valueOf(val));
        } catch (Exception e) {
            return null;
        }
    }
}
