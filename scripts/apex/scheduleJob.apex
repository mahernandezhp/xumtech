// Use this script to schedule the XUM_AutoApproveMaxLimitScheduler to run every minute.
// To execute, open the Developer Console in your Salesforce org,
// go to Debug > Open Execute Anonymous Window, paste this code, and click Execute.

XUM_AutoApproveMaxLimitScheduler job = new XUM_AutoApproveMaxLimitScheduler();
job.execute(null);

XUM_AutoApproveMaxLimitScheduler.scheduleEveryMinute();

Id jobId = System.enqueueJob(new VEC_AlertOppUnattendedQueueable());
System.debug('Enqueued job: ' + jobId);
