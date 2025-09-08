public class XUM_AutoApproveMaxLimitAmount {
    public class Inputs {
        @InvocableVariable(required=true) public Id recordId;   // Opportunity Id
    }
    public class Results {
        @InvocableVariable public Boolean approved;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Auto Approve If Still Pending (42horas)')
    public static List<Results> run(List<Inputs> batch){
        List<Results> out = new List<Results>();
        Set<String> oppIds = new Set<String>();

        if (batch.isEmpty()) return out;

        for(Inputs input : batch){
            oppIds.add(input.recordId);
        }
        
        if(oppIds == null && oppIds.isEmpty()){
            return out;
        }

        Map<Id, Opportunity> opps = new Map<Id, Opportunity>([
            SELECT Id
            FROM Opportunity
            WHERE Id IN :oppIds
        ]);

        for (Inputs i : batch) {
            Results r = new Results();
            try {
                Opportunity opp = opps.get(i.recordId);
                if (opp == null) { r.approved = false; r.message = 'Opp no encontrada'; out.add(r); continue; }
                
                List<ProcessInstanceWorkitem> wis = [
                    SELECT Id, ProcessInstance.Status
                    FROM ProcessInstanceWorkitem
                    WHERE ProcessInstance.TargetObjectId = :i.recordId
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

                r.approved = res.isSuccess();
                r.message  = res.getInstanceStatus();
            } catch (Exception e) {
                r.approved = false; r.message = e.getMessage();
            }
            out.add(r);
        }
        return out;
    }
}