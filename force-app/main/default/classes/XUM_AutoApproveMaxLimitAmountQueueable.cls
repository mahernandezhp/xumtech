public class XUM_AutoApproveMaxLimitAmountQueueable implements Queueable {
    private List<Id> recordIds;

    public XUM_AutoApproveMaxLimitAmountQueueable(List<Id> recordIds) {
        this.recordIds = recordIds;
    }

    public void execute(QueueableContext context) {
        List<XUM_AutoApproveMaxLimitAmount.Results> out = new List<XUM_AutoApproveMaxLimitAmount.Results>();

        if (recordIds == null || recordIds.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> opps = new Map<Id, Opportunity>([
            SELECT Id
            FROM Opportunity
            WHERE Id IN :recordIds
        ]);

        for (Id recordId : recordIds) {
            XUM_AutoApproveMaxLimitAmount.Results r = new XUM_AutoApproveMaxLimitAmount.Results();
            try {
                Opportunity opp = opps.get(recordId);
                if (opp == null) { r.approved = false; r.message = 'Opp no encontrada'; out.add(r); continue; }

                List<ProcessInstanceWorkitem> wis = [
                    SELECT Id, ProcessInstance.Status
                    FROM ProcessInstanceWorkitem
                    WHERE ProcessInstance.TargetObjectId = :recordId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];

                if (wis.isEmpty() || wis[0].ProcessInstance.Status != 'Pending') {
                    r.approved = false; r.message = 'Sin aprobación pendiente.'; out.add(r); continue;
                }

                Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
                req.setWorkitemId(wis[0].Id);
                req.setAction('Approve');
                req.setComments('La solicitud ha sido aprobada automaticamente');
                Approval.ProcessResult res = Approval.process(req);

                if (res.isSuccess()) {
                    Approval.UnlockResult unlockRes = Approval.unlock(recordId);
                    if (unlockRes.isSuccess()) {
                        r.approved = true;
                        r.message = 'Aprobado y desbloqueado: ' + res.getInstanceStatus();
                    } else {
                        r.approved = false;
                        r.message = 'Aprobado pero no se pudo desbloquear: ' + unlockRes.getErrors()[0].getMessage();
                    }
                } else {
                    r.approved = false;
                    r.message = res.getInstanceStatus();
                }
            } catch (Exception e) {
                r.approved = false; r.message = e.getMessage();
            }
            out.add(r);
        }
    }
}