SELECT *
from epic.eh_booking_custody_status bcs,
       epic.eh_booking b,
       epic.eh_offender_ids id
WHERE  b.entity_id = id.entity_id
  AND  b.booking_id = bcs.booking_id (+)
  --AND  not bcs.code_custody_status in ('2','3','5','11','12','13','40')
  AND  not bcs.code_custody_status in ('2','3','11','12','13','40')
  AND id.offender_id = '83398'
  AND b.booking_id = '0KADFNS000USJ2BH' ;
