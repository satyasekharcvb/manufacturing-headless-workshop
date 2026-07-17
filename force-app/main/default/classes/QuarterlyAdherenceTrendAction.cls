global class QuarterlyAdherenceTrendAction {

    @InvocableMethod(label='Get Renewals With Adherence Trend' description='Find active Sales Agreements renewing within a date window and report whether their schedule adherence is declining, improving, or stable quarter-over-quarter.')
    global static List<TrendOutput> getRenewalsWithAdherenceTrend(List<TrendInput> inputs) {
        List<TrendOutput> outputs = new List<TrendOutput>();

        for (TrendInput input : inputs) {
            List<QuarterlyAdherenceTrendCalculator.TrendResult> results =
                QuarterlyAdherenceTrendCalculator.getRenewalsWithAdherenceTrend(input.renewalWindowStart, input.renewalWindowEnd);

            for (QuarterlyAdherenceTrendCalculator.TrendResult r : results) {
                TrendOutput output = new TrendOutput();
                output.accountId = r.accountId;
                output.accountName = r.accountName;
                output.salesAgreementId = r.salesAgreementId;
                output.salesAgreementName = r.salesAgreementName;
                output.renewalDate = r.renewalDate;
                output.currentPeriodAdherence = r.currentPeriodAdherence;
                output.previousPeriodAdherence = r.previousPeriodAdherence;
                output.trend = r.trend;

                outputs.add(output);
            }
        }

        return outputs;
    }

    global class TrendInput {
        @InvocableVariable(label='Renewal Window Start' description='Start of the renewal date window to check, e.g. the first day of the target quarter' required=true)
        global Date renewalWindowStart;

        @InvocableVariable(label='Renewal Window End' description='End of the renewal date window to check, e.g. the last day of the target quarter' required=true)
        global Date renewalWindowEnd;
    }

    global class TrendOutput {
        @InvocableVariable(label='Account ID' description='Salesforce Account ID')
        global Id accountId;

        @InvocableVariable(label='Account Name' description='Account name')
        global String accountName;

        @InvocableVariable(label='Sales Agreement ID' description='Salesforce Sales Agreement ID')
        global Id salesAgreementId;

        @InvocableVariable(label='Sales Agreement Name' description='Sales Agreement name')
        global String salesAgreementName;

        @InvocableVariable(label='Renewal Date' description='Sales Agreement end date (renewal date)')
        global Date renewalDate;

        @InvocableVariable(label='Current Period Adherence' description='Adherence percentage for the most recently completed schedule period')
        global Decimal currentPeriodAdherence;

        @InvocableVariable(label='Previous Period Adherence' description='Adherence percentage for the schedule period before that')
        global Decimal previousPeriodAdherence;

        @InvocableVariable(label='Trend' description='Declining, Improving, Stable, or Insufficient Data')
        global String trend;
    }
}