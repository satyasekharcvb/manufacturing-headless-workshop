global class RenewalRiskAction {

    @InvocableMethod(label='Calculate Renewal Risk' description='Calculate renewal risk score (0-100) for an account. Analyzes adherence, asset health, open cases, and renewal timing to determine risk level (Low/Medium/High/Critical).')
    global static List<RiskOutput> calculateRisk(List<RiskInput> inputs) {
        List<RiskOutput> outputs = new List<RiskOutput>();

        for (RiskInput input : inputs) {
            RenewalRiskScorer.RiskResult result = RenewalRiskScorer.calculateRenewalRisk(input.accountId);

            RiskOutput output = new RiskOutput();
            output.riskScore = result.riskScore;
            output.riskLevel = result.riskLevel;
            output.adherenceScore = result.adherenceScore;
            output.assetHealthScore = result.assetHealthScore;
            output.openCaseCount = result.openCaseCount;
            output.daysUntilRenewal = result.daysUntilRenewal;
            output.renewalDate = result.renewalDate;
            output.accountName = result.accountName;
            output.salesAgreementName = result.salesAgreementName;

            outputs.add(output);
        }

        return outputs;
    }

    global class RiskInput {
        @InvocableVariable(label='Account ID' description='Salesforce Account ID (18-character ID starting with 001)' required=true)
        global Id accountId;
    }

    global class RiskOutput {
        @InvocableVariable(label='Risk Score' description='Risk score from 0-100 (higher = more risk)')
        global Decimal riskScore;

        @InvocableVariable(label='Risk Level' description='Risk classification: Low, Medium, High, or Critical')
        global String riskLevel;

        @InvocableVariable(label='Adherence Score' description='Average adherence percentage across product lines')
        global Decimal adherenceScore;

        @InvocableVariable(label='Asset Health Score' description='Average asset health percentage')
        global Decimal assetHealthScore;

        @InvocableVariable(label='Open Case Count' description='Number of open cases for this account')
        global Integer openCaseCount;

        @InvocableVariable(label='Days Until Renewal' description='Days remaining until contract renewal')
        global Integer daysUntilRenewal;

        @InvocableVariable(label='Renewal Date' description='Contract renewal date')
        global Date renewalDate;

        @InvocableVariable(label='Account Name' description='Account name')
        global String accountName;

        @InvocableVariable(label='Sales Agreement Name' description='Sales Agreement name')
        global String salesAgreementName;
    }
}