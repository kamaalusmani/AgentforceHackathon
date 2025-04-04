global class MyEmailHandler implements Messaging.InboundEmailHandler {
   global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
   
           // Extract email details
            String subject = email.subject;
            String body = email.plainTextBody;
            String senderEmail = envelope.fromAddress;
            
            // Get the email received date
            Date receivedDate = System.today();  // Capture today's date
        
        // Initialize the result object
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        
        // Query to find the account by email
        List<Account> accounts= [SELECT Id, Email__c FROM Account WHERE Email__c = :email.fromAddress LIMIT 1];
        Account account;
        
        // If a contact is account , use it; otherwise, create a new account 
        if (!accounts.isEmpty()) {
            account= accounts[0];
        } else {
            // Create a new account if none is found
            account= new Account(
                Name = 'Email Query '+email.fromAddress,  // Customize as needed
                Email__c = email.fromAddress
            );
            insert account;
        }

        // Create a new Opportunity and link it with the found or newly created Account
        Opportunity newOpp= new Opportunity (
            Name = 'New Opportunity from Email: ' + senderEmail ,
            Description = body, // You can customize this to use the email body as the description
            CloseDate=receivedDate + 15,
            StageName='Proposal/Price Quote',
            AccountId= account.Id
        );
        insert newOpp;

        // Create an EmailMessage record and link it to the newly created Opportunity
        // Use the first recipient in the toAddresses list (if it's a single recipient)
        String recipient = (email.toAddresses != null && email.toAddresses.size() > 0) ? email.toAddresses[0] : '';
        
        /*EmailMessage emailMessage = new EmailMessage(
            Subject = email.subject,
            ToAddress = recipient,
            FromAddress = email.fromAddress,
            TextBody = email.plainTextBody,
            ParentId = newOpp.Id // This links the EmailMessage to the newly created Case
        );
        insert emailMessage;*/

                String getProductInfoJSON=extractProducts(email.plainTextBody);
                Boolean isOLICreated=OpportunityLineItemCreator.createOpportunityLineItems(getProductInfoJSON,newOpp.id);
            
       if (isOLICreated) {
                
            // Step 1: Send the generated response as an email
            Messaging.SingleEmailMessage emailMessage2 = new Messaging.SingleEmailMessage();
            emailMessage2.setToAddresses(new String[] { account.Email__c }); // Recipient's email address
            emailMessage2.setSubject('Query Received : Do Not Reply');
            emailMessage2.setPlainTextBody('Dear Customer,\nThanks for Your Query\nWe will connect with you with the requested information soon');
            
            // Step 2: Send the email
                   Messaging.SendEmailResult[] emailResults = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { emailMessage2 });
        
                if (emailResults != null && emailResults[0].isSuccess()) {
                } else {
                    System.debug('Failed to send reply. Error: ' + emailResults[0].getErrors()[0].getMessage());
                }
       }
        

            // Success: Set the result as processed
            result.success = true;
            return result;
    }

   public static String extractProducts(String Body) {
        
        ConnectApi.EinsteinPromptTemplateGenerationsInput promptGenerationsInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        Map<String, ConnectApi.WrappedValue> valueMap = new Map<String, ConnectApi.WrappedValue>();
        Map<String, Object> EmailText = new Map<String, Object>();
        EmailText.put('Body', Body); // Use the key expected by your template

        // Serialize the map to JSON
        ConnectApi.WrappedValue contactWrappedValue = new ConnectApi.WrappedValue();
        contactWrappedValue.value = JSON.serialize(EmailText);

      // Add to inputParams with correct key
       valueMap.put('Input:userInstructions', contactWrappedValue); 
        
        system.debug('valueMap'+valueMap);
        
        promptGenerationsInput.inputParams = valueMap;
        promptGenerationsInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        promptGenerationsInput.additionalConfig.applicationName = 'PromptBuilderPreview';
        promptGenerationsInput.isPreview = false;
        
        system.debug('promptGenerationsInput'+promptGenerationsInput);
        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                'Extract_Products_From_Email',
                promptGenerationsInput
            );
        system.debug('generationsOutput'+generationsOutput);
        return generationsOutput.generations[0].text; 
    }
}