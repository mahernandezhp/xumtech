public class XuM_AutoApproveMaxLimitAmount {
    public class Inputs {
        @InvocableVariable(required=true) public Id recordId;   // Opportunity Id
    }
    public class Results {
        @InvocableVariable public Boolean approved;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Auto Approve If Still Pending (42horas)')
    public static void run(List<Inputs> batch){
        if (batch.isEmpty()) return;

        Set<Id> oppIds = new Set<Id>();
        for (Inputs input : batch) {
            oppIds.add(input.recordId);
        }

        if (!oppIds.isEmpty()) {
            System.enqueueJob(new XUM_AutoApproveMaxLimitAmountQueueable(new List<Id>(oppIds)));
        }
    }
}