global without sharing class AccountSearchAction {

    global class AccountSearchRequest {
        @InvocableVariable(required=true label='Account Name' description='The name of the account to search for')
        global String accountName;
    }

    global class AccountSearchResponse {
        @InvocableVariable(label='Account ID' description='The 18-character Account ID')
        global String accountId;

        @InvocableVariable(label='Account Name' description='The exact account name found')
        global String accountName;

        @InvocableVariable(label='Found' description='Whether the account was found')
        global Boolean found;

        @InvocableVariable(label='Error Message' description='Error message if account not found')
        global String errorMessage;
    }

    @InvocableMethod(
        label='Search Account by Name'
        description='Searches for an account by name and returns the Account ID'
        category='Manufacturing Cloud'
    )
    global static List<AccountSearchResponse> searchAccount(List<AccountSearchRequest> requests) {
        List<AccountSearchResponse> responses = new List<AccountSearchResponse>();

        for (AccountSearchRequest request : requests) {
            AccountSearchResponse response = new AccountSearchResponse();
            response.found = false;

            if (String.isBlank(request.accountName)) {
                response.errorMessage = 'Account name is required';
                responses.add(response);
                continue;
            }

            // Use SOSL search to find accounts (works with limited license users)
            String searchQuery = 'FIND {' + String.escapeSingleQuotes(request.accountName) + '} IN NAME FIELDS RETURNING Account(Id, Name LIMIT 1)';
            List<List<SObject>> searchResults = Search.query(searchQuery);

            List<Account> accounts = new List<Account>();
            if (!searchResults.isEmpty() && !searchResults[0].isEmpty()) {
                accounts = (List<Account>)searchResults[0];
            }

            if (!accounts.isEmpty()) {
                response.accountId = accounts[0].Id;
                response.accountName = accounts[0].Name;
                response.found = true;
            } else {
                response.errorMessage = 'No account found matching: ' + request.accountName;
            }

            responses.add(response);
        }

        return responses;
    }
}