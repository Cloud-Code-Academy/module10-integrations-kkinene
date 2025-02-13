public class ContactTriggerHandler {
    // Static variable to prevent recursion for handleBeforeUpdate across the entire trigger execution
    public static Boolean isHandleBeforeUpdateAlreadyExecuted = false; // More descriptive variable name

    public static void handleBeforeInsert (List<Contact> newContacts){
        Set<String> idsToFetch = new Set<String>();

        for(Contact tempCont : newContacts){

            // if DummyJSON_Id__c is null, generate a random number between 0 and 100 and set this as the contact's DummyJSON_Id__c value
            if(tempCont.DummyJSON_Id__c == null){
                // Generate a random number between 0 and 100
                Integer random0To100 = (Integer)Math.ceil(Math.random() * 100);
                tempCont.DummyJSON_Id__c = String.valueOf(random0To100);
            }

            Integer dummyIdValue = null; // Initialize outside try-catch
            String dummyIdString = tempCont.DummyJSON_Id__c; // Get the string value
            /*try {
                dummyIdValue = Integer.valueOf(tempCont.DummyJSON_Id__c); // Convert to Integer and handle potential errors
            } catch (System.NumberFormatException e) {
                System.debug('Error: Invalid DummyJSON_Id__c format for Contact ID: ' + tempCont.Id + '. Value: ' + tempCont.DummyJSON_Id__c);
                tempCont.addError('Invalid DummyJSON ID format. Please use a numeric value.');
                continue; // Skip to the next contact in the list
            }*/


            if(dummyIdValue != null && dummyIdValue <= 100){
               if (String.isNotBlank(dummyIdString) && dummyIdString.isNumeric()) { // **Proactive Validation**
            dummyIdValue = Integer.valueOf(dummyIdString); // Conversion is now safer
        } else {
            System.debug('Error: Invalid DummyJSON_Id__c format for Contact ID: ' + tempCont.Id + '. Value: ' + dummyIdString);
            tempCont.addError('Invalid DummyJSON ID format. Please use a numeric value.');
            continue; // Skip to the next contact
        }
 //When a contact is inserted
                // if DummyJSON_Id__c is less than or equal to 100, call the getDummyJSONUserFromId API
                idsToFetch.add(tempCont.DummyJSON_Id__c);
            }
        }

        //Bulkification complete and API Call can be made outside of the for loop
        if(!idsToFetch.isEmpty()){
            DummyJSONCallout.getDummyJSONUserFromId(idsToFetch);
        }
    }

    public static void handleBeforeUpdate(List<Contact> newContacts) {
        // **Correct Recursion Prevention:** Check the flag *at the very beginning* of the method
        if (isHandleBeforeUpdateAlreadyExecuted) {
            return; // Prevent recursion for handleBeforeUpdate logic
        }
        isHandleBeforeUpdateAlreadyExecuted = true; // Set the flag *before processing any records*

        List<Id> contactsToPostCreate = new List<Id>(); // Bulk collection of Contact IDs for postCreate call

        for (Contact newCont : newContacts) { // Use enhanced for loop for better readability

            Integer dummyIdValue = null; // Initialize outside try-catch
            String dummyIdString = newCont.DummyJSON_Id__c; // Get the string value
            /*try {
                dummyIdValue = Integer.valueOf(newCont.DummyJSON_Id__c); // Convert to Integer and handle potential errors
            } catch (System.NumberFormatException e) {
                System.debug('Error: Invalid DummyJSON_Id__c format for Contact ID: ' + newCont.Id + '. Value: ' + newCont.DummyJSON_Id__c);
                newCont.addError('Invalid DummyJSON ID format. Please use a numeric value.');
                continue; // Skip to the next contact
            }*/
            if (String.isNotBlank(dummyIdString) && dummyIdString.isNumeric()) { // **Proactive Validation**
                dummyIdValue = Integer.valueOf(dummyIdString); // Conversion is now safer
            } else {
                System.debug('Error: Invalid DummyJSON_Id__c format for Contact ID: ' + newCont.Id + '. Value: ' + dummyIdString);
                newCont.addError('Invalid DummyJSON ID format. Please use a numeric value.');
                continue; // Skip to the next contact
            }
    


            if (dummyIdValue != null && dummyIdValue > 100) {
                contactsToPostCreate.add(newCont.Id); // Collect Contact IDs for bulk callout
                /* **Removed direct callout inside the loop** - will be done in bulk later */
            }
        }

        // **Bulk Callout (Asynchronous - assuming DummyJSONCallout.postCreateDummyJSONUser is @future or Queueable)**
        if(!contactsToPostCreate.isEmpty()){
            try {
                DummyJSONCallout.postCreateDummyJSONUser(contactsToPostCreate); // Pass the list of Contact IDs for bulk processing
            } catch (Exception e) {
                System.debug('Error in handleBeforeUpdate (Bulk Callout): ' + e.getMessage());
                // **Important:** How to handle errors when a bulk asynchronous call fails?
                // Option 1 (Simpler): Log the error - you might need more robust error handling depending on requirements.
                // Option 2 (More Complex): Implement a retry mechanism or store error information for later processing.
                // For now, just logging.  Consider more robust error handling for production scenarios.
            }
        }


        isHandleBeforeUpdateAlreadyExecuted = false; // Reset the flag *after processing all records* in this trigger execution context
    }
}