public with sharing class QBRPrepCalculator {

    public class QBRSummary {
        public String accountName;
        public String salesAgreementName;
        public Date renewalDate;
        public Integer daysUntilRenewal;
        public Decimal riskScore;
        public String riskLevel;
        public Decimal adherenceScore;
        public String adherenceTrend;
        public Decimal assetHealthScore;
        public Integer openCaseCount;
        public Integer highPriorityCaseCount;
        public List<String> productAdherenceSummary = new List<String>();
        public List<String> openCaseSummary = new List<String>();
        public List<String> talkingPoints = new List<String>();
    }

    public static QBRSummary prepareQBR(Id accountId) {
        RenewalRiskScorer.RiskResult risk = RenewalRiskScorer.calculateRenewalRisk(accountId);

        SalesAgreement agreement = [
            SELECT Id
            FROM SalesAgreement
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        QBRSummary summary = new QBRSummary();
        summary.accountName = risk.accountName;
        summary.salesAgreementName = risk.salesAgreementName;
        summary.renewalDate = risk.renewalDate;
        summary.daysUntilRenewal = risk.daysUntilRenewal;
        summary.riskScore = risk.riskScore;
        summary.riskLevel = risk.riskLevel;
        summary.adherenceScore = risk.adherenceScore;

        Integer assetCount = [SELECT COUNT() FROM Asset WHERE AccountId = :accountId];
        // RenewalRiskScorer.assetHealthScore reports 0 when there's no Asset data at all,
        // which reads identically to "assets exist and are unhealthy" — track presence
        // separately so the talking points don't manufacture a false signal.
        summary.assetHealthScore = assetCount > 0 ? risk.assetHealthScore : null;

        for (AdherenceCalculator.AdherenceDetail detail : AdherenceCalculator.getAdherenceDetails(agreement.Id)) {
            summary.productAdherenceSummary.add(
                detail.productLine + ': ' + detail.adherenceScore + '% (' + detail.status + ')'
            );
        }

        summary.adherenceTrend = getAdherenceTrend(accountId);

        CaseImpactAnalyzer.CaseImpact caseImpact = CaseImpactAnalyzer.analyzeCases(accountId);
        summary.openCaseCount = caseImpact.openCaseCount;
        summary.highPriorityCaseCount = caseImpact.highPriorityCount;
        for (CaseImpactAnalyzer.CaseDetail c : caseImpact.cases) {
            summary.openCaseSummary.add(
                c.caseNumber + ': ' + c.subject + ' (' + c.priority + ', open ' + c.daysOpen + ' days)'
            );
        }

        summary.talkingPoints = buildTalkingPoints(summary);
        return summary;
    }

    private static String getAdherenceTrend(Id accountId) {
        List<QuarterlyAdherenceTrendCalculator.TrendResult> trends =
            QuarterlyAdherenceTrendCalculator.getRenewalsWithAdherenceTrend(
                Date.today().addYears(-1), Date.today().addYears(1)
            );

        for (QuarterlyAdherenceTrendCalculator.TrendResult trend : trends) {
            if (trend.accountId == accountId) {
                return trend.trend;
            }
        }
        return 'Insufficient Data';
    }

    private static List<String> buildTalkingPoints(QBRSummary summary) {
        List<String> points = new List<String>();

        if (summary.riskLevel == 'Critical' || summary.riskLevel == 'High') {
            points.add(
                'Renewal risk is ' + summary.riskLevel + ' (' + summary.riskScore +
                '/100) — lead with a mitigation plan before discussing renewal terms.'
            );
        }

        if (summary.adherenceTrend == 'Declining') {
            points.add(
                'Adherence trend is declining quarter-over-quarter — review demand/capacity ' +
                'changes with the customer and consider a revised schedule.'
            );
        }

        if (summary.adherenceScore != null && summary.adherenceScore < 80) {
            points.add(
                'Overall schedule adherence is ' + summary.adherenceScore.setScale(1) +
                '% (below the 80% target) — come with a corrective plan or proposed quantity adjustments.'
            );
        }

        if (summary.highPriorityCaseCount > 0) {
            points.add(
                summary.highPriorityCaseCount + ' open High-priority case(s) — get a status update ' +
                'or resolution plan before the QBR call.'
            );
        }

        if (summary.assetHealthScore != null && summary.assetHealthScore < 70) {
            points.add(
                'Average asset health is ' + summary.assetHealthScore.setScale(1) +
                '% — flag proactive maintenance or replacement as a discussion topic.'
            );
        }

        if (summary.daysUntilRenewal != null && summary.daysUntilRenewal <= 60) {
            points.add(
                'Renewal is in ' + summary.daysUntilRenewal +
                ' days — confirm terms, pricing, and quantities now so nothing is decided last-minute.'
            );
        }

        if (points.isEmpty()) {
            points.add('Account is healthy across adherence, cases, and asset health — use the QBR to explore growth or expansion opportunities.');
        }

        return points;
    }
}
