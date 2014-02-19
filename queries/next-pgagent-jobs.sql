-- file: next-pgagent-jobs.sql
-- descrition: Lists next PGAgent jobs.
-- version: >= 9.0

SELECT
  pga_job.jobname as job_name,
  pga_jobstep.jstdbname as database_name,
  pgagent.pga_next_schedule(
  pga_schedule.jscid,
  pga_schedule.jscstart,
  pga_schedule.jscend,
  pga_schedule.jscminutes,
  pga_schedule.jschours,
  pga_schedule.jscweekdays,
  pga_schedule.jscmonthdays,
  pga_schedule.jscmonths) as next_run
FROM
  pgagent.pga_job
  JOIN
    pgagent.pga_schedule ON pga_schedule.jscjobid = pga_job.jobid
  JOIN
  pgagent.pga_jobstep ON pga_jobstep.jstjobid = pga_job.jobid;