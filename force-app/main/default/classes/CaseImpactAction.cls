global class CaseImpactAction {

    @InvocableMethod(label='Analyze Case Impact' description='Analyze open cases for an account to determine customer satisfaction impact. Returns case counts by priority and overall impact level.')
    global static List<CaseImpactOutput> analyzeCaseImpact(List<CaseImpactInput> inputs) {
        List<CaseImpactOutput> outputs = new List<CaseImpactOutput>();

        for (CaseImpactInput input : inputs) {
            Map<String, Object> summary = CaseImpactAnalyzer.getCaseImpactSummary(input.accountId);

            CaseImpactOutput output = new CaseImpactOutput();
            output.impactLevel = (String) summary.get('impactLevel');
            output.openCaseCount = (Integer) summary.get('openCaseCount');
            output.highPriorityCount = (Integer) summary.get('highPriorityCount');
            output.mediumPriorityCount = (Integer) summary.get('mediumPriorityCount');
            output.lowPriorityCount = (Integer) summary.get('lowPriorityCount');

            // Serialize case details for output
            List<CaseImpactAnalyzer.CaseDetail> cases =
                (List<CaseImpactAnalyzer.CaseDetail>) summary.get('cases');
            output.casesJSON = JSON.serialize(cases);

            outputs.add(output);
        }

        return outputs;
    }

    global class CaseImpactInput {
        @InvocableVariable(label='Account ID' description='Salesforce Account ID (18-character ID starting with 001)' required=true)
        global Id accountId;
    }

    global class CaseImpactOutput {
        @InvocableVariable(label='Impact Level' description='Overall impact: Critical, High, Medium, or Low')
        global String impactLevel;

        @InvocableVariable(label='Open Case Count' description='Total number of open cases')
        global Integer openCaseCount;

        @InvocableVariable(label='High Priority Count' description='Number of high priority cases')
        global Integer highPriorityCount;

        @InvocableVariable(label='Medium Priority Count' description='Number of medium priority cases')
        global Integer mediumPriorityCount;

        @InvocableVariable(label='Low Priority Count' description='Number of low priority cases')
        global Integer lowPriorityCount;

        @InvocableVariable(label='Cases JSON' description='JSON array of case details')
        global String casesJSON;
    }
}