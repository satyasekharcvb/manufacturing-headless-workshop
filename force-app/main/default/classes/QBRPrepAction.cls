global class QBRPrepAction {

    @InvocableMethod(label='Prepare QBR' description='Assemble a Quarterly Business Review packet for an account: renewal risk, adherence trend, open cases, asset health, and generated talking points.')
    global static List<QBROutput> prepareQBR(List<QBRInput> inputs) {
        List<QBROutput> outputs = new List<QBROutput>();

        for (QBRInput input : inputs) {
            QBRPrepCalculator.QBRSummary summary = QBRPrepCalculator.prepareQBR(input.accountId);

            QBROutput output = new QBROutput();
            output.accountName = summary.accountName;
            output.salesAgreementName = summary.salesAgreementName;
            output.renewalDate = summary.renewalDate;
            output.daysUntilRenewal = summary.daysUntilRenewal;
            output.riskScore = summary.riskScore;
            output.riskLevel = summary.riskLevel;
            output.adherenceScore = summary.adherenceScore;
            output.adherenceTrend = summary.adherenceTrend;
            output.assetHealthScore = summary.assetHealthScore;
            output.openCaseCount = summary.openCaseCount;
            output.highPriorityCaseCount = summary.highPriorityCaseCount;
            output.productAdherenceSummary = String.join(summary.productAdherenceSummary, '\n');
            output.openCaseSummary = String.join(summary.openCaseSummary, '\n');
            output.talkingPoints = String.join(summary.talkingPoints, '\n');

            outputs.add(output);
        }

        return outputs;
    }

    global class QBRInput {
        @InvocableVariable(label='Account ID' description='Salesforce Account ID (18-character ID starting with 001)' required=true)
        global Id accountId;
    }

    global class QBROutput {
        @InvocableVariable(label='Account Name' description='Account name')
        global String accountName;

        @InvocableVariable(label='Sales Agreement Name' description='Sales Agreement name')
        global String salesAgreementName;

        @InvocableVariable(label='Renewal Date' description='Contract renewal date')
        global Date renewalDate;

        @InvocableVariable(label='Days Until Renewal' description='Days remaining until contract renewal')
        global Integer daysUntilRenewal;

        @InvocableVariable(label='Risk Score' description='Risk score from 0-100 (higher = more risk)')
        global Decimal riskScore;

        @InvocableVariable(label='Risk Level' description='Risk classification: Low, Medium, High, or Critical')
        global String riskLevel;

        @InvocableVariable(label='Adherence Score' description='Average adherence percentage across product lines')
        global Decimal adherenceScore;

        @InvocableVariable(label='Adherence Trend' description='Quarter-over-quarter adherence trend: Improving, Declining, Stable, or Insufficient Data')
        global String adherenceTrend;

        @InvocableVariable(label='Asset Health Score' description='Average asset health percentage')
        global Decimal assetHealthScore;

        @InvocableVariable(label='Open Case Count' description='Number of open cases for this account')
        global Integer openCaseCount;

        @InvocableVariable(label='High Priority Case Count' description='Number of open High-priority cases')
        global Integer highPriorityCaseCount;

        @InvocableVariable(label='Product Adherence Summary' description='Per-product adherence score and status, one per line')
        global String productAdherenceSummary;

        @InvocableVariable(label='Open Case Summary' description='Open case number, subject, priority, and days open, one per line')
        global String openCaseSummary;

        @InvocableVariable(label='Talking Points' description='Generated QBR talking points based on risk, adherence, cases, and asset health, one per line')
        global String talkingPoints;
    }
}
