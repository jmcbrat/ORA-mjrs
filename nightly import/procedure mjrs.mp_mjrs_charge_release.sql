CREATE OR REPLACE
PROCEDURE MP_mjrs_charge_release (
		p_batch_id          IN      VARCHAR2,
		p_offender_id       IN		VARCHAR2,
		p_booking_id        IN      VARCHAR2,
		p_status_date  		IN		DATE,
		p_Status			   OUT	VARCHAR2
	 )
		
IS
/*	
	Purpose:		update offendertrak charge/status into mjrs for release inmate
					
	Author:			Joseph McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
					----------	 -------------	------------------------------------------
					J. McBratnie 10/20/08		Created 
                  
*/  
v_charge_id         number;
v_existing_charge   number;
v_work_release      varchar2(3); 
v_cash_settlement   varchar2(3);
v_new_end           date; 

BEGIN
    p_Status := 'TRUE';
	--dbms_output.put_line('status release....');

	-- set the max charge_id for reference later.
	BEGIN
		SELECT max(charge_id) 
		  INTO v_charge_id 
		  FROM charges 
		 WHERE booking_id = p_booking_id
	  GROUP BY booking_id;
	EXCEPTION when no_data_found then
		v_charge_id := 1;
	END;



        --prep for update
        BEGIN
			SELECT is_work_release, is_cash_settlement
			  INTO v_work_release, v_cash_settlement 
			  FROM charges 
			 WHERE booking_id = p_booking_id 
			   AND charge_id = v_charge_id 
			   AND STATUS_END_DATE IS NULL;
		EXCEPTION WHEN no_data_found THEN
			 v_work_release := 'no';
			 v_cash_settlement := 'no';
		END;		
		IF (lower(v_work_release) = 'yes' OR lower(v_cash_settlement) = 'yes' ) THEN
			-- Complete the status DONT update the amounts.
			UPDATE charges 
			   SET (END_DATE, OFFTRK_DAYS_IN, BATCH_ID, STATUS_END_DATE 
			       ) =
				(SELECT 
					 p_status_date AS release_date, -- release date,
					 floor(p_status_date - epic.ef_epic_date_to_date(bcs.date_start)) AS days_in,
					 p_batch_id,
					 --epic.ef_epic_date_to_date(bcs.date_start)
					 p_status_date AS status_end
				 FROM epic.eh_booking_custody_status bcs
				 WHERE booking_id = p_booking_id              
				   and epic.ef_epic_date_to_date(action_time) = (select  max(epic.ef_epic_date_to_date(action_time)) 
				                                                FROM epic.eh_booking_custody_status
																where booking_id =p_booking_id 
																group by booking_id)				 
				)
 			WHERE booking_id = p_booking_id
 			  AND charge_id = v_charge_id; 

			MP_mjrs_charge_insert_log(p_batch_id, p_booking_id, v_charge_id+1);
 			  
		ELSE -- No work release or cash settlement at this time.  OK to update amounts.
			UPDATE charges 
			  SET (END_DATE, OFFTRK_DAYS_IN, ORIGINAL_CHARGE_AMT, ADJUSTED_CHARGE_AMT, 
			       BATCH_ID, STATUS_END_DATE
			      ) = 
				(SELECT 
					 p_status_date as release_date, -- release date,
					 floor(p_status_date - epic.ef_epic_date_to_date(bcs.date_start)) as days_in,
	                 -- function to calc rent
	                 MF_Get_Rent(code_custody_status ,
	                             floor(epic.ef_epic_date_to_date(bcs.date_end)-epic.ef_epic_date_to_date(bcs.date_start))
	                            ) as original_charge_amt,
	                 MF_Get_Rent(code_custody_status ,
	                             floor(epic.ef_epic_date_to_date(bcs.date_end)-epic.ef_epic_date_to_date(bcs.date_start))
	                            ) as ADJUSTED_CHARGE_AMT,
	                 p_batch_id,
					 --epic.ef_epic_date_to_date(bcs.date_start) 
					 p_status_date  AS status_end
				 FROM epic.eh_booking_custody_status bcs
				 WHERE booking_id = p_booking_id                      
				   and epic.ef_epic_date_to_date(action_time) = (select  max(epic.ef_epic_date_to_date(action_time)) 
				                                                FROM epic.eh_booking_custody_status
																where booking_id =p_booking_id 
																group by booking_id)
				) 
			WHERE booking_id = p_booking_id
			  AND charge_id = v_charge_id;

			MP_mjrs_charge_insert_log(p_batch_id, p_booking_id, v_charge_id+1);
					
		END IF; -- v_work_release
		COMMIT;
		
		MP_mjrs_charge_insert_log(p_batch_id, p_booking_id, v_charge_id);
		
		   -- dbms_output.put_line('release inmate');



END;
/
