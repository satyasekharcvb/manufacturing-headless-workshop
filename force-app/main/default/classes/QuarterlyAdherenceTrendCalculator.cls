public with sharing class QuarterlyAdherenceTrendCalculator {

    public class TrendResult {
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public Id salesAgreementId { get; set; }
        @AuraEnabled public String salesAgreementName { get; set; }
        @AuraEnabled public Date renewalDate { get; set; }
        @AuraEnabled public Decimal currentPeriodAdherence { get; set; }
        @AuraEnabled public Decimal previousPeriodAdherence { get; set; }
        @AuraEnabled public String trend { get; set; }
    }

    private class PeriodTotals {
        Decimal plannedQty = 0;
        Decimal actualQty = 0;
        Date periodEndDate;
    }

    public static List<TrendResult> getRenewalsWithAdherenceTrend(Date renewalWindowStart, Date renewalWindowEnd) {
        List<TrendResult> results = new List<TrendResult>();

        List<SalesAgreement> agreements = [
            SELECT Id, Name, AccountId, Account.Name, EndDate
            FROM SalesAgreement
            WHERE EndDate >= :renewalWindowStart
            AND EndDate <= :renewalWindowEnd
            AND Status = 'Activated'
        ];

        if (agreements.isEmpty()) {
            return results;
        }

        Set<Id> agreementIds = new Map<Id, SalesAgreement>(agreements).keySet();

        List<SalesAgreementProductSchedule> schedules = [
            SELECT SalesAgreementProduct.SalesAgreementId, StartDate, EndDate, PlannedQuantity, ActualQuantity
            FROM SalesAgreementProductSchedule
            WHERE SalesAgreementProduct.SalesAgreementId IN :agreementIds
            ORDER BY StartDate ASC
        ];

        Map<Id, Map<Date, PeriodTotals>> periodsByAgreement = new Map<Id, Map<Date, PeriodTotals>>();
        for (SalesAgreementProductSchedule sched : schedules) {
            Id agreementId = sched.SalesAgreementProduct.SalesAgreementId;
            Map<Date, PeriodTotals> periodMap = periodsByAgreement.get(agreementId);
            if (periodMap == null) {
                periodMap = new Map<Date, PeriodTotals>();
                periodsByAgreement.put(agreementId, periodMap);
            }

            PeriodTotals totals = periodMap.get(sched.StartDate);
            if (totals == null) {
                totals = new PeriodTotals();
                totals.periodEndDate = sched.EndDate;
                periodMap.put(sched.StartDate, totals);
            }

            totals.plannedQty += (sched.PlannedQuantity == null ? 0 : sched.PlannedQuantity);
            totals.actualQty += (sched.ActualQuantity == null ? 0 : sched.ActualQuantity);
        }

        for (SalesAgreement sa : agreements) {
            TrendResult result = new TrendResult();
            result.accountId = sa.AccountId;
            result.accountName = sa.Account.Name;
            result.salesAgreementId = sa.Id;
            result.salesAgreementName = sa.Name;
            result.renewalDate = sa.EndDate;

            Map<Date, PeriodTotals> periodMap = periodsByAgreement.get(sa.Id);
            List<Date> completedPeriodStarts = new List<Date>();
            if (periodMap != null) {
                for (Date periodStart : periodMap.keySet()) {
                    PeriodTotals totals = periodMap.get(periodStart);
                    if (totals.plannedQty > 0 && totals.periodEndDate < Date.today()) {
                        completedPeriodStarts.add(periodStart);
                    }
                }
                completedPeriodStarts.sort();
            }

            if (completedPeriodStarts.size() < 2) {
                result.trend = 'Insufficient Data';
                results.add(result);
                continue;
            }

            Date currentPeriodStart = completedPeriodStarts[completedPeriodStarts.size() - 1];
            Date previousPeriodStart = completedPeriodStarts[completedPeriodStarts.size() - 2];
            PeriodTotals currentTotals = periodMap.get(currentPeriodStart);
            PeriodTotals previousTotals = periodMap.get(previousPeriodStart);

            result.currentPeriodAdherence = (currentTotals.actualQty / currentTotals.plannedQty * 100).setScale(1);
            result.previousPeriodAdherence = (previousTotals.actualQty / previousTotals.plannedQty * 100).setScale(1);

            if (result.currentPeriodAdherence < result.previousPeriodAdherence) {
                result.trend = 'Declining';
            } else if (result.currentPeriodAdherence > result.previousPeriodAdherence) {
                result.trend = 'Improving';
            } else {
                result.trend = 'Stable';
            }

            results.add(result);
        }

        return results;
    }
}