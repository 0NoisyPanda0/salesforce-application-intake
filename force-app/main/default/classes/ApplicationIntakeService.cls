public with sharing class ApplicationIntakeService {

    public class ApplicationRequest {
        public String companyName;
        public String email;
        public String phone;
        public String contactFirstName;
        public String contactLastName;
        public String federalTaxId;
        public Decimal annualRevenue;
        public String source;
    }

    public class ApplicationResult {
        public Boolean success;
        public String recordId;
        public String recordType;
        public String errorMessage;

        public ApplicationResult(Boolean success, String recordId, String recordType) {
            this.success     = success;
            this.recordId    = recordId;
            this.recordType  = recordType;
        }

        public ApplicationResult(String errorMessage) {
            this.success      = false;
            this.errorMessage = errorMessage;
        }
    }

    // ─── Constants ───────────────────────────────────────────────────────────

    private static final String SOURCE_COMMUNITY = 'Community';
    private static final String SOURCE_WEBHOOK   = 'Webhook';
    private static final Set<String> VALID_SOURCES = new Set<String>{
        SOURCE_COMMUNITY, SOURCE_WEBHOOK
    };

    /**
     * @param  req
     * @return
     */

    public static ApplicationResult process(ApplicationRequest req) {
        try {
            validateRequest(req);

            Account matchedAccount = findMatchingAccount(req);

            if (matchedAccount != null) {
                Opportunity opp = createOpportunity(req, matchedAccount);
                return new ApplicationResult(true, opp.Id, 'Opportunity');
            } else {
                Lead lead = createLead(req);
                return new ApplicationResult(true, lead.Id, 'Lead');
            }

        } catch (ApplicationValidationException e) {
            return new ApplicationResult(e.getMessage());

        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'DML failure in ApplicationIntakeService: ' + e.getMessage());
            return new ApplicationResult('A database error occurred. Please try again later.');

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Unexpected error in ApplicationIntakeService: ' + e.getMessage());
            return new ApplicationResult('An unexpected error occurred. Please contact support.');
        }
    }

    private static void validateRequest(ApplicationRequest req) {
        if (req == null) {
            throw new ApplicationValidationException('Request payload cannot be null.');
        }

        List<String> missing = new List<String>();

        if (String.isBlank(req.companyName))      missing.add('Company Name');
        if (String.isBlank(req.email))            missing.add('Email');
        if (String.isBlank(req.phone))            missing.add('Phone');
        if (String.isBlank(req.contactFirstName)) missing.add('Contact First Name');
        if (String.isBlank(req.contactLastName))  missing.add('Contact Last Name');

        if (!missing.isEmpty()) {
            throw new ApplicationValidationException(
                'Missing required fields: ' + String.join(missing, ', ')
            );
        }

        if (!isValidEmail(req.email)) {
            throw new ApplicationValidationException('Invalid email format: ' + req.email);
        }

        if (!VALID_SOURCES.contains(req.source)) {
            throw new ApplicationValidationException(
                'Invalid source value. Must be Community or Webhook.'
            );
        }

        if (req.annualRevenue != null && req.annualRevenue < 0) {
            throw new ApplicationValidationException('Annual Revenue cannot be negative.');
        }

        req.companyName    = req.companyName.trim();
        req.federalTaxId   = String.isBlank(req.federalTaxId) ? null : req.federalTaxId.trim();
    }

    private static Boolean isValidEmail(String email) {
        return Pattern.matches(
            '^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$',
            email
        );
    }

    /**
     * @param  req
     * @return
     */

    private static Account findMatchingAccount(ApplicationRequest req) {
        if (String.isNotBlank(req.federalTaxId)) {
            List<Account> taxMatches = [
                SELECT Id, Name
                FROM   Account
                WHERE  Federal_Tax_ID__c = :req.federalTaxId
                LIMIT  1
            ];
            if (!taxMatches.isEmpty()) {
                return taxMatches[0];
            }
        }

        List<Account> nameMatches = [
            SELECT Id, Name
            FROM   Account
            WHERE  Name = :req.companyName
            LIMIT  1
        ];

        return nameMatches.isEmpty() ? null : nameMatches[0];
    }

    private static Opportunity createOpportunity(ApplicationRequest req, Account acct) {
        Opportunity opp = new Opportunity(
            Name               = req.companyName + ' — Application',
            AccountId          = acct.Id,
            StageName          = 'Prospecting',
            CloseDate          = Date.today().addDays(30),
            Application_Source__c = req.source,
            Description        = buildDescription(req)
        );
        insert opp;
        return opp;
    }

    private static Lead createLead(ApplicationRequest req) {
        Lead lead = new Lead(
            FirstName             = req.contactFirstName,
            LastName              = req.contactLastName,
            Company               = req.companyName,
            Email                 = req.email,
            Phone                 = req.phone,
            AnnualRevenue         = req.annualRevenue,
            Application_Source__c = req.source,
            Description           = buildDescription(req)
        );
        insert lead;
        return lead;
    }

    private static String buildDescription(ApplicationRequest req) {
        return String.format(
            'Submitted via {0}. Contact: {1} {2} | Email: {3} | Phone: {4}{5}',
            new List<Object>{
                req.source,
                req.contactFirstName,
                req.contactLastName,
                req.email,
                req.phone,
                String.isNotBlank(req.federalTaxId) ? ' | Tax ID: ' + req.federalTaxId : ''
            }
        );
    }

    public class ApplicationValidationException extends Exception {}
}
