update inmates
set account_status_id = (SELECT account_status_id FROM ACCOUNT_STATUS_TYPES WHERE account_status_desc = 'Inactive')
--select * from charges
--select distinct offender_id from inmates
where  offender_id in (
					select distinct i.offender_id --*
					from inmates i,
					     ACCOUNT_STATUS_TYPES a,
					     charges c
					where i.account_status_id = a.account_status_id
					  and a.account_status_desc = 'Active'
					  --and c.end_date is null
					  and c.batch_id > 0
					  and c.is_work_release = 'no'
					  and i.offender_id = c.offender_id
					  and c.status_end_date is null
					  --order by offender_id
					  );
order by 1;

select * from ACCOUNT_STATUS_TYPES where account_status_id = 1;
