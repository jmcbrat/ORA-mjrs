SELECT distinct id.offender_id,
                bcs.booking_id ,
                custody_status_id,
                bcs.code_custody_status,
                ct.OFFTRK_DESCRIPTION,
				to_Date(decode(epic.ef_epic_date_to_date(date_start),
				                                   null,
				                                   null,
				                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
				to_Date(decode(epic.ef_epic_date_to_date(ACTUAL_RELEASE),null,null,to_char(epic.ef_epic_date_to_date(ACTUAL_RELEASE), 'mm/dd/yyyy')||' 23:59:59')) as status_end
FROM   epic.eh_booking_custody_status bcs,
       epic.eh_booking b,
	   epic.eh_offender_ids id,
       epic.eh_charge c,
       CHARGE_TYPE ct,
       epic.eh_release r
WHERE  ct.OFFTRK_CODE = bcs.code_custody_status
  and  b.booking_id = r.booking_id(+)
  and  b.entity_id = id.entity_id
  AND  b.booking_id = bcs.booking_id
  AND  not bcs.code_custody_status in ('2','3','11','12','13','40')
  AND  b.booking_id = c.booking_id
  AND  c.sentence_id is not null        -- at least one charge sentenced
  AND  id.offender_id = '327260'
  --AND  epic.ef_epic_date_to_date(bcs.action_time) BETWEEN MF_GET_LAST_RUN()
  --                                                    AND sysdate
                                          ;


