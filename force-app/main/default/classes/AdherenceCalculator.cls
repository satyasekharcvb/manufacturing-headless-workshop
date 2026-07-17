public with sharing class AdherenceCalculator {

    public class AdherenceDetail {
        @AuraEnabled public String productLine { get; set; }
        @AuraEnabled public Decimal adherenceScore { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean isBelowThreshold { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static Decimal getAverageAdherence(Id salesAgreementId) {
        AggregateResult[] results = [
            SELECT AVG(AdherenceScore__c) avgAdherence
            FROM SalesAgreementProduct
            WHERE SalesAgreementId = :salesAgreementId
            AND AdherenceScore__c != null
        ];

        if (!results.isEmpty() && results[0].get('avgAdherence') != null) {
            return (Decimal)results[0].get('avgAdherence');
        }

        return 0;
    }

    @AuraEnabled(cacheable=true)
    public static List<AdherenceDetail> getAdherenceDetails(Id salesAgreementId) {
        List<AdherenceDetail> details = new List<AdherenceDetail>();

        List<SalesAgreementProduct> products = [
            SELECT Name, PricebookEntry.Product2.Name, AdherenceScore__c
            FROM SalesAgreementProduct
            WHERE SalesAgreementId = :salesAgreementId
            AND AdherenceScore__c != null
            ORDER BY AdherenceScore__c ASC
        ];

        for (SalesAgreementProduct sap : products) {
            AdherenceDetail detail = new AdherenceDetail();
            detail.productLine = sap.Name;
            detail.adherenceScore = sap.AdherenceScore__c;
            detail.isBelowThreshold = sap.AdherenceScore__c < 80;

            if (sap.AdherenceScore__c >= 85) {
                detail.status = 'Excellent';
            } else if (sap.AdherenceScore__c >= 80) {
                detail.status = 'Acceptable';
            } else if (sap.AdherenceScore__c >= 75) {
                detail.status = 'Warning';
            } else {
                detail.status = 'Critical';
            }

            details.add(detail);
        }

        return details;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAdherenceSummary(Id salesAgreementId) {
        Map<String, Object> summary = new Map<String, Object>();

        Decimal avgAdherence = getAverageAdherence(salesAgreementId);
        List<AdherenceDetail> details = getAdherenceDetails(salesAgreementId);

        Integer belowThresholdCount = 0;
        for (AdherenceDetail d : details) {
            if (d.isBelowThreshold) {
                belowThresholdCount++;
            }
        }

        summary.put('averageAdherence', avgAdherence);
        summary.put('totalProductLines', details.size());
        summary.put('belowThresholdCount', belowThresholdCount);
        summary.put('thresholdPercentage', 80);
        summary.put('targetPercentage', 85);
        summary.put('details', details);

        return summary;
    }

    public static Decimal updateScheduleAdherence(Id salesAgreementId) {
        Decimal avgAdherence = getAverageAdherence(salesAgreementId);

        update new SalesAgreement(
            Id = salesAgreementId,
            SchedAdherenceScore__c = avgAdherence
        );

        return avgAdherence;
    }
}