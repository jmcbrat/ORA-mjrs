select sum(adjusted_charge_amt), sum(original_charge_amt), min(status_start_date), max(status_end_date) from CHARGES
where booking_id = '0JUOQSV000USJ2BF'

order by offender_id, charge_id;


--4140,	4140,	01/15/2008 12:31:00,	11/12/2008 07:36:00

select * from CHARGES
where booking_id = '0JUOQSV000USJ2BF'

order by offender_id, charge_id;
