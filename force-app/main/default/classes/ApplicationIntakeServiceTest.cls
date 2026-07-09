@IsTest
private class ApplicationIntakeServiceTest {

    private static ApplicationIntakeService.ApplicationRequest buildRequest(
        String companyName,
        String source
    ) {
        ApplicationIntakeService.ApplicationRequest req =
            new ApplicationIntakeService.ApplicationRequest();
        req.companyName      = companyName;
        req.email            = 'test@example.com';
        req.phone            = '555-1234';
        req.contactFirstName = 'Jane';
        req.contactLastName  = 'Smith';
        req.source           = source;
        return req;
    }

    private static Account insertAccount(String name, String taxId) {
        Account acct = new Account(Name = name);
        if (taxId != null) acct.Federal_Tax_ID__c = taxId;
        insert acct;
        return acct;
    }

    @IsTest
    static void test_leadCreated_whenNoAccountMatch() {
        ApplicationIntakeService.ApplicationRequest req =
            buildRequest('Acme Corp — No Match', 'Community');

        Test.startTest();
        ApplicationIntakeService.ApplicationResult result =
            ApplicationIntakeService.process(req);
        Test.stopTest();

        System.assert(result.success, 'Expected success=true');
        System.assertEquals('Lead', result.recordType, 'Expected a Lead to be created');
        System.assertNotEquals(null, result.recordId, 'Expected a valid record Id');

        Lead created = [
            SELECT Company, Email, Application_Source__c
            FROM   Lead
            WHERE  Id = :result.recordId
        ];
        System.assertEquals('Acme Corp — No Match', created.Company);
        System.assertEquals('Community', created.Application_Source__c);
        System.assertEquals('test@example.com', created.Email);
    }

    @IsTest
    static void test_opportunityCreated_whenAccountMatchedByTaxId() {
        Account acct = insertAccount('Global Widgets Inc', '12-3456789');

        ApplicationIntakeService.ApplicationRequest req =
            buildRequest('Global Widgets Inc', 'Webhook');
        req.federalTaxId = '12-3456789';

        Test.startTest();
        ApplicationIntakeService.ApplicationResult result =
            ApplicationIntakeService.process(req);
        Test.stopTest();

        System.assert(result.success, 'Expected success=true');
        System.assertEquals('Opportunity', result.recordType,
            'Expected an Opportunity when account is matched by Tax ID');

        Opportunity opp = [
            SELECT AccountId, Application_Source__c, StageName
            FROM   Opportunity
            WHERE  Id = :result.recordId
        ];
        System.assertEquals(acct.Id, opp.AccountId);
        System.assertEquals('Webhook', opp.Application_Source__c);
        System.assertEquals('Prospecting', opp.StageName);
    }

    @IsTest
    static void test_opportunityCreated_whenAccountMatchedByCompanyName() {
        Account acct = insertAccount('NameMatch LLC', null);

        ApplicationIntakeService.ApplicationRequest req =
            buildRequest('NameMatch LLC', 'Community');

        Test.startTest();
        ApplicationIntakeService.ApplicationResult result =
            ApplicationIntakeService.process(req);
        Test.stopTest();

        System.assert(result.success, 'Expected success=true');
        System.assertEquals('Opportunity', result.recordType,
            'Expected Opportunity when matched by company name');

        Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :result.recordId];
        System.assertEquals(acct.Id, opp.AccountId);
    }

    @IsTest
    static void test_webhook_validPayload_createsLead() {
        RestRequest req   = new RestRequest();
        RestResponse resp = new RestResponse();

        req.httpMethod  = 'POST';
        req.requestURI  = '/services/apexrest/v1/application-intake';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'company_name'  => 'Webhook Corp',
            'email'         => 'wh@example.com',
            'phone'         => '555-9999',
            'first_name'    => 'Bob',
            'last_name'     => 'Builder',
            'annual_revenue'=> 500000
        }));

        RestContext.request  = req;
        RestContext.response = resp;

        Test.startTest();
        ApplicationWebhookHandler.handlePost();
        Test.stopTest();

        System.assertEquals(201, resp.statusCode, 'Expected HTTP 201 Created');

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(resp.responseBody.toString());
        System.assertEquals(true,   body.get('success'));
        System.assertEquals('Lead', body.get('recordType'));
        System.assertNotEquals(null, body.get('recordId'));
    }

    @IsTest
    static void test_webhook_invalidJson_returns400() {
        RestRequest req   = new RestRequest();
        RestResponse resp = new RestResponse();

        req.httpMethod  = 'POST';
        req.requestBody = Blob.valueOf('{ this is not json !!!');

        RestContext.request  = req;
        RestContext.response = resp;

        Test.startTest();
        ApplicationWebhookHandler.handlePost();
        Test.stopTest();

        System.assertEquals(400, resp.statusCode, 'Expected HTTP 400 for malformed JSON');

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(resp.responseBody.toString());
        System.assertEquals(false, body.get('success'));
        System.assertNotEquals(null, body.get('error'));
    }

    @IsTest
    static void test_webhook_missingRequiredFields_returns422() {
        RestRequest req   = new RestRequest();
        RestResponse resp = new RestResponse();

        req.httpMethod  = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'company_name' => 'Incomplete Corp'
        }));

        RestContext.request  = req;
        RestContext.response = resp;

        Test.startTest();
        ApplicationWebhookHandler.handlePost();
        Test.stopTest();

        System.assertEquals(422, resp.statusCode,
            'Expected HTTP 422 for business validation failure');

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(resp.responseBody.toString());
        System.assertEquals(false, body.get('success'));
    }

    @IsTest
    static void test_webhook_emptyBody_returns400() {
        RestRequest req   = new RestRequest();
        RestResponse resp = new RestResponse();

        req.httpMethod  = 'POST';
        // Intentionally no requestBody set

        RestContext.request  = req;
        RestContext.response = resp;

        Test.startTest();
        ApplicationWebhookHandler.handlePost();
        Test.stopTest();

        System.assertEquals(400, resp.statusCode, 'Expected 400 for empty body');
    }

    @IsTest
    static void test_validation_missingRequiredFields_returnsFalse() {
        ApplicationIntakeService.ApplicationRequest req =
            new ApplicationIntakeService.ApplicationRequest();
        req.companyName = 'Only Company';
        req.source      = 'Community';
        // email, phone, names all absent

        Test.startTest();
        ApplicationIntakeService.ApplicationResult result =
            ApplicationIntakeService.process(req);
        Test.stopTest();

        System.assertEquals(false,  result.success);
        System.assertNotEquals(null, result.errorMessage);
        System.assert(
            result.errorMessage.containsIgnoreCase('Missing required fields'),
            'Error should mention missing fields. Got: ' + result.errorMessage
        );
    }

    @IsTest
    static void test_validation_invalidEmail_returnsFalse() {
        ApplicationIntakeService.ApplicationRequest req =
            buildRequest('Bad Email Co', 'Community');
        req.email = 'not-an-email';

        Test.startTest();
        ApplicationIntakeService.ApplicationResult result =
            ApplicationIntakeService.process(req);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(
            result.errorMessage.containsIgnoreCase('Invalid email'),
            'Expected invalid email message. Got: ' + result.errorMessage
        );
    }

    @IsTest
    static void test_validation_negativeRevenue_returnsFalse() {
        ApplicationIntakeService.ApplicationRequest req =
            buildRequest('Negative Revenue Co', 'Webhook');
        req.annualRevenue = -100;

        Test.startTest();
        ApplicationIntakeService.ApplicationResult result =
            ApplicationIntakeService.process(req);
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assert(
            result.errorMessage.containsIgnoreCase('Annual Revenue'),
            'Expected revenue validation message. Got: ' + result.errorMessage
        );
    }
}
