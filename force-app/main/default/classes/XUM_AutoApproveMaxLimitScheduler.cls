// Schedulable class to invoke XUM_AutoApproveMaxLimitAmountQueueable logic every minute.
// NOTE: Scheduling every minute can consume significant scheduled job resources; ensure this is acceptable for your org limits.
global without sharing class XUM_AutoApproveMaxLimitScheduler implements Schedulable {

    // Executes on schedule, processes items, and reschedules itself to run again in one minute.
    global void execute(SchedulableContext sc) {

        DateTime cutoff = System.now().addMinutes(-1); // 3 minutes ago (adjust value as needed for production)

        // Query pending approval work items
        List<ProcessInstanceWorkitem> wis = [
            SELECT ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.Status = 'Pending'
              AND CreatedDate <= :cutoff
              AND ProcessInstance.TargetObjectId != null
            LIMIT 500
        ];

        System.debug('Found ' + wis.size() + ' pending work items older than cutoff.');

        if (!wis.isEmpty()) {
            Set<Id> oppIds = new Set<Id>();
            for (ProcessInstanceWorkitem w : wis) {
                oppIds.add(w.ProcessInstance.TargetObjectId);
            }

            // Use the Queueable class to process the records
            System.enqueueJob(new XUM_AutoApproveMaxLimitAmountQueueable(new List<Id>(oppIds)));
        }

    }

    // Helper to programmatically schedule this job to run in one minute.
    public static Id scheduleEveryMinute() {
        return System.schedule('XUM AutoApprove Every Minute', '0 0 * * * ?', new XUM_AutoApproveMaxLimitScheduler());
    }

}