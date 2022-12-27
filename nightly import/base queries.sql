--must add and not exist in mjrs tables    

-- function get last bastch date....   Must have seed value.  

-- create batches
-- add new inmates (newly sentenced)
-- update inmates
-- release inmates


-- newly sentenced charges
select * from epic.eh_sentence
where epic.ef_epic_date_to_date(date_entered) between sysdate-4 and sysdate;

-- newly release inmates
select * from epic.eh_release
where epic.ef_epic_date_to_date(actual_release) between sysdate-4 and sysdate;

-- newly status changes
select bcs.booking_id,
       bcs.custody_status_id,
       code_custody_status,
       bcs.date_start,
       MACOMB.mf_custody_status_end_date(bcs.booking_id, bcs.custody_status_id),
       floor(epic.ef_epic_date_to_date(MACOMB.mf_custody_status_end_date(bcs.booking_id, bcs.custody_status_id))- trunc(epic.ef_epic_date_to_date(bcs.date_start))),
 	   trunc(epic.ef_epic_date_to_date(bcs.date_start)) as mod_date
from epic.eh_booking_custody_status bcs
where epic.ef_epic_date_to_date(bcs.action_time) between sysdate-4 and sysdate
order by booking_id ;



select * from EPIC.EH_CHARGE;

select * from EPIC.EH_SENTENCE;
select * from EPIC.epp_booking_dates;
