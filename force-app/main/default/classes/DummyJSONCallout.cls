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
     * @param dummyUserId The ID of the user in the external system to fetch data for.
     */
	@future
	public static void getDummyJSONUserFromId(Set<String> dummyUserIds) {
		//check for null or empty
		if(dummyUserIds == null || dummyUserIds.isEmpty()) {
            System.debug('No user IDs provided for callout.');
            return;
        }

		Http http = new Http();
        List<Contact> contactsToUpsert = new List<Contact>();
        
        for (String dummyUserId : dummyUserIds) {

			try {
				// Create HTTP request to send.
				HttpRequest request = new HttpRequest();

				// Set the endpoint URL. Use direct URL or for best practices use Named Credential.
				request.setEndpoint('callOut:DummyJSON_Cred/users/'+dummyUserId);  // Replace with your API endpoint

				// Set the HTTP method to GET.
				request.setMethod('GET');
				request.setHeader('Accept',	'application/json');

				// Send the HTTP request and get the response.
				HttpResponse response = http.send(request);

				//System.debug('Status Code: ' + response.getStatusCode());
				// If the HTTP response code is successful, parse the JSON response and update the contact.
				Contact cont = null;
				if(response.getStatusCode() == 200){				
					String jsonRespString = response.getBody();
					System.debug('Response Body: ' + jsonRespString);
					cont = createContactFromJson(jsonRespString);
				}

				if(cont != null ){
					contactsToUpsert.add(cont); //insert/update from the JSON response using the external id (dummyUserId)
				}else{
					System.debug('Callout failed status: ' + response.getStatusCode());
				}
			} catch (Exception e) {
					System.debug('Exception in HTTP Callout: ' + e.getMessage());
				}
		}	

		if(!contactsToUpsert.isEmpty()){
			upsert contactsToUpsert DummyJSON_Id__c;
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
     * @return Contact The Salesforce Contact object populated with details from the JSON string.
     */
	@TestVisible // Allows test class to see this method. Since it is private, it would not be visible otherwise.
	private static Contact createContactFromJson(String jsonResponse) {
		// Deserialize the JSON string into map of primitive data types.
		Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);

		//Access values needed to create the Contact
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
			lastName = 'Unknown';
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
     * Sends Contact information to an external system https://dummyjson.com/users/add ('DummyJsonUser') to create or update a user based on the provided Salesforce Contact ID.
     * The method prepares a JSON payload with the contact's information and sends it to the 'DummyJsonUser' add endpoint.
     * If the callout is successful (HTTP status code between 200 and 299), the method updates the contact's 'DummyJSON_Last_Updated__c' field in Salesforce to the current time.
	 * Salesforce Contact should be used to generate the JSON payload
	 * Fields: Id, FirstName, LastName, Email, Phone
	 * This callout method should work in triggers
	 * 
     * Documentation: https://dummyjson.com/docs/users
     * 
     * @param contactId The Salesforce Contact ID used to generate the JSON payload for the external system.
     */
	
	public static void postCreateDummyJSONUser(String contactId) {
		// Validate input contact Id
		if (String.isBlank(contactId)) {
			System.debug('Invalid contact ID provided.');
			return;
		}
		Http http = new Http();

		try{
			// Create HTTP request to send.
			HttpRequest request = new HttpRequest();

			// Set the endpoint URL. Use direct URL or for best practices use Named Credential.
			request.setEndpoint('callOut:DummyJSON_Cred'+'/users/add');  // Replace with your API endpoint

			// Set the HTTP method to POST.
			request.setMethod('POST');
			request.setHeader('Accept',	'application/json');

			// Query the contact record from Salesforce
			Contact tempCont = [SELECT Id, FirstName, LastName, Email, Phone, DummyJSON_Last_Updated__c
								FROM Contact 
								WHERE Id = :contactId 
								LIMIT 1];

			// Set the body using generateDummyJsonUserPayload method.
			String jsonPayload = generateDummyJsonUserPayload(tempCont.Id);
        	request.setBody(jsonPayload);


			// Send the HTTP request and get the response.
			HttpResponse response = http.send(request);

			// If the HTTP response code is successful, update the contact.
			if(response.getStatusCode() >= 200 && response.getStatusCode()<300){
				tempCont.DummyJSON_Last_Updated__c = System.now();
				update tempCont;
			} else{
				System.debug('Failed to update DummyJSON user. Status Code: ' + response.getStatusCode());
			}
		} catch(Exception e){
			System.debug('Exception in HTTP Callout: '+ e.getMessage());
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
     * @return String The JSON string payload that represents the Contact's details.
     */
	@TestVisible // Allows test class to see this method. Since it is private, it would not be visible otherwise.
	private static String generateDummyJsonUserPayload(String contactId) {

		//check for empty contactId
		if (String.isBlank(contactId)) {//Use of String.isBlank() also checks for null value isEmpty() ONLY checks empty
            throw new IllegalArgumentException('Contact ID cannot be null or empty');
        }
		// Query the contact to get the field values to generate the JSON payload.
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
		Map<String, Object> contactMap = new Map<String, Object>{
            'id' => tempCont.Id,
            'firstName' => tempCont.FirstName,
            'lastName' => tempCont.LastName,
            'email' => tempCont.Email,
            'phone' => tempCont.Phone
        };

		// Serialize the map into a JSON string.
		return JSON.serialize(contactMap);
		// Make sure to check that required contacts fields have a value. Default the value to unknown if it does not exists.
		// Integration data can change over time. It is a best practice to add safeguards/validation to ensure the integration does not break.	
	}
}