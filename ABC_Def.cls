public class CARMA_MassPatronageLettersCtrl {  

    private ApexPages.StandardSetController stdSetController;  
    public Boolean showError {get;set;}   
    public Boolean inCorrectRecord {get;set;}
    public Boolean noAccess {get;set;}
    public String  generateLettersURL {get;set;}       
    private @TestVisible List<Id> lstRecordId;      

    public CARMA_MassPatronageLettersCtrl(ApexPages.StandardSetController sscOther) {

        ListView generateLettersView = [select Id,Name from ListView where Name =:'Patronage Letter Task List'];   
        generateLettersURL =  URL.getSalesforceBaseUrl().toExternalForm()+'/lightning/o/CARMA_Task__c/list?filterName='+ generateLettersView.Id;  
        noAccess = false;          
        showError = false;    
        inCorrectRecord = false ;    
        stdSetController = sscOther;
        String userName = UserInfo.getName();    
        List<SObject> selectedRecords = stdSetController.getSelected();
        List<PermissionSetAssignment> lstPermissionSet = [SELECT Id,PermissionSet.Name FROM PermissionSetAssignment WHERE Assignee.Name =: userName 
                                                        and PermissionSet.Name in ('CARMA_OCC_Manager','CARMA_OCC_Lead','CARMA_OCC_Super_User')];
        if(lstPermissionSet.isEmpty() || lstPermissionSet== null){ 
             noAccess = true;    
             showError = true;        
           } else {      
                lstRecordId = new List<Id>(); 
                for(SObject record : selectedRecords) {
                    Id recordId = String.valueOf(record.get('Id'));   
                    lstRecordId.add(recordId);
                }     
                List<Carma_Task__c> carmaTaskLst = [Select Id,EDIPI_Number__c, EDIPI_Status__c,Status__c,RecordType.Name, Assessment_Type__c from Carma_Task__c where Id in: lstRecordId ];
            
                for(CARMA_Task__c task: carmaTaskLst){    
                    if(task.EDIPI_Status__c != 'Batch Retrieve' || task.RecordType.Name != 'OCC Tasks' || task.Status__c != 'Done' || 
                        task.Assessment_Type__c != 'New Application' || task.EDIPI_Number__c == null ){  
                        inCorrectRecord =true;    
                        showError = true;         
                        break;   
                    }     
                }   
            }                                         
    }           
      
    public PageReference createMassMergeJobs() {
        if(!showError ){
                System.debug( 'The showError is >> '+showError ); 
                String objectName = ApexPages.currentPage().getParameters().get('objectName');
                Boolean showHeader = ApexPages.currentPage().getParameters().get('showHeader') != 'false';
                List<SDOC__SDJob__c> addToMassMerge = new List<SDOC__SDJob__c>();
                List<SObject> selectedRecords = stdSetController.getSelected();
                if (Test.isRunningTest()) {    
                    selectedRecords = new List<SObject> { new Contact(LastName='Test') };
                }
                for (SObject selectedRecord : selectedRecords) {
                    SDOC__SDJob__c massMergeJob = new SDOC__SDJob__c(
                        SDOC__Oid__c = String.valueOf(selectedRecord.get('Id')),
                        SDOC__runAs__c = UserInfo.getUserName(),
                        SDOC__Status__c = 'Selected',      
                        SDOC__type__c = 'Bulk Job - List View',   
                        SDOC__objAPIName__c = objectName,
                        SDOC__Doclist__c = 'Patronage' 
                    );
                    addToMassMerge.add(massMergeJob);  
                }
                insert addToMassMerge;

                Integer batchSize = Database.countQuery(
                    'SELECT COUNT() FROM SDOC__SDJob__c WHERE ownerid=\'' 
                    + String.valueOf(UserInfo.getUserId()) + '\''
                    + ' AND SDOC__Type__c=\'Bulk Job - List View\''
                    + ' AND SDOC__ObjApiName__c=\'' + objectName + '\''
                );
        
                String sDocTemplateIdString ='Patronage';
                    PageReference massMergePage = new PageReference(
                    + '/apex/SDOC__SDJobContact'          
                    + '?numRecordsAdded=' + String.valueOf(addToMassMerge.size()) 
                    + '&batchSize=' + batchSize
                    + '&objectName=' + objectName
                    + '&showHeader=' + showHeader
                    + '&sidebar=false' 
                    + '&tab=2'                 
                );
                return massMergePage;     
            }
        return null;
    }
}
