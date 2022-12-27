CREATE OR REPLACE
PROCEDURE MP_mjrs_charge_maint (
		p_batch_id          IN      number,
		p_offender_id       IN		VARCHAR2,
		p_booking_id        IN      VARCHAR2,
		p_custody_status_id IN      VARCHAR2,
		p_rec_type          IN      VARCHAR2,
        p_custody_status	IN		VARCHAR2,
        p_status_start		IN		DATE,
        p_status_end		IN		DATE,
		p_Status			   OUT	VARCHAR2
	 )

IS
/*	
	Purpose:		insert offendertrak charge/status into mjrs
					
	Author:			Joseph McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
					----------	 -------------	------------------------------------------
					J. McBratnie 10/14/08		Created  
					J. McBratnie 10/27/08		Update parameter list and function to fix bug 
					                            and reduce processing tim
                  
*/  
v_charge_id         number;
v_existing_charge   number;
v_work_release      varchar2(3); 
v_cash_settlement   varchar2(3);
v_new_end           date; 

BEGIN
    p_Status := 'TRUE';
	--dbms_output.put_line('Insert inmate log....');
	-- set the max charge_id for reference later.  
    if p_offender_id = '134399' then
    	dbms_output.put_line('Got one'|| p_offender_id ||'= 134399') ;
    END IF;
 	BEGIN
		SELECT max(charge_id) 
		  INTO v_charge_id 
		  FROM charges 
		 WHERE offender_id = p_offender_id
	  GROUP BY offender_id;
	EXCEPTION when no_data_found then
		v_charge_id := 0;
	END;   
	
	IF v_charge_id > 0 THEN -- update old charge/status
        
		dbms_output.put_line( 'booking id: '||p_booking_id|| 'Charge id: '||v_charge_id|| 'end date'|| p_status_start);  
		BEGIN
			SELECT is_work_release, is_cash_settlement,STATUS_START_DATE
			  INTO v_work_release, v_cash_settlement, v_new_end 
			  FROM charges 
			 WHERE booking_id = p_booking_id 
			   AND charge_id = v_charge_id 
			   AND STATUS_END_DATE IS NULL;	
		EXCEPTION WHEN no_data_found THEN
			    v_work_release := 'no';
			    v_cash_settlement := 'no';
			    v_new_end := sysdate;
		END; 

		UPDATE charges
		SET (STATUS_END_DATE) =  p_status_start
			--(SELECT epic.ef_epic_date_to_date(bcs.date_start) AS status_start
			-- FROM epic.eh_booking_custody_status bcs
	 		-- WHERE booking_id = p_booking_id
	 		--) 
		WHERE offender_id = p_offender_id
		  AND charge_id = v_charge_id
		  AND status_end_date IS NULL;

		IF (lower(v_work_release) = 'yes' OR lower(v_cash_settlement) = 'yes' ) THEN
			-- Complete the status DONT update the amounts.
			UPDATE charges 
			   SET (END_DATE, OFFTRK_DAYS_IN, BATCH_ID, STATUS_START_DATE, MODIFIED_BY
			       ) =
				(SELECT 
					 v_new_end, --decode(MACOMB.MCF_ISACTIVEBOOKING_FROM_BOOK(bcs.booking_id), 'FALSE',p_status_end, NULL) AS release_date, -- release date,
					 decode(MACOMB.MCF_ISACTIVEBOOKING_FROM_BOOK(bcs.booking_id), 'TRUE',floor(p_status_end-p_status_start),
					                                                                     floor(p_status_end-p_status_start)) AS days_in,
					 p_batch_id,
					 epic.ef_epic_date_to_date(bcs.date_start) AS status_start,
					 -3
				 FROM epic.eh_booking_custody_status bcs
				 WHERE booking_id = p_booking_id
				)
 			WHERE offender_id = p_offender_id
 			  AND charge_id = v_charge_id; 

			--MP_mjrs_charge_insert_log(p_batch_id, p_booking_id, v_charge_id);
 			  
		ELSE -- No work release or cash settlement at this time.  OK to update amounts.
		dbms_output.put_line('batch id: '|| p_batch_id);
			UPDATE charges 
			  SET (END_DATE, OFFTRK_DAYS_IN, ORIGINAL_CHARGE_AMT, ADJUSTED_CHARGE_AMT, 
			       STATUS_END_DATE, MODIFIED_BY
			      ) = 
				(SELECT 
					 p_status_end as release_date, -- release date,
					 decode(MACOMB.MCF_ISACTIVEBOOKING_FROM_BOOK(bcs.booking_id), 'TRUE',floor(p_status_end-p_status_start ),
					                                                                     floor(p_status_end-p_status_start)) as days_in,
	                 -- function to calc rent
	                 MF_Get_Rent(code_custody_status ,
	                             floor(p_status_end-p_status_start)
	                            ) as original_charge_amt,
	                 MF_Get_Rent(code_custody_status ,
	                             floor(p_status_end-p_status_start)
	                            ) as ADJUSTED_CHARGE_AMT,
	                 --p_batch_id,
					 p_status_end AS STATUS_END_DATE,
					 -4
				 FROM epic.eh_booking_custody_status bcs
				 WHERE booking_id = p_booking_id    --- need to add booking_custody_Status_id to this update.... 
				   AND bcs.custody_status_id = p_custody_status_id
				) 
			WHERE offender_id = p_offender_id
			  AND charge_id = v_charge_id;

			--MP_mjrs_charge_insert_log(p_batch_id, p_booking_id, v_charge_id);
        END IF;
		commit;
		--MP_mjrs_charge_insert_log(p_batch_id, p_booking_id, 1);
	END IF; 
 	-- insert the new chrage/status
		dbms_output.put_line( 'insert booking id: '||p_booking_id|| ' Charge id: '||v_charge_id|| ' custody '|| p_custody_status_id);  
   INSERT INTO CHARGES
   (OFFENDER_ID, CHARGE_ID, TRANSACTION_CODE, BOOKING_DATE, 
    OFFTRK_DAYS_IN, DAYS_IN, BATCH_ID, PROJ_RELEASE_DATE, 
    STATUS_START_DATE, BOOKING_ID,
    IS_CASH_SETTLEMENT, IS_WORK_RELEASE, MODIFIED_BY, MODIFIED_DATE, AGING, WAS_STMT_SENT
   )
	SELECT distinct p_offender_id AS offender_id,
		   v_charge_id + 1 AS charge_id, 
		   Mf_Get_Transaction_Code(code_custody_status) AS Transaction_code,
		   MF_Get_offense_date(booking_id) AS book_date, -- also called charged booked
		   floor(sysdate - p_status_start) AS offtrk_days_in, -- should this be projected days???
		   floor(sysdate - p_status_start) AS days_in,        -- should this be projected days???
		   --MF_Get_Rent(code_custody_status ,
               --             floor(epic.ef_epic_date_to_date(bcs.date_end)-epic.ef_epic_date_to_date(bcs.date_start))
                --           ) AS ORIGINAL_CHARGE_AMT,                      
		   --MF_Get_Rent(code_custody_status ,
              --              floor(epic.ef_epic_date_to_date(bcs.date_end)-epic.ef_epic_date_to_date(bcs.date_start))
              --             ) AS ADJUSTED_CHARGE_AMT,
     	   p_batch_id,                       
		   p_status_end, --epic.ef_epic_date_to_date(epic.epp_booking_dates.final_release_date(bcs.booking_id)) AS proj_release_date,
		   p_status_start,  --epic.ef_epic_date_to_date(bcs.date_start) AS status_start_date,
		   --NULL AS status_end_date,
		   p_booking_id AS booking_id,
		   'no',
		   'no',
		   -2,
		   sysdate,
		   0,
		   'no'
	FROM   epic.eh_booking_custody_status bcs
	WHERE --bcs.booking_id = c.booking_id
	      MF_is_sentenced(booking_id) = 'YES'
	  AND bcs.booking_id = p_booking_id
	  AND bcs.custody_status_id = p_custody_status_id
    ORDER BY MF_Get_offense_date(booking_id) asc; 

	commit;

	MP_INC_charges_Batch(p_batch_id);	
END;        
/
