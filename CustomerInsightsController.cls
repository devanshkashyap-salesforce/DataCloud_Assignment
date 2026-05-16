public with sharing class CustomerInsightsController {
    
    public class DataCloudException extends Exception {}

    @AuraEnabled
    public static Map<String, Object> getCustomerData(String customerId) {
        if (String.isBlank(customerId)) {
            AuraHandledException ex = new AuraHandledException('Customer ID tracking parameter cannot be blank.');
            ex.setMessage('Customer ID tracking parameter cannot be blank.');
            throw ex;
        }

        try {
            String cleanId = String.escapeSingleQuotes(customerId.trim());
            
            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = 'SELECT Full_Name__c, Visitor_ID__c, Email__c, Phone__c, ' + 
                             'CAST(Engagement_Score__c AS VARCHAR), Customer_Intent__c, ' + 
                             'Product__c, Category__c, Session__c ' + 
                             'FROM Consolidate_Web_Data__dlm WHERE Visitor_ID__c = \'' + cleanId + '\'';
            
            ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
            
            if (queryOutput != null && queryOutput.data != null && !queryOutput.data.isEmpty()) {
                
                ConnectApi.CdpQueryV2Row firstRow = queryOutput.data[0];
                List<Object> firstRowData = firstRow.rowData;
                
                Map<String, Object> resultMap = new Map<String, Object>();
                resultMap.put('FullName', firstRowData[0] != null ? String.valueOf(firstRowData[0]) : '');
                resultMap.put('CustomerId', firstRowData[1] != null ? String.valueOf(firstRowData[1]) : '');
                resultMap.put('Email', firstRowData[2] != null ? String.valueOf(firstRowData[2]) : 'N/A');
                
                // FIX FOR PHONE NUMBER: Strip out trailing scientific zero decimal strings completely
                String rawPhone = firstRowData[3] != null ? String.valueOf(firstRowData[3]) : 'N/A';
                if (rawPhone.contains('.')) {
                    rawPhone = rawPhone.substringBefore('.');
                }
                resultMap.put('Phone', rawPhone);
                
                // FIX FOR ENGAGEMENT SCORE: Coerce text value string and lock to exactly 2 decimal spots
                Decimal score = 0.00;
                if (firstRowData[4] != null) {
                    try {
                        score = Decimal.valueOf(String.valueOf(firstRowData[4])).setScale(2);
                    } catch(Exception numEx) {
                        score = 0.00;
                    }
                }
                resultMap.put('EngagementScore', score);
                resultMap.put('IntentLevel', firstRowData[5] != null ? String.valueOf(firstRowData[5]) : 'Normal Interest');
                
                // Assemble the recent activities list tracking logs
                List<Map<String, String>> activitiesList = new List<Map<String, String>>();
                for (ConnectApi.CdpQueryV2Row row : queryOutput.data) {
                    List<Object> rData = row.rowData;
                    if (rData[6] != null || rData[7] != null) { 
                        Map<String, String> act = new Map<String, String>();
                        act.put('product', rData[6] != null ? String.valueOf(rData[6]) : 'Unknown Item');
                        act.put('category', rData[7] != null ? String.valueOf(rData[7]) : 'General Navigation');
                        act.put('session', rData[8] != null ? String.valueOf(rData[8]) : 'Direct Link');
                        activitiesList.add(act);
                    }
                }
                resultMap.put('activities', activitiesList);
                return resultMap;
                
            } else {
                throw new DataCloudException('Customer does not exist in the system.');
            }
        } catch (DataCloudException dce) {
            AuraHandledException ex = new AuraHandledException(dce.getMessage());
            ex.setMessage(dce.getMessage());
            throw ex;
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    @AuraEnabled
    public static String getAIRecommendation(String fullName) {
        if (String.isBlank(fullName)) {
            AuraHandledException ex = new AuraHandledException('Customer name parameter cannot be empty.');
            ex.setMessage('Customer name parameter cannot be empty.');
            throw ex;
        }

        ConnectApi.WrappedValue experienceSessionValue = new ConnectApi.WrappedValue();
        experienceSessionValue.value = fullName;
        
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
        inputParams.put('Input:Customer_Name', experienceSessionValue);

        ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        executeTemplateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        executeTemplateInput.additionalConfig.applicationName = 'PromptBuilderPreview';
        executeTemplateInput.isPreview = false;
        executeTemplateInput.inputParams = inputParams;

        try {
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = 
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Advisory_Prompt', executeTemplateInput);
            
            if (generationsOutput != null && generationsOutput.generations != null && !generationsOutput.generations.isEmpty()) {
                return generationsOutput.generations[0].text;
            }
            
            return 'Agentforce processed the prompt successfully, but returned an empty response string.';
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException('Agentforce Execution Failed: ' + e.getMessage());
            ex.setMessage('Agentforce Execution Failed: ' + e.getMessage());
            throw ex;
        }
    }
}