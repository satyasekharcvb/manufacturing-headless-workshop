public with sharing class WorkshopDataSetup {

    private static final List<String> PRODUCT_NAMES = new List<String>{
        'Turbine Blade Assembly', 'Gasket Seal Kit', 'Heavy-Duty Bearing Kit'
    };

    private static final Map<String, Integer> PLANNED_QTY_BY_PRODUCT = new Map<String, Integer>{
        'Turbine Blade Assembly' => 13,
        'Gasket Seal Kit' => 25,
        'Heavy-Duty Bearing Kit' => 19
    };

    // Applied to each period's own PlannedQuantity (the platform splits InitialPlannedQuantity
    // evenly across periods, so it isn't known until after activation) to derive ActualQuantity.
    // A declining trend across periods gives the risk scorer a real signal to act on.
    private static final Map<String, List<Decimal>> ADHERENCE_RATIO_HISTORY_BY_PRODUCT = new Map<String, List<Decimal>>{
        'Turbine Blade Assembly' => new List<Decimal>{ 0.95, 0.80, 0.62 },
        'Gasket Seal Kit' => new List<Decimal>{ 0.97, 0.85, 0.68 },
        'Heavy-Duty Bearing Kit' => new List<Decimal>{ 0.93, 0.78, 0.58 }
    };

    private static final Map<String, Decimal> ASSET_HEALTH_BY_PRODUCT = new Map<String, Decimal>{
        'Turbine Blade Assembly' => 58,
        'Gasket Seal Kit' => 60,
        'Heavy-Duty Bearing Kit' => 58
    };

    private static final Map<String, Decimal> UNIT_PRICE_BY_PRODUCT = new Map<String, Decimal>{
        'Turbine Blade Assembly' => 1200,
        'Gasket Seal Kit' => 150,
        'Heavy-Duty Bearing Kit' => 450
    };

    private static final String DEMO_ACCOUNT_NAME = 'Skyline Aviation';

    // No-arg convenience: resolves the fixed demo account by name so callers don't have to
    // look up the Id per org. Use this after importing the data tree.
    public static void setupSkylineDemo() {
        List<Account> accounts = [
            SELECT Id FROM Account WHERE Name = :DEMO_ACCOUNT_NAME
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (accounts.isEmpty()) {
            throw new SetupException(
                'No Account named "' + DEMO_ACCOUNT_NAME + '" found. Import the data tree first.'
            );
        }
        setupSkylineDemo(accounts[0].Id);
    }

    public class SetupException extends Exception {}

    public static void setupSkylineDemo(Id accountId) {
        SalesAgreement agreement = getOrCreateDraftAgreement(accountId);

        if (agreement.Status == 'Draft') {
            insertProductLines(agreement.Id);
            // Activating in the same transaction as the SalesAgreementProduct insert fails with
            // "Save other edits before changing the status." — Manufacturing Cloud's platform
            // automation requires the product-line insert to have fully committed first.
            // Queueable defers activation (and everything after it) to a fresh transaction.
            System.enqueueJob(new AgreementActivationJob(agreement.Id, accountId));
            return;
        }

        finishSetup(agreement.Id, accountId);
    }

    private static void finishSetup(Id agreementId, Id accountId) {
        backfillActualQuantities(agreementId);
        computeAdherenceScores(agreementId);
        AdherenceCalculator.updateScheduleAdherence(agreementId);
        createAssetsWithHealthScores(accountId);
    }

    public class AgreementActivationJob implements Queueable {
        private Id agreementId;
        private Id accountId;

        public AgreementActivationJob(Id agreementId, Id accountId) {
            this.agreementId = agreementId;
            this.accountId = accountId;
        }

        public void execute(QueueableContext context) {
            update new SalesAgreement(Id = agreementId, Status = 'Approved');
            finishSetup(agreementId, accountId);
        }
    }

    private static SalesAgreement getOrCreateDraftAgreement(Id accountId) {
        List<SalesAgreement> existing = [
            SELECT Id, Status
            FROM SalesAgreement
            WHERE AccountId = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return existing[0];
        }

        Pricebook2 standardPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];

        SalesAgreement agreement = new SalesAgreement(
            Name = 'SA-WORKSHOP-DEMO',
            AccountId = accountId,
            PricebookId = standardPricebook.Id,
            AgreementType = 'Volume',
            ProductLevel = 'Product',
            Status = 'Draft',
            StartDate = Date.today().addMonths(-9),
            EndDate = Date.today().addMonths(3),
            ScheduleFrequency = 'Quarterly',
            ScheduleCount = 4
        );
        insert agreement;
        return agreement;
    }

    private static void insertProductLines(Id agreementId) {
        ensureProductsAndPricebookEntries();

        Map<String, Id> pricebookEntryIdByProductName = new Map<String, Id>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2.Name
            FROM PricebookEntry
            WHERE Product2.Name IN :PRODUCT_NAMES
            AND Pricebook2.IsStandard = true
        ]) {
            pricebookEntryIdByProductName.put(pbe.Product2.Name, pbe.Id);
        }

        List<SalesAgreementProduct> lines = new List<SalesAgreementProduct>();
        for (String productName : PRODUCT_NAMES) {
            if (!pricebookEntryIdByProductName.containsKey(productName)) {
                continue;
            }

            lines.add(new SalesAgreementProduct(
                Name = productName,
                SalesAgreementId = agreementId,
                PricebookEntryId = pricebookEntryIdByProductName.get(productName),
                InitialPlannedQuantity = PLANNED_QTY_BY_PRODUCT.get(productName)
            ));
        }
        insert lines;
    }

    // A fresh org has the demo Products but no Standard PricebookEntries for them (or no
    // Products at all). Without a Standard PricebookEntry, the SalesAgreementProduct insert
    // above finds nothing and the agreement is left empty. Create whatever's missing so the
    // rest of setup can proceed in any org.
    private static void ensureProductsAndPricebookEntries() {
        Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;

        Map<String, Id> productIdByName = new Map<String, Id>();
        for (Product2 p : [SELECT Id, Name FROM Product2 WHERE Name IN :PRODUCT_NAMES]) {
            productIdByName.put(p.Name, p.Id);
        }

        List<Product2> productsToInsert = new List<Product2>();
        for (String productName : PRODUCT_NAMES) {
            if (!productIdByName.containsKey(productName)) {
                productsToInsert.add(new Product2(Name = productName, IsActive = true));
            }
        }
        if (!productsToInsert.isEmpty()) {
            insert productsToInsert;
            for (Product2 p : productsToInsert) {
                productIdByName.put(p.Name, p.Id);
            }
        }

        Set<Id> productIdsWithStandardEntry = new Set<Id>();
        for (PricebookEntry pbe : [
            SELECT Product2Id FROM PricebookEntry
            WHERE Product2.Name IN :PRODUCT_NAMES AND Pricebook2.IsStandard = true
        ]) {
            productIdsWithStandardEntry.add(pbe.Product2Id);
        }

        List<PricebookEntry> entriesToInsert = new List<PricebookEntry>();
        for (String productName : PRODUCT_NAMES) {
            Id productId = productIdByName.get(productName);
            if (productId != null && !productIdsWithStandardEntry.contains(productId)) {
                entriesToInsert.add(new PricebookEntry(
                    Pricebook2Id = standardPricebookId,
                    Product2Id = productId,
                    UnitPrice = UNIT_PRICE_BY_PRODUCT.get(productName),
                    IsActive = true
                ));
            }
        }
        if (!entriesToInsert.isEmpty()) {
            insert entriesToInsert;
        }
    }

    private static void backfillActualQuantities(Id agreementId) {
        Map<Id, String> productNameById = new Map<Id, String>();
        for (SalesAgreementProduct sap : [
            SELECT Id, Name
            FROM SalesAgreementProduct
            WHERE SalesAgreementId = :agreementId
        ]) {
            productNameById.put(sap.Id, sap.Name);
        }

        List<SalesAgreementProductSchedule> schedules = [
            SELECT Id, StartDate, PlannedQuantity, SalesAgreementProductId
            FROM SalesAgreementProductSchedule
            WHERE SalesAgreementProductId IN :productNameById.keySet()
            ORDER BY SalesAgreementProductId, StartDate
        ];

        Map<Id, List<SalesAgreementProductSchedule>> schedulesByProduct = new Map<Id, List<SalesAgreementProductSchedule>>();
        for (SalesAgreementProductSchedule sched : schedules) {
            if (!schedulesByProduct.containsKey(sched.SalesAgreementProductId)) {
                schedulesByProduct.put(sched.SalesAgreementProductId, new List<SalesAgreementProductSchedule>());
            }
            schedulesByProduct.get(sched.SalesAgreementProductId).add(sched);
        }

        List<SalesAgreementProductSchedule> updates = new List<SalesAgreementProductSchedule>();
        for (Id productId : schedulesByProduct.keySet()) {
            String productName = productNameById.get(productId);
            List<Decimal> ratios = ADHERENCE_RATIO_HISTORY_BY_PRODUCT.get(productName);
            if (ratios == null) {
                continue;
            }

            List<SalesAgreementProductSchedule> productSchedules = schedulesByProduct.get(productId);
            for (Integer i = 0; i < ratios.size() && i < productSchedules.size(); i++) {
                Decimal planned = productSchedules[i].PlannedQuantity;
                if (planned == null) {
                    continue;
                }
                updates.add(new SalesAgreementProductSchedule(
                    Id = productSchedules[i].Id,
                    ActualQuantity = Integer.valueOf((planned * ratios[i]).setScale(0, System.RoundingMode.HALF_UP))
                ));
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static void computeAdherenceScores(Id agreementId) {
        List<AggregateResult> totals = [
            SELECT SalesAgreementProductId sapId,
                   SUM(PlannedQuantity) plannedTotal,
                   SUM(ActualQuantity) actualTotal
            FROM SalesAgreementProductSchedule
            WHERE SalesAgreementProductId IN (
                SELECT Id FROM SalesAgreementProduct WHERE SalesAgreementId = :agreementId
            )
            AND ActualQuantity != null
            GROUP BY SalesAgreementProductId
        ];

        List<SalesAgreementProduct> updates = new List<SalesAgreementProduct>();
        for (AggregateResult result : totals) {
            Decimal plannedTotal = (Decimal) result.get('plannedTotal');
            Decimal actualTotal = (Decimal) result.get('actualTotal');

            if (plannedTotal == null || plannedTotal == 0) {
                continue;
            }

            Decimal adherence = (actualTotal / plannedTotal * 100).setScale(1);
            updates.add(new SalesAgreementProduct(
                Id = (Id) result.get('sapId'),
                AdherenceScore__c = adherence
            ));
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static void createAssetsWithHealthScores(Id accountId) {
        List<Asset> existingAssets = [SELECT Id FROM Asset WHERE AccountId = :accountId];
        if (!existingAssets.isEmpty()) {
            return;
        }

        List<Asset> assets = new List<Asset>();
        for (String productName : PRODUCT_NAMES) {
            assets.add(new Asset(
                Name = productName + ' Unit',
                AccountId = accountId,
                health_score__c = ASSET_HEALTH_BY_PRODUCT.get(productName),
                hub_location__c = 'Hong Kong',
                maintenance_priority__c = 'Medium',
                InstallDate = Date.today().addMonths(-9),
                Status = 'Shipped'
            ));
        }
        insert assets;
    }
}
