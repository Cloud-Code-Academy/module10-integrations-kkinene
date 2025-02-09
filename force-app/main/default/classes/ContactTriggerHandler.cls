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

	public static void handleBeforeUpdate(List<Contact> newContacts){
        Set<String> idsToPost = new Set<String>();

        for(Contact tempCont : newContacts){
            //If DummyJSON_Id__c > 100 add to set of Id's
            if(tempCont.DummyJSON_Id__c != null && Integer.valueOf(tempCont.DummyJSON_Id__c)> 100){
                idsToPost.add(tempCont.DummyJSON_Id__c);
            }
        }

        //Perform API callout with ids
        if(!idsToPost.isEmpty()){
		    DummyJSONCallout.postCreateDummyJSONUser(idsToPost);
        }
	}
}