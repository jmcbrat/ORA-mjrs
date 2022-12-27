

				SELECT *
				  --INTO v_trancode,       v_end_date
				  FROM CHARGE_detail
				 WHERE offender_id = '107867' --booking_id = '0K3T36Z000USJ2WS' --p_booking_id
				   --AND charge_id = 4 --(vt_charge_id+1);


-- Correct the
-- this inmate should be showing a regular stay in charges (zero days and end dated) also.  It is being over written with a weekender code
-- that is missing the charge_id.   when I add a new charge end date the old one in both locations
