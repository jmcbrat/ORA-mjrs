select distinct id.offender_id, bcs.*, rel_book.release_id from (
SELECT distinct id.offender_id,
                b.booking_id ,
                custody_status_id,
                'RELEASE INMATE',
                4,                    -- note was 3
                bcs.code_custody_status,
				to_Date(decode(epic.ef_epic_date_to_date(date_start),
				                                   null,
				                                   null,
				                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
				to_Date(decode(epic.ef_epic_date_to_date(ACTUAL_RELEASE),null,null,to_char(epic.ef_epic_date_to_date(ACTUAL_RELEASE), 'mm/dd/yyyy')||' 23:59:59')) as status_end,
				r.release_id
from epic.eh_booking_custody_status bcs,
       epic.eh_release r,
       epic.eh_booking b,
       epic.eh_offender_ids id,
       epic.eh_charge ec
WHERE  b.booking_id = r.booking_id (+)
  AND  b.entity_id = id.entity_id
  AND  b.booking_id = ec.booking_id
  AND  b.booking_id = bcs.booking_id (+)
  --AND  not bcs.code_custody_status in ('2','3','5','11','12','13','40')
  AND  not bcs.code_custody_status in ('2','3','11','12','13','40')
  --AND  c.sentence_id is not null        -- at least one charge sentenced
  AND  epic.ef_epic_date_to_date(r.actual_release) BETWEEN to_date('12/09/2008')
                                                       AND sysdate
  order by booking_id, code_custody_status) rel_book,
epic.eh_booking_custody_status bcs,
epic.eh_booking b,
epic.eh_offender_ids id
where rel_book.booking_id = bcs.booking_id
and b.entity_id = id.entity_id
and b.booking_id = bcs.booking_id (+)
and not exists (select c.OFFENDER_ID as id, c.CHARGE_ID as charge, c.TRANSACTION_CODE as trans,
				ct.OFFTRK_DESCRIPTION as trans_desc, ct.DAILY_RATE as rate, c.BOOKING_DATE as book_date, c.END_DATE as rele_date,
				c.ORIGINAL_CHARGE_AMT as charge_amt, c.BATCH_ID as batch, c.IS_WORK_RELEASE as is_wr, c.STATUS_START_DATE as startdt,
				c.STATUS_END_date as enddt, c.CUSTODY_STATUS_ID as cust_stat_id, c.REF_CHARGE_Id
			from charges c,
			   CHARGE_TYPE ct
			where c.transaction_code = ct.transaction_code
			and to_number(c.TRANSACTION_CODE) < 4250
			and c.offender_id = id.offender_id)
order by offender_id, bcs.booking_id, date_start;


--select * from epic.eh_booking_custody_status bcs where booking_id = '0K6XI0H000USJ2WS'
--order by 4
