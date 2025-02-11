public class ContactTriggerHandler {
    // Static variable to prevent recursion
    public static Boolean isTriggerAlreadyExecuted = false;


	public static void handleBeforeInsert (List<Contact> newContacts){
        Set<String> idsToFetch = new Set<String>();

        for(Contact tempCont : newContacts){
		            
            // if DummyJSON_Id__c is null, generate a random number between 0 and 100 and set this as the contact's DummyJSON_Id__c value
            if(tempCont.DummyJSON_Id__c == null){
                // Generate a random number between 0 and 100
                Integer random0To100 = (Integer)Math.ceil(Math.random() * 100);
                tempCont.DummyJSON_Id__c = String.valueOf(random0To100);				
            } 
            
            if(Integer.valueOf(tempCont.DummyJSON_Id__c) <= 100){
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
        if (isTriggerAlreadyExecuted) {
            return; // Prevent recursion
        }
        isTriggerAlreadyExecuted = true; // Set the flag
    
        for (Integer i = 0; i < newContacts.size(); i++) {
            Contact newCont = newContacts[i];
    
            if (newCont.DummyJSON_Id__c != null && Integer.valueOf(newCont.DummyJSON_Id__c) > 100) {
                try {
                    DummyJSONCallout.postCreateDummyJSONUser(newCont.Id); // Pass the individual Contact ID
                } catch (Exception e) {
                    System.debug('Error in handleBeforeUpdate: ' + e.getMessage());
                    newCont.addError('Callout to DummyJSON failed. Please try again later.'); // Add error to the specific contact
                }
            }
        }
    
        isTriggerAlreadyExecuted = false; // Reset the flag
    }
}