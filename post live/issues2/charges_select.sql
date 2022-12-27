select c.OFFENDER_ID as id, c.CHARGE_ID as charge, c.TRANSACTION_CODE as trans,
	ct.OFFTRK_DESCRIPTION as trans_desc, ct.DAILY_RATE as rate, c.BOOKING_DATE as book_date, c.END_DATE as rele_date,
	c.ORIGINAL_CHARGE_AMT as charge_amt, c.BATCH_ID as batch, c.IS_WORK_RELEASE as is_wr, c.STATUS_START_DATE as startdt,
	c.STATUS_END_date as enddt, c.CUSTODY_STATUS_ID as cust_stat_id, c.REF_CHARGE_Id
from charges c,
   CHARGE_TYPE ct
where c.transaction_code = ct.transaction_code
and to_number(c.TRANSACTION_CODE) < 4250
and c.offender_id = '102278'

