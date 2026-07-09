@RestResource(urlMapping='/v1/application-intake')
global with sharing class ApplicationWebhookHandler {

    @HttpPost
    global static void handlePost() {
        RestRequest  req  = RestContext.request;
        RestResponse resp = RestContext.response;

        resp.addHeader('Content-Type', 'application/json');

        try {
            if (req.requestBody == null || req.requestBody.size() == 0) {
                sendError(resp, 400, 'Request body is empty.');
                return;
            }

            Map<String, Object> payload;
            try {
                payload = (Map<String, Object>) JSON.deserializeUntyped(
                    req.requestBody.toString()
                );
            } catch (JSONException e) {
                sendError(resp, 400, 'Invalid JSON payload.');
                return;
            }

            ApplicationIntakeService.ApplicationRequest appReq =
                mapPayload(payload);
            appReq.source = 'Webhook';

            ApplicationIntakeService.ApplicationResult result =
                ApplicationIntakeService.process(appReq);

            if (result.success) {
                resp.statusCode = 201;
                resp.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'success'    => true,
                    'recordId'   => result.recordId,
                    'recordType' => result.recordType
                }));
            } else {
                sendError(resp, 422, result.errorMessage);
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'Unhandled exception in ApplicationWebhookHandler: ' + e.getMessage()
            );
            sendError(resp, 500, 'An internal error occurred.');
        }
    }

    private static ApplicationIntakeService.ApplicationRequest mapPayload(
        Map<String, Object> p
    ) {
        ApplicationIntakeService.ApplicationRequest r =
            new ApplicationIntakeService.ApplicationRequest();

        r.companyName      = getString(p, new List<String>{ 'companyName', 'company_name', 'company' });
        r.email            = getString(p, new List<String>{ 'email' });
        r.phone            = getString(p, new List<String>{ 'phone', 'phoneNumber', 'phone_number' });
        r.contactFirstName = getString(p, new List<String>{ 'contactFirstName', 'first_name', 'firstName' });
        r.contactLastName  = getString(p, new List<String>{ 'contactLastName', 'last_name', 'lastName' });
        r.federalTaxId     = getString(p, new List<String>{ 'federalTaxId', 'federal_tax_id', 'taxId', 'tax_id', 'ein' });
        r.annualRevenue    = getDecimal(p, new List<String>{ 'annualRevenue', 'annual_revenue', 'revenue' });

        return r;
    }

    private static void sendError(RestResponse resp, Integer statusCode, String message) {
        resp.statusCode    = statusCode;
        resp.responseBody  = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'success' => false,
            'error'   => message
        }));
    }

    private static String getString(Map<String, Object> m, List<String> keys) {
        for (String key : keys) {
            if (m.containsKey(key) && m.get(key) != null) {
                String val = String.valueOf(m.get(key)).trim();
                if (String.isNotBlank(val)) return val;
            }
        }
        return null;
    }

    private static Decimal getDecimal(Map<String, Object> m, List<String> keys) {
        for (String key : keys) {
            if (m.containsKey(key) && m.get(key) != null) {
                try {
                    return Decimal.valueOf(String.valueOf(m.get(key)));
                } catch (Exception e) {
                }
            }
        }
        return null;
    }
}
