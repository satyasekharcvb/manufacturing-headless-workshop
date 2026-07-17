global with sharing class ScheduleUpdateAction {

    global class Request {
        @InvocableVariable(required=true label='Schedule Id') global Id scheduleId;
        @InvocableVariable(required=true label='New Planned Quantity') global Integer newPlannedQuantity;
    }

    global class Response {
        @InvocableVariable global Boolean success;
        @InvocableVariable global String message;
        @InvocableVariable global Integer previousProposedQuantity;
        @InvocableVariable global Integer updatedProposedQuantity;
    }

    @InvocableMethod(
        label='Apply Schedule Update'
        description='Propose an updated PlannedQuantity on a single SalesAgreementProductSchedule record'
    )
    global static List<Response> applyUpdate(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            responses.add(applySingleUpdate(req));
        }

        return responses;
    }

    private static Response applySingleUpdate(Request req) {
        Response resp = new Response();

        if (!Schema.SObjectType.SalesAgreementProductSchedule.fields.ProposedPlannedQuantity.isUpdateable()) {
            resp.success = false;
            resp.message = 'You do not have permission to update ProposedPlannedQuantity';
            return resp;
        }

        if (req.newPlannedQuantity == null || req.newPlannedQuantity < 0) {
            resp.success = false;
            resp.message = 'New planned quantity must be a non-negative number';
            return resp;
        }

        List<SalesAgreementProductSchedule> schedules = [
            SELECT Id, EndDate, ProposedPlannedQuantity
            FROM SalesAgreementProductSchedule
            WHERE Id = :req.scheduleId
            LIMIT 1
        ];

        if (schedules.isEmpty()) {
            resp.success = false;
            resp.message = 'Schedule record not found';
            return resp;
        }

        SalesAgreementProductSchedule schedule = schedules[0];

        if (schedule.EndDate < Date.today()) {
            resp.success = false;
            resp.message = 'Cannot update a schedule period that has already ended';
            return resp;
        }

        resp.previousProposedQuantity = schedule.ProposedPlannedQuantity;

        try {
            update new SalesAgreementProductSchedule(Id = schedule.Id, ProposedPlannedQuantity = req.newPlannedQuantity);
            resp.success = true;
            resp.message = 'Proposed planned quantity updated';
            resp.updatedProposedQuantity = req.newPlannedQuantity;
        } catch (DmlException e) {
            resp.success = false;
            resp.message = 'Update failed: ' + e.getMessage();
        }

        return resp;
    }
}
