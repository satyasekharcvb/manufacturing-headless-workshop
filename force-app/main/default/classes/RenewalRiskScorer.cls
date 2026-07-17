global without sharing class RenewalRiskScorer {

    global class Request {
        @InvocableVariable(required=true label='Account Id') global Id accountId;
    }

    global class Response {
        @InvocableVariable global Decimal score;
        @InvocableVariable global Decimal adherenceDelta;
        @InvocableVariable global Integer openCasesInHubs;
        @InvocableVariable global Integer daysToRenewal;
    }

    @InvocableMethod(
        label='Score renewal risk'
        description='Compute a deterministic risk score (0.0-1.0) for an account renewal'
    )
    global static List<Response> scoreRenewalRisk(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            List<SalesAgreement> agreements = [
                SELECT Id, EndDate
                FROM SalesAgreement
                WHERE AccountId = :req.accountId
                AND Status = 'Activated'
                AND EndDate >= TODAY
                ORDER BY EndDate ASC
                LIMIT 1
            ];

            if (agreements.isEmpty()) {
                throw new IllegalArgumentException('No active upcoming Sales Agreement found for this account');
            }

            SalesAgreement agreement = agreements[0];

            Decimal avgAdherence = AdherenceCalculator.getAverageAdherence(agreement.Id);
            Integer openCaseCount = [
                SELECT COUNT()
                FROM Case
                WHERE AccountId = :req.accountId
                AND IsClosed = false
            ];

            Response resp = new Response();
            resp.adherenceDelta = 90 - avgAdherence;
            resp.openCasesInHubs = openCaseCount;
            resp.daysToRenewal = Date.today().daysBetween(agreement.EndDate);
            resp.score = computeScore(resp.adherenceDelta, resp.openCasesInHubs, resp.daysToRenewal);

            responses.add(resp);
        }

        return responses;
    }

    private static Decimal computeScore(Decimal adherenceDelta, Integer openCasesInHubs, Integer daysToRenewal) {
        Decimal score = 0;

        // Adherence component (45% weight)
        if (adherenceDelta > 15) {
            score += 0.45;
        } else if (adherenceDelta > 10) {
            score += 0.35;
        } else if (adherenceDelta > 5) {
            score += 0.20;
        } else if (adherenceDelta > 0) {
            score += 0.08;
        }

        // Open case component (35% weight)
        if (openCasesInHubs >= 3) {
            score += 0.35;
        } else if (openCasesInHubs == 2) {
            score += 0.25;
        } else if (openCasesInHubs == 1) {
            score += 0.12;
        }

        // Renewal urgency component (20% weight)
        if (daysToRenewal <= 30) {
            score += 0.20;
        } else if (daysToRenewal <= 60) {
            score += 0.14;
        } else if (daysToRenewal <= 90) {
            score += 0.06;
        }

        return score.setScale(2);
    }

    public class RiskResult {
        @AuraEnabled public Decimal riskScore { get; set; }
        @AuraEnabled public String riskLevel { get; set; }
        @AuraEnabled public Decimal adherenceScore { get; set; }
        @AuraEnabled public Decimal assetHealthScore { get; set; }
        @AuraEnabled public Integer openCaseCount { get; set; }
        @AuraEnabled public Integer daysUntilRenewal { get; set; }
        @AuraEnabled public Date renewalDate { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public String salesAgreementName { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static RiskResult calculateRenewalRisk(Id accountId) {
        RiskResult result = new RiskResult();

        // Get Sales Agreement for account
        List<SalesAgreement> agreements = [
            SELECT Id, Name, EndDate, AccountId, Account.Name
            FROM SalesAgreement
            WHERE AccountId = :accountId
            LIMIT 1
        ];

        if (agreements.isEmpty()) {
            throw new AuraHandledException('No Sales Agreement found for this account');
        }

        SalesAgreement sa = agreements[0];
        result.accountName = sa.Account.Name;
        result.salesAgreementName = sa.Name;

        // WORKAROUND: EndDate is auto-calculated incorrectly by Manufacturing Cloud
        // Workshop date: 2026-07-18, target renewal: 60 days later (2026-09-16)
        // For POC demo, hard-code the expected renewal date
        Date effectiveRenewalDate = Date.newInstance(2026, 9, 16);
        result.renewalDate = effectiveRenewalDate;
        result.daysUntilRenewal = Date.today().daysBetween(effectiveRenewalDate);

        // Get adherence score using AdherenceCalculator
        result.adherenceScore = AdherenceCalculator.getAverageAdherence(sa.Id);

        // Get asset health score
        AggregateResult[] assetHealthResults = [
            SELECT AVG(health_score__c) avgHealth
            FROM Asset
            WHERE AccountId = :accountId AND health_score__c != null
        ];

        if (!assetHealthResults.isEmpty() && assetHealthResults[0].get('avgHealth') != null) {
            result.assetHealthScore = ((Decimal)assetHealthResults[0].get('avgHealth')) * 100;
        } else {
            result.assetHealthScore = 0;
        }

        // Get open case count and severity using CaseImpactAnalyzer
        CaseImpactAnalyzer.CaseImpact caseImpact = CaseImpactAnalyzer.analyzeCases(accountId);
        result.openCaseCount = caseImpact.openCaseCount;

        // Calculate risk score (0-100, higher = more risk)
        result.riskScore = calculateScore(
            result.adherenceScore,
            result.assetHealthScore,
            result.openCaseCount,
            caseImpact.highPriorityCount,
            result.daysUntilRenewal
        );

        // Determine risk level
        if (result.riskScore >= 70) {
            result.riskLevel = 'Critical';
        } else if (result.riskScore >= 50) {
            result.riskLevel = 'High';
        } else if (result.riskScore >= 30) {
            result.riskLevel = 'Medium';
        } else {
            result.riskLevel = 'Low';
        }

        return result;
    }

    private static Decimal calculateScore(
        Decimal adherenceScore,
        Decimal assetHealthScore,
        Integer openCaseCount,
        Integer highPriorityCount,
        Integer daysUntilRenewal
    ) {
        Decimal score = 0;

        // Adherence component (40% weight)
        // Target: 85%+, Service credit trigger: <80%
        if (adherenceScore < 75) {
            score += 40;
        } else if (adherenceScore < 80) {
            score += 30;
        } else if (adherenceScore < 85) {
            score += 15;
        }

        // Asset health component (30% weight)
        // Target: 85%+
        if (assetHealthScore < 70) {
            score += 30;
        } else if (assetHealthScore < 80) {
            score += 20;
        } else if (assetHealthScore < 85) {
            score += 10;
        }

        // Case impact component (20% weight)
        if (highPriorityCount >= 2) {
            score += 20;
        } else if (highPriorityCount >= 1) {
            score += 15;
        } else if (openCaseCount >= 3) {
            score += 10;
        } else if (openCaseCount >= 1) {
            score += 5;
        }

        // Time to renewal component (10% weight)
        if (daysUntilRenewal <= 30) {
            score += 10;
        } else if (daysUntilRenewal <= 60) {
            score += 7;
        } else if (daysUntilRenewal <= 90) {
            score += 3;
        }

        return score;
    }
}