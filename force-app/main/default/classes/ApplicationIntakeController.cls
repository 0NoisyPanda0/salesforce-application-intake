public with sharing class ApplicationIntakeController {

    @AuraEnabled
    public static Map<String, Object> submitApplication(Map<String, Object> payload) {

        ApplicationIntakeService.ApplicationRequest req =
            new ApplicationIntakeService.ApplicationRequest();

        req.companyName      = (String)  safeGet(payload, 'companyName');
        req.email            = (String)  safeGet(payload, 'email');
        req.phone            = (String)  safeGet(payload, 'phone');
        req.contactFirstName = (String)  safeGet(payload, 'contactFirstName');
        req.contactLastName  = (String)  safeGet(payload, 'contactLastName');
        req.federalTaxId     = (String)  safeGet(payload, 'federalTaxId');
        req.annualRevenue    = safeGetDecimal(payload, 'annualRevenue');
        req.source           = 'Community';

        ApplicationIntakeService.ApplicationResult result =
            ApplicationIntakeService.process(req);

        return new Map<String, Object>{
            'success'      => result.success,
            'recordId'     => result.recordId,
            'recordType'   => result.recordType,
            'errorMessage' => result.errorMessage
        };
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
