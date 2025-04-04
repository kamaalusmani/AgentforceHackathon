public class OpportunityLineItemCreator {
         public static Boolean isOpportunityCreated=false;
    public static Boolean createOpportunityLineItems(String response, Id opportunityId) {
    
        
        // Check if "JSON Extracted" is present in the response
        if (!response.contains('JSON Extracted')) {
            System.debug('JSON Extracted string not found in response.');
            return isOpportunityCreated;
        }

        // Extract JSON from response (assuming JSON starts right after "JSON Extracted")
        Integer jsonStartIndex = response.indexOf('JSON Extracted') + 'JSON Extracted'.length();
        String jsonString = response.substring(jsonStartIndex).trim();

        // Ensure extracted JSON is not empty
        if (String.isBlank(jsonString)) {
            System.debug('Extracted JSON is empty.');
            return isOpportunityCreated;
        }

        try {
            // Parse JSON
            List<ProductWrapper> productList = (List<ProductWrapper>) JSON.deserialize(jsonString, List<ProductWrapper>.class);

            List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();

            // Fetching Product2 records
            Map<String, Id> productPricebookEntryMap = new Map<String, Id>();
            Set<String> productNames = new Set<String>();
            
            for (ProductWrapper product : productList) {
                productNames.add(product.product_name);
            }

            // Get the standard price book
            Id pricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

            // Query Product2 & related PricebookEntry
            for (PricebookEntry pbe : [
                SELECT Id, Product2.Name 
                FROM PricebookEntry 
                WHERE Product2.Name IN :productNames AND Pricebook2Id = :pricebookId AND IsActive = TRUE
            ]) {
                productPricebookEntryMap.put(pbe.Product2.Name, pbe.Id);
            }

            // Create OpportunityLineItem records
            for (ProductWrapper product : productList) {
                if (productPricebookEntryMap.containsKey(product.product_name)) {
                    OpportunityLineItem oli = new OpportunityLineItem();
                    oli.OpportunityId = opportunityId;
                    oli.PricebookEntryId = productPricebookEntryMap.get(product.product_name);
                    oli.Quantity = Integer.valueOf(product.quantity);
                    oli.TotalPrice = 1000; // Example price, update logic as needed
                    oliList.add(oli);
                }
            }

            // Insert OpportunityLineItems
            if (!oliList.isEmpty()) {
                insert oliList;
                isOpportunityCreated=true;
            }
        } catch (Exception e) {
            System.debug('Error processing JSON: ' + e.getMessage());
        }
        
        return isOpportunityCreated;
    }

    public class ProductWrapper {
        public String product_name;
        public String quantity;
        public Map<String, String> attributes;
    }
    
}