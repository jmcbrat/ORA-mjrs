select *
from CHARGES c,
     inmates i
where c.offender_id = i.offender_id
and status_end_date is null
and i.account_status_id = 1
and batch_id <> 0
and not TRANSACTION_CODE in ('4201','4229','4250');

update inmates
set ACCOUNT_STATUS_ID = 0
where offender_id in ('127365',
'162879');

