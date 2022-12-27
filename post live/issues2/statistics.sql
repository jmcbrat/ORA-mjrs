select *
from charges cd
where not exists (select 1 from epic.eh_release r where r.booking_id = cd.booking_id) -- remove non-releases
and exists (select 1 from epic.eh_active_booking ab where ab.booking_id = cd.booking_id); -- only those that are still active
--results 294

select *
from charge_detail cd
where not exists (select 1 from epic.eh_release r where r.booking_id = cd.booking_id) -- remove non-releases
and exists (select 1 from epic.eh_active_booking ab where ab.booking_id = cd.booking_id) -- only those that are still active
-- active not released 426
-- released and non active 785

