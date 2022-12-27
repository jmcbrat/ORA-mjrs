select OFFENDER_ID as off, CHARGE_DETAIL_ID as id, CHARGE_ID as cid, TRANSACTION_CODE as tran,
OFFTRK_DAYS_IN as din, STATUS_START_DATE as startdt, STATUS_END_DATE as enddt,
BOOKING_ID, CUSTODY_STATUS_ID, IS_WORK_RELEASE, batch_id
from CHARGE_DETAIL --where offender_id = '99422'
 order by offender_id,2
