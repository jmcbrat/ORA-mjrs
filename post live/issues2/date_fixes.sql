select *
from epic.eh_booking_custody_status bcs
where bcs.booking_id in (select booking_id from charge_detail where offender_id = '311198');

select bcs1.*,
       MF_charge_end_date_calc(bcs1.booking_id,
                   epic.ef_epic_date_to_date(bcs1.action_time)
                  ) as end_date

from epic.eh_booking_custody_status bcs1
where bcs1.booking_id in (select booking_id from charge_detail where offender_id = '311198')
order by bcs1.date_start;

select epic.ef_epic_date_to_date(bcs.date_start)
--INTO v_date
from epic.eh_booking_custody_status bcs
where bcs.booking_id = '0K4077O000USJ2WS' --p_booking_id
  and epic.ef_epic_date_to_date('2008071420:02:42-240') < epic.ef_epic_date_to_date(action_time)--p_action_time
  --and ROWNUM =1
  having rownum = 1
order by epic.ef_epic_date_to_date(bcs.action_time) asc
