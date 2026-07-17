global class AdherenceAction {

    @InvocableMethod(label='Get Adherence Summary' description='Get adherence performance summary for a Sales Agreement. Returns average adherence, count below threshold, and detailed breakdown per product line.')
    global static List<AdherenceOutput> getAdherenceSummary(List<AdherenceInput> inputs) {
        List<AdherenceOutput> outputs = new List<AdherenceOutput>();

        for (AdherenceInput input : inputs) {
            Map<String, Object> summary = AdherenceCalculator.getAdherenceSummary(input.salesAgreementId);
            AdherenceCalculator.updateScheduleAdherence(input.salesAgreementId);

            AdherenceOutput output = new AdherenceOutput();
            output.averageAdherence = (Decimal) summary.get('averageAdherence');
            output.totalProductLines = (Integer) summary.get('totalProductLines');
            output.belowThresholdCount = (Integer) summary.get('belowThresholdCount');
            output.thresholdPercentage = (Integer) summary.get('thresholdPercentage');
            output.targetPercentage = (Integer) summary.get('targetPercentage');

            // Serialize details for output
            List<AdherenceCalculator.AdherenceDetail> details =
                (List<AdherenceCalculator.AdherenceDetail>) summary.get('details');
            output.detailsJSON = JSON.serialize(details);

            outputs.add(output);
        }

        return outputs;
    }

    global class AdherenceInput {
        @InvocableVariable(label='Sales Agreement ID' description='Salesforce Sales Agreement ID (starts with 0YA)' required=true)
        global Id salesAgreementId;
    }

    global class AdherenceOutput {
        @InvocableVariable(label='Average Adherence' description='Average adherence percentage across all product lines')
        global Decimal averageAdherence;

        @InvocableVariable(label='Total Product Lines' description='Total number of product lines')
        global Integer totalProductLines;

        @InvocableVariable(label='Below Threshold Count' description='Number of product lines below 80% threshold')
        global Integer belowThresholdCount;

        @InvocableVariable(label='Threshold Percentage' description='Threshold percentage (80%)')
        global Integer thresholdPercentage;

        @InvocableVariable(label='Target Percentage' description='Target percentage (85%)')
        global Integer targetPercentage;

        @InvocableVariable(label='Details JSON' description='JSON array of detailed adherence per product line')
        global String detailsJSON;
    }
}