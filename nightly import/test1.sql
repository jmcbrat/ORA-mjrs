		select
	       code_custody_status
	from epic.eh_booking_custody_status
	where
	 date_start in
		(select max(date_start)
		from epic.eh_booking_custody_status);
		--where booking_id = p_booking_id);

select booking_id, custody_status_id, code_custody_status, date_start,
MACOMB.mf_custody_status_end_date('0K8FHQ0000USJ2WS', '0K8FHQJ300USJZ10') as date_end
from epic.eh_booking_custody_status bcs
where epic.ef_epic_date_to_date(date_start) between sysdate-7 and sysdate
  and booking_id = '0K8FHQ0000USJ2WS'
  and custody_status_id = '0K8FHQJ300USJZ10'
order by date_start; --booking_id
