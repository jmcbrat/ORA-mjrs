select * from eh_offender_ids where offender_id in ('324286','315078');
--315078 0JF1ITP000USJ2BF Booking Date: 10/03/08  Charge Booked: 10/07/08
--324286 0K3BXHN000USJ2WS Booking Date: 07/01/08 Charge Booked: 07/02/08
--eh_charge.offense_date

select  EPIC.ef_epic_date_to_date(EPIC.epp_booking_dates.start_date(b.booking_id)),
       b.* from eh_booking b where b.entity_id in ('0JF1ITP000USJ2BF','0K3BXHN000USJ2WS');

select * from eh_charge where booking_id in ('0K86G3L000USJ2WS','0K3BXMQ000USJ2WS');

select * from EH_BOOKING_CUSTODY_STATUS where booking_id in ('0K86G3L000USJ2WS','0K3BXMQ000USJ2WS');

select * from EH_BOOKING_ENTITY_STATUS  where booking_id in ('0K86G3L000USJ2WS','0K3BXMQ000USJ2WS');

charged_booked
