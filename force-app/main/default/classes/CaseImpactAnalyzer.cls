public without sharing class CaseImpactAnalyzer {

    public class CaseImpact {
        @AuraEnabled public Integer openCaseCount { get; set; }
        @AuraEnabled public Integer highPriorityCount { get; set; }
        @AuraEnabled public Integer mediumPriorityCount { get; set; }
        @AuraEnabled public Integer lowPriorityCount { get; set; }
        @AuraEnabled public List<CaseDetail> cases { get; set; }
    }

    public class CaseDetail {
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Integer daysOpen { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static CaseImpact analyzeCases(Id accountId) {
        CaseImpact impact = new CaseImpact();
        impact.cases = new List<CaseDetail>();

        List<Case> cases = [
            SELECT CaseNumber, Subject, Priority, Status, CreatedDate
            FROM Case
            WHERE AccountId = :accountId
            AND IsClosed = false
            ORDER BY Priority DESC, CreatedDate ASC
        ];

        impact.openCaseCount = cases.size();
        impact.highPriorityCount = 0;
        impact.mediumPriorityCount = 0;
        impact.lowPriorityCount = 0;

        for (Case c : cases) {
            if (c.Priority == 'High') {
                impact.highPriorityCount++;
            } else if (c.Priority == 'Medium') {
                impact.mediumPriorityCount++;
            } else {
                impact.lowPriorityCount++;
            }

            CaseDetail detail = new CaseDetail();
            detail.caseNumber = c.CaseNumber;
            detail.subject = c.Subject;
            detail.priority = c.Priority;
            detail.status = c.Status;
            detail.daysOpen = Date.today().daysBetween(c.CreatedDate.date());

            impact.cases.add(detail);
        }

        return impact;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCaseImpactSummary(Id accountId) {
        Map<String, Object> summary = new Map<String, Object>();

        CaseImpact impact = analyzeCases(accountId);

        String impactLevel;
        if (impact.highPriorityCount >= 2) {
            impactLevel = 'Critical';
        } else if (impact.highPriorityCount >= 1) {
            impactLevel = 'High';
        } else if (impact.mediumPriorityCount >= 2) {
            impactLevel = 'Medium';
        } else {
            impactLevel = 'Low';
        }

        summary.put('impactLevel', impactLevel);
        summary.put('openCaseCount', impact.openCaseCount);
        summary.put('highPriorityCount', impact.highPriorityCount);
        summary.put('mediumPriorityCount', impact.mediumPriorityCount);
        summary.put('lowPriorityCount', impact.lowPriorityCount);
        summary.put('cases', impact.cases);

        return summary;
    }
}