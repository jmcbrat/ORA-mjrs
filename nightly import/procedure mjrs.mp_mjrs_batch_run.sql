CREATE OR REPLACE
PROCEDURE MP_mjrs_Batch_Run (
		p_run_date          IN      Date
	 )
		
IS
/*	
	Purpose:		Build and process a batch of changes from OT
					
	Author:			Joseph McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
					----------	 -------------	------------------------------------------
					J. McBratnie 10/17/08		Created 
                  
*/ 
v_last_run_date date;
v_run_date date;
v_batch_id number;  
v_status varchar2(20);
v_inmate_exists varchar2(3);

CURSOR process_list 
	IS
	   -- Add any inmates that are not in the system from previous runs.
	   -- Normally, this should be 0 row for this part of the union
		SELECT distinct id.offender_id AS OFFENDER_ID,
		                b.booking_id   AS BOOKING_ID,
			            custody_status_id as CUSTODY_STATUS_ID,
		                'NEW MISSING'  AS STATUS,
		                0              AS ORDER_BY,
		                code_custody_status  AS CUSTODY_STATUS,
		                epic.ef_epic_date_to_date(date_start)  AS STATUS_DATE,
		                null                 AS STATUS_END
		FROM   epic.eh_sentence s,
		       epic.eh_charge c,
		       epic.eh_active_booking b,
		       epic.eh_booking_custody_status bcs,
		       epic.eh_offender_ids id
		WHERE  b.booking_id = c.booking_id
		  AND  b.booking_id = bcs.booking_id
		  AND  c.sentence_id = s.sentence_id
		  AND  c.sentence_id is not null
		  AND  b.entity_id = id.entity_id
		  AND  NOT EXISTS (select 1
				           from inmates i
				           where id.offender_id = i.offender_id)
		UNION  -- create a new inmate
			SELECT distinct id.offender_id AS OFFENDER_ID,
			                b.booking_id   AS BOOKING_ID,
			                custody_status_id,
			                'NEW SENTENCE' AS STATUS,
			                1              AS ORDER_BY,
			                code_custody_status  AS CUSTODY_STATUS,
			                epic.ef_epic_date_to_date(date_start)  AS STATUS_DATE,
			                null                AS STATUS_END
				FROM   epic.eh_sentence s,
				       epic.eh_charge c,
				       epic.eh_active_booking b,
				       epic.eh_booking_custody_status bcs,
				       epic.eh_offender_ids id
				WHERE  b.booking_id = c.booking_id
				  AND  b.booking_id = bcs.booking_id
				  AND  c.sentence_id = s.sentence_id
				  AND  b.entity_id = id.entity_id
				  AND  epic.ef_epic_date_to_date(date_entered) BETWEEN to_date('04/01/2007 10:05:51')
				  											       AND sysdate
		UNION  -- newly release inmates
			SELECT distinct id.offender_id,
			                b.booking_id ,
			                '',
			                'RELEASE INMATE',
			                3,
			                '',
			                null,
			                epic.ef_epic_date_to_date(ACTUAL_RELEASE)
			FROM   epic.eh_release r,
			       epic.eh_booking b,
			       epic.eh_offender_ids id,
			       epic.eh_charge c
			WHERE  b.booking_id = r.booking_id
			  AND  b.entity_id = id.entity_id
			  AND  b.booking_id = c.booking_id
			  AND  c.sentence_id is not null
			  AND  epic.ef_epic_date_to_date(r.actual_release) BETWEEN to_date('04/01/2007 10:05:51')
			                                                       AND sysdate
		UNION  -- newly status changes
			SELECT distinct id.offender_id,
			                bcs.booking_id ,
			                custody_status_id,
			                'STATUS UPDATE',
			                2 ,
			                code_custody_status,
			                epic.ef_epic_date_to_date(date_start)  AS STATUS_DATE,
			                null AS STATUS_END
			FROM   epic.eh_booking_custody_status bcs,
			       epic.eh_active_booking b,
				   epic.eh_offender_ids id,
			       epic.eh_charge c
			WHERE  b.entity_id = id.entity_id
			  AND  b.booking_id = bcs.booking_id
			  AND  b.booking_id = c.booking_id
			  AND  c.sentence_id is not null        -- at least one charge sentenced
			  --AND  bcs.code_custody_status <>'3'    -- PAROLEE  4208
			  AND  epic.ef_epic_date_to_date(bcs.action_time) BETWEEN to_date('04/01/2007 10:05:51')
			                                                      AND sysdate
			order by 1,4;                                                       ---    need to add booking_custody_Status_id to this update....


BEGIN               
	-- get the last run date to use in cursor above.
	SELECT max(import_date) 
	  INTO v_last_run_date
	  FROM OFFTRK_IMPORT_BACTHES;
	  
     v_batch_id := MF_Get_New_Batch();
     
	-- add new inmates (newly sentenced)
	-- update inmates
	-- release inmates               
   	FOR records in process_list
	LOOP  
		-- check for inmate in system already, should be for all but new sentenced inmates 
		BEGIN
			SELECT 'YES' INTO v_inmate_exists FROM INMATES i WHERE i.offender_id = records.offender_id;  
		EXCEPTION WHEN no_data_found THEN
			-- Inmate not in system, insert please.
			v_inmate_exists := 'NO';
		END;
		IF records.STATUS = 'NEW SENTENCE' THEN  
			-- Insert demographics
			-- update any previous status for this inmates booking
			v_status := 'no';
 			--dbms_output.put_line('new sent'); 
 			IF v_inmate_exists = 'NO' THEN
				MP_mjrs_inmate_insert(v_batch_id,records.offender_id,-1,v_status);
			ELSE
				MP_mjrs_inmate_update(v_batch_id,records.offender_id,-1,records.CUSTODY_STATUS,v_status);  -- needs to be created
			END IF; 
            MP_INC_inmates_Batch(v_batch_id);
		END IF;            

		MP_mjrs_charge_maint(v_batch_id,
	                          records.offender_id,
	                          records.booking_id,
	                          records.custody_status_id,
	                          records.status, 
	                          records.CUSTODY_STATUS,
	                          records.STATUS_DATE, -- start
	                          records.STATUS_END,
	                          v_status);
 		commit;
 		mp_inc_batch(v_batch_id);
 		
	END LOOP;
END;
/
