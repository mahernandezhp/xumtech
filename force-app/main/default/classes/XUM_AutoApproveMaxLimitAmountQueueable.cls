public class XUM_AutoApproveMaxLimitAmountQueueable implements Queueable {
    private List<Id> recordIds;

    public XUM_AutoApproveMaxLimitAmountQueueable(List<Id> recordIds) {
        this.recordIds = recordIds;
    }

    public void execute(QueueableContext context) {
        if (recordIds == null || recordIds.isEmpty()) {
            return;
        }

        // Consolidate SOQL query to fetch Opportunities
        Map<Id, Opportunity> opps = new Map<Id, Opportunity>([
            SELECT Id
            FROM Opportunity
            WHERE Id IN :recordIds
        ]);

        // Consolidate SOQL query to fetch ProcessInstanceWorkitems
        Map<Id, ProcessInstanceWorkitem> workitemMap = new Map<Id, ProcessInstanceWorkitem>();
        for (ProcessInstanceWorkitem wi : [
            SELECT Id, ProcessInstance.Status, ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId IN :recordIds
            ORDER BY CreatedDate DESC
        ]) {
            if (!workitemMap.containsKey(wi.ProcessInstance.TargetObjectId)) {
                workitemMap.put(wi.ProcessInstance.TargetObjectId, wi);
            }
        }

        List<Approval.ProcessWorkitemRequest> requests = new List<Approval.ProcessWorkitemRequest>();
        List<Id> unlockIds = new List<Id>();
        List<XUM_AutoApproveMaxLimitAmount.Results> results = new List<XUM_AutoApproveMaxLimitAmount.Results>();

        for (Id recordId : recordIds) {
            XUM_AutoApproveMaxLimitAmount.Results result = new XUM_AutoApproveMaxLimitAmount.Results();
            try {
                Opportunity opp = opps.get(recordId);
                if (opp == null) {
                    result.approved = false;
                    result.message = 'Opp no encontrada';
                    results.add(result);
                    continue;
                }

                ProcessInstanceWorkitem workitem = workitemMap.get(recordId);
                if (workitem == null || workitem.ProcessInstance.Status != 'Pending') {
                    result.approved = false;
                    result.message = 'Sin aprobación pendiente.';
                    results.add(result);
                    continue;
                }

                Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
                req.setWorkitemId(workitem.Id);
                req.setAction('Approve');
                req.setComments('La solicitud ha sido aprobada automaticamente');
                requests.add(req);
                unlockIds.add(recordId);

                result.approved = true;
                result.message = 'Aprobado y desbloqueado';
            } catch (Exception e) {
                result.approved = false;
                result.message = e.getMessage();
            }
            results.add(result);
        }

        // Process approvals in bulk
        if (!requests.isEmpty()) {
            List<Approval.ProcessResult> processResults = Approval.process(requests);
            for (Approval.ProcessResult processResult : processResults) {
                if (!processResult.isSuccess()) {
                    // Log or handle individual approval errors
                }
            }
        }

        // Unlock records in bulk
        if (!unlockIds.isEmpty()) {
            List<Approval.UnlockResult> unlockResults = Approval.unlock(unlockIds);
            for (Approval.UnlockResult unlockResult : unlockResults) {
                if (!unlockResult.isSuccess()) {
                    // Log or handle individual unlock errors
                }
            }
        }
    }
}