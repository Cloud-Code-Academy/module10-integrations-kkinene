/*
 * DummyJSONCallout Class Description:
 * 
 * This class, DummyJSONCallout, facilitates HTTP callouts to an external system (presumably 'DummyJsonUser' in this context) 
 * to either fetch or send user information based on a given identifier. The class supports both GET (to fetch data) 
 * and POST (to send data) operations.
 * 
 * Overview of HTTP Callouts:
 * 
 * HTTP callouts are a way for Salesforce to communicate with external systems using HTTP protocols. Through HTTP callouts, 
 * you can invoke external web services, collect data from them, or send data for further processing. Apex provides 
 * classes that enable you to both send and receive HTTP data. The primary classes for this are `HttpRequest`, which 
 * represents the request you're sending, and `HttpResponse`, which represents the response you receive.
 * 
 * Best Practices:
 * 1. Handle Exceptions: Always handle exceptions that might be thrown, to ensure your code doesn't break unexpectedly.
 * 2. Named Credentials: Use Named Credentials to store endpoint URLs and authentication details securely.
 * 3. Test Callouts: Use mock classes and interfaces to test HTTP callouts without making actual callouts.
 * 
 * For more detailed information on HTTP callouts in Apex, refer to the official Salesforce documentation: 
 * https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httprequest.htm
 */
public with sharing class DummyJSONCallout {

    /*
     * Question 1
     * Fetches user information from an external system https://dummyjson.com/user/{id} ('DummyJsonUser') based on the provided dummy user ID.
     * If the callout is successful and returns an HTTP status of 200, the method will update a contact based on the DummyJSON_Id__c with the data returned from the external system.
     * Use the createContactFromJson method to parse the JSON response and create a Salesforce Contact object.
     * Documentation: https://dummyjson.com/docs/users
     * This callout method should work in triggers
     *
     * @param dummyUserIds The Set of DummyJSON_Id__c values for users in the external system to fetch data for.
     */
    @future(callout=true)
    public static void getDummyJSONUserFromId(Set<String> dummyUserIds) {
        //check for null or empty
        if(dummyUserIds == null || dummyUserIds.isEmpty()) {
            System.debug('No user IDs provided for getDummyJSONUserFromId callout.');
            return;
        }

        Http http = new Http();
        List<Contact> contactsToUpsert = new List<Contact>();

        for (String dummyUserId : dummyUserIds) { // Iterate through the provided set of IDs

            try {
                // Create HTTP request to send.
                HttpRequest request = new HttpRequest();

                // Set the endpoint URL. Use direct URL or for best practices use Named Credential.
                request.setEndpoint('callOut:DummyJSON_Cred/users/'+dummyUserId);  // Replace with your API endpoint

                // Set the HTTP method to GET.
                request.setMethod('GET');
                request.setHeader('Accept', 'application/json');

                // Send the HTTP request and get the response.
                HttpResponse response = http.send(request);

                Contact cont = null;
                if(response.getStatusCode() == 200){
                    String jsonRespString = response.getBody();
                    System.debug('Response Body (getDummyJSONUserFromId for ID ' + dummyUserId + '): ' + jsonRespString);
                    cont = createContactFromJson(jsonRespString);
                    if(cont != null) {
                        // **Important**: Set DummyJSON_Id__c as the External ID for Upsert.
                        // Assuming DummyJSON_Id__c is the field to match on for upsert.
                        cont.DummyJSON_Id__c = dummyUserId; // Ensure External ID is set for upsert to work correctly.
                    }
                } else {
                    System.debug('getDummyJSONUserFromId Callout failed for ID ' + dummyUserId + '. Status Code: ' + response.getStatusCode() + '. Response Body: ' + response.getBody());
                }

                if(cont != null ){
                    contactsToUpsert.add(cont); // Collect contacts for bulk upsert
				}else{
					System.debug('Callout failed status: ' + response.getStatusCode());
                }

            } catch (Exception e) {
                System.debug('Exception in getDummyJSONUserFromId HTTP Callout for ID ' + dummyUserId + ': ' + e.getMessage());
            }
        }

        if(!contactsToUpsert.isEmpty()){
            try {
                upsert contactsToUpsert DummyJSON_Id__c; // **Bulk UPSERT using External ID** - very important for efficiency
            } catch (Exception upsertException) {
                System.debug('Exception during bulk upsert in getDummyJSONUserFromId: ' + upsertException.getMessage());
                // Handle upsert errors - consider more robust error logging/handling if needed.
            }
        }
    }


    /*
     * Question 2
     * Transforms a JSON response from the external system https://dummyjson.com/users into a Salesforce Contact object.
     * The method parses the JSON string to extract user details and map them to a Salesforce Contact object.
     * The contact fields populated from the JSON include Email, Phone, Birthdate, and various address-related fields.
     * The method is primarily designed to work in conjunction with callouts that fetch user details from the external system. 
	 * 
	 * Fields from JSON used to populate Salesforce Contact
	 * Fields: Email, Phone, Birthdate, MailingStreet, MailingCity, MailingPostalCode, MailingState, MailingCountry
	 * 
     * Documentation: https://dummyjson.com/docs/users
     * 
     * @param String jsonResponse The JSON string from the external system that contains user details.
     * @return Contact The Salesforce Contact object populated with details from the JSON string.     */
    @TestVisible
    private static Contact createContactFromJson(String jsonResponse) {
        // Deserialize the JSON string into map of primitive data types.
        Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);

        String firstName = (String) dataMap.get('firstName'); 
		String lastName = (String) dataMap.get('lastName'); 
		String email = (String) dataMap.get('email');
		String phone = (String) dataMap.get('phone'); 
		String birthDate = (String) dataMap.get('birthDate');        
        // Create a new contact from the JSON response.
		Contact newContact = new Contact();

		// Set the contact fields from the JSON response.
		newContact.FirstName = firstName;
		newContact.LastName = lastName;
		if(String.isBlank(lastName)){
			newContact.lastName = 'Unknown';
		}
		newContact.Email = email;
		newContact.Phone = phone;
		if (birthDate != null) {
			newContact.Birthdate = Date.valueOf(birthDate);
		}

		// Deserialize the address from the JSON response.
		//Accessing Mailing Address fields Is not as straight forward because it is a nested Object
		//"address":{"address":"1538 Eighth Street","city":"San Jose","state":"Missouri","stateCode":"MO","postalCode":"29673","coordinates":{"lat":24.169361,"lng":-29.395167},"country":"United States"}}
		if(dataMap.get('address')!= null){
			Map<String, Object> address = (Map<String, Object>) dataMap.get('address');

			String mailingStreet = (String) address.get('address'); // "31 Maple Street"
			String mailingCity = (String) address.get('city'); // "San Jose"
			String mailingPostalCode = (String) address.get('postalCode'); // "78243"
			String mailingState = (String) address.get('state'); // "Utah"
			String mailingCountry = (String) address.get('country'); // "United States"

			// Set the address fields on the contact.
			newContact.MailingStreet = mailingStreet;
			newContact.MailingCity = mailingCity;
			newContact.MailingPostalCode = mailingPostalCode;
			newContact.MailingState = mailingState;
			newContact.MailingCountry = mailingCountry;
		}
        return newContact;
    }


    /*
     * Question 3
     * Sends Contact information to an external system https://dummyjson.com/users/add ('DummyJsonUser') to create or update a user based on the provided Salesforce Contact IDs (Bulkified).
     * The method prepares a JSON payload with the contact's information and sends it to the 'DummyJsonUser' add endpoint.
     * If the callout is successful (HTTP status code between 200 and 299), the method updates the contact's 'DummyJSON_Last_Updated__c' field in Salesforce to the current time.
     * Salesforce Contact should be used to generate the JSON payload
     * Fields: Id, FirstName, LastName, Email, Phone
     * This callout method should work in triggers
     *
     * Documentation: https://dummyjson.com/docs/users
     *
     * @param contactIds List<Id> - The list of Salesforce Contact IDs to process and send to DummyJSON.
     */
    @future(callout=true) // **Made Asynchronous with @future**
    public static void postCreateDummyJSONUser(List<Id> contactIds) { // **Accepts List<Id> for Bulk Processing**
        // Validate input contact Ids
        if (contactIds == null || contactIds.isEmpty()) { // Changed to check for null or empty List
            System.debug('No contact IDs provided for postCreateDummyJSONUser callout.');
            return;
        }
        Http http = new Http();
        List<Contact> contactsToUpdate = new List<Contact>(); // To bulk update contacts after successful callouts

        List<Contact> contactsToProcess = [SELECT Id, FirstName, LastName, Email, Phone, DummyJSON_Last_Updated__c // **Bulk SOQL Query**
                                            FROM Contact
                                            WHERE Id IN :contactIds];


        for(Contact tempCont : contactsToProcess) { // Iterate through fetched contacts (already in bulk)
            try{
                // Create HTTP request to send.
                HttpRequest request = new HttpRequest();

                // Set the endpoint URL. Use direct URL or for best practices use Named Credential.
                request.setEndpoint('callOut:DummyJSON_Cred'+'/users/add');  // Replace with your API endpoint

                // Set the HTTP method to POST.
                request.setMethod('POST');
                request.setHeader('Accept', 'application/json');

                // Set the body using generateDummyJsonUserPayload method.
                String jsonPayload = generateDummyJsonUserPayload(tempCont.Id); // Generate payload for *each* contact
                request.setBody(jsonPayload);

                // Send the HTTP request and get the response.
                HttpResponse response = http.send(request);

                // If the HTTP response code is successful (2xx range), update the contact.
                if(response.getStatusCode() >= 200 && response.getStatusCode()<300){
                    tempCont.DummyJSON_Last_Updated__c = System.now();
                    contactsToUpdate.add(tempCont); // Collect contacts for bulk update
                    System.debug('Successfully sent Contact ID: ' + tempCont.Id + ' to DummyJSON. Status Code: ' + response.getStatusCode());
                } else{
                    System.debug('Failed to update DummyJSON user for Contact ID: ' + tempCont.Id + '. Status Code: ' + response.getStatusCode() + '. Response Body: ' + response.getBody());
                    // **Consider adding error handling here - e.g., setting an error flag on the Contact or logging to a custom object for retry**
                }
            } catch(Exception e){
                System.debug('Exception in postCreateDummyJSONUser HTTP Callout for Contact ID: ' + tempCont.Id + ': '+ e.getMessage());
                // **Consider adding more robust error handling here as well**
            }
        } // End of Contact loop

        if(!contactsToUpdate.isEmpty()){
            try {
                update contactsToUpdate; // **Bulk DML update outside the loop**
            } catch (Exception dmlException) {
                System.debug('Exception during bulk Contact update in postCreateDummyJSONUser: ' + dmlException.getMessage());
                // Handle DML update errors.
            }
        }
    }


    /*
     * Question 4
     * Generates a JSON payload based on a Salesforce Contact's fields to be sent to an external system https://dummyjson.com/users/add for user creation or update.
     * The method queries a contact from Salesforce based on the provided contactId and maps its fields into a JSON payload.
     * The fields from Salesforce Contact that are transformed into the JSON payload include Id, FirstName, LastName, Email, and Phone.
     * The generated JSON payload can be sent to the external system for various operations like creating or updating a user.
	 * 
	 * Fields from Salesforce Contact used to generate JSON payload:
	 * Fields: Id => salesforceId, FirstName => firstName, LastName => lastName, Email => email, Phone => phone
	 * 
     * Documentation: https://dummyjson.com/docs/users
     * 
     * @param String contactId The Salesforce Contact ID used to fetch the contact's fields and generate the JSON payload.
     * @return String The JSON string payload that represents the Contact's details.     */
    @TestVisible
    private static String generateDummyJsonUserPayload(String contactId) {
       //check for empty contactId
		if (String.isBlank(contactId)) {//Use of String.isBlank() also checks for null value isEmpty() ONLY checks empty
            throw new IllegalArgumentException('Contact ID cannot be null or empty');
        }        // Query the contact to get the field values to generate the JSON payload.
        Contact tempCont = [SELECT Id, FirstName, LastName, Email, Phone
                            FROM Contact
                            WHERE Id = :contactId
                            LIMIT 1];
							if(String.isBlank(tempCont.LastName) ){
								tempCont.LastName='Unknown';
							}
							if(String.isBlank(tempCont.FirstName)){
								tempCont.FirstName='Unknown';
							}
							if(String.isBlank(tempCont.Email)){
								tempCont.Email='Unknown';
							}
							if(String.isBlank(tempCont.Phone)){
								tempCont.Phone='Unknown';
							}
							// Create a map of the contact field values.
							Map<String, Object> contactMap = new Map<String, Object>{'salesforceId' => String.valueOf(tempCont.Id),
								'firstName' => tempCont.FirstName,
								'lastName' => tempCont.LastName,
								'email' => tempCont.Email,
								'phone' => tempCont.Phone
							};        return JSON.serialize(contactMap);
    }
}