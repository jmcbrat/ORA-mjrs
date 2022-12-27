select * --offender_id, booking_id, count(*)
from charges  c1
where TRANSACTION_CODE = '4201'
and exists (select offender_id, booking_id, count(*)
				from charges c2
				where TRANSACTION_CODE = '4201'
				  and c2.offender_id = c1.offender_id
				  and c2.booking_id = c1.booking_id
				group by offender_id, booking_id
				having count(*)>1);
--having count(*) > 1;
--group by offender_id, booking_id
--having count(*) > 1;
      ;
select * from charge_Detail where offender_id = '320673' and booking_id = '0KBF8GR000USJ2WS';




delete from charges
where is_work_release = 'no' and offender_id =  '320673'
  and booking_id = '0KBF8GR000USJ2WS';

delete from charges
where is_work_release = 'no' and offender_id =  '60500'
  and booking_id = '0KBCWUU000USJ2WS';
