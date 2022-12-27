CREATE OR REPLACE
   	--
	--
	--	function if newly sentenced charges   --not used
	--
	--
    FUNCTION new_sentence
	(p_entity_id	in		EPIC.eh_booking.entity_id%type)   
	
	 /*	
		System: 		Macomb MJRS
		Purpose:		Returns Y if inmate an is newly sentenced.
		                
		Author:			Joe McBratnie
		
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 10/01/08		Created 
						
						
	*/       


	RETURN VARCHAR2 AS
	
	vActive VARCHAR2(1);
	  
	BEGIN          
		vActive := 'N';
	    BEGIN
			select 'Y' into vActive 
			from epic.eh_active_booking ab,
			     epic.eh_charge c,
			     epic.eh_Sentence s,
			     OFFTRK_IMPORT_BATCHES OTB
			where ab.booking_id = c.booking_id
			  and ab.entity_id = p_entity_id
			  and c.sentence_id = s.sentence_id
			  and epic.ef_epic_date_to_date(s.DATE_ENTERED) between OTB.Import_date --sysdate-1 -- last batch date from mjrs tables
			                                                    and sysdate;
	    EXCEPTION
	    	when NO_DATA_FOUND then
				vActive := 'N';
	    	when OTHERS then
				vActive := 'N';
		END;    		
				
	RETURN vActive;
	END;
    --


	--
	--	Procedure release old charge/status        can be removed -- not used
	--
	PROCEDURE MP_mjrs_charge_release 
	     (
			p_batch_id          IN      number,
 			p_offender_id       IN		VARCHAR2,
 			p_booking_id		IN		VARCHAR2,
 			p_custody_status_id IN      VARCHAR2,
	        p_status_start		IN		DATE,
			p_Status			   OUT	VARCHAR2
		 )
	
	IS
	/*	
		Purpose:		close charge/status in mjrs
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 10/14/08		Created  
						J. McBratnie 10/27/08		Update parameter list and function to fix bug 
						                            and reduce processing tim
	                  
	*/  
	v_charge_id         number;
	 vt_charge_id 		NUMBER;
	 v_trancode 		varchar2(20);
	 v_amt	     		number;
	 v_end_date 		date;
	 v_status_end		date;
	 
	BEGIN
	    p_Status := 'TRUE';
		-- set the max charge_id for reference later.  
	 	BEGIN
			SELECT c.charge_detail_id, c.status_end_date
			INTO   v_charge_id, v_status_end
			FROM CHARGE_DETAIL c
			WHERE c.offender_id = p_offender_id
			  and c.booking_id = p_booking_id
			  AND c.charge_detail_id = ( SELECT MAX(c2.charge_detail_id)
										   FROM CHARGE_DETAIL c2
									      WHERE c2.offender_id = c.offender_id --'108121' --p_offender_id
									        AND c2.booking_id = c.booking_id
							  		   GROUP BY c2.offender_id );	 	
		EXCEPTION when no_data_found then
			v_charge_id := 0;
		END;   
		
		--IF v_charge_id > 0 THEN -- update old charge/status
	 
			BEGIN
				UPDATE CHARGE_DETAIL 
				  SET (STATUS_END_DATE, OFFTRK_DAYS_IN, CHARGE_AMT, MODIFIED_BY, MODIFIED_DATE
				      ) = 
					(SELECT --p_status_start,
					     p_status_start-1,
						 CEIL(p_status_start-status_start_date) as offdays_in,
		                 -- function to calc rent
		                 MF_Get_Rent_trans_code(TRANSACTION_CODE ,
		                             CEIL(p_status_start-1-status_start_date)) as original_charge_amt,
						 0 as User_ID,
						 sysdate
					 FROM charge_detail --epic.eh_booking_custody_status bcs
					 WHERE offender_id = p_offender_id 
					   and charge_detail_id = v_charge_id --booking_id = p_booking_id    --- need to add booking_custody_Status_id to this update.... 
					) 
				WHERE offender_id = p_offender_id
				  AND charge_detail_id = v_charge_id
				  AND status_end_date IS NULL;  
			EXCEPTION WHEN no_data_found THEN
				 p_Status := 'FALSE';
			END;
			IF p_Status = 'TRUE' THEN			  
				MP_mjrs_charge_insert_log(p_batch_id, p_offender_id, v_charge_id);
			END IF;
			if gv_debug then
	        	dbms_output.put_line('release charge ' || p_status_start|| ' offender ' ||p_offender_id|| ' charge_id '|| v_charge_id);
			end if;
		commit;   
		
	END;    
	--	
	--
	--
	--	procedure to initate a batch process run
	--
	--
	PROCEDURE MP_mjrs_inital_load 
	     (
			p_run_date          IN      Date
		 )
			
	IS
	/*	
		Purpose:		Process the initial load into charge_detail.
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 12/03/08		Created
	                  
	*/ 
	
		v_last_run_date      date;
	v_run_date           date;
	v_batch_id           number;  
	v_status             varchar2(20);
	v_status_end         date;
	v_charge_detail_id   number(38);
	v_inmate_exists      varchar2(3);
	v_flag_open_charge   varchar2(3);
	vr_OFFENDER_ID		 varchar2(16);
	vr_BOOKING_ID        varchar2(16);
	vr_CUSTODY_STATUS_ID varchar2(16);
	vr_STATUS            varchar2(20);
	vr_ORDER_BY          number(8,0);
	vr_CUSTODY_STATUS    number(8,0);
	vr_STATUS_DATE       date;
	vr_STATUS_END        date;

	CURSOR process_list 
	IS
			SELECT distinct id.offender_id AS OFFENDER_ID,
			                b.booking_id   AS BOOKING_ID,
				            custody_status_id as CUSTODY_STATUS_ID,
			                'NEW MISSING'  AS STATUS,
			                0              AS ORDER_BY,
			                code_custody_status  AS CUSTODY_STATUS,
							to_Date(decode(epic.ef_epic_date_to_date(date_start),
							                                   null,
							                                   null,
							                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
			                null                 AS STATUS_END
			FROM   epic.eh_sentence s,
			       epic.eh_charge c,
			       epic.eh_booking b,
			       epic.eh_booking_custody_status bcs,
			       epic.eh_offender_ids id
			WHERE  b.booking_id = c.booking_id
			  AND  b.booking_id = bcs.booking_id
			  AND  c.sentence_id = s.sentence_id
			  AND  c.sentence_id is not null
			  AND  b.entity_id = id.entity_id
			  AND  not bcs.code_custody_status in ('2','3','5','11','12','13','40')
			  AND  NOT EXISTS (select 1
					           from inmates i
					           where id.offender_id = i.offender_id)
			UNION  -- newly status changes
				SELECT distinct id.offender_id,
				                bcs.booking_id ,
				                custody_status_id,
				                'STATUS UPDATE',
				                2 ,
				                code_custody_status,
								to_Date(decode(epic.ef_epic_date_to_date(date_start),
								                                   null,
								                                   null,
								                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
				                null AS STATUS_END
				FROM   epic.eh_booking_custody_status bcs,
				       epic.eh_booking b,
					   epic.eh_offender_ids id,
				       epic.eh_charge c
				WHERE  b.entity_id = id.entity_id
				  AND  b.booking_id = bcs.booking_id
				  AND  not bcs.code_custody_status in ('2','3','5','11','12','13','40')
				  AND  b.booking_id = c.booking_id
				  AND  c.sentence_id is not null        -- at least one charge sentenced
				  AND  epic.ef_epic_date_to_date(bcs.action_time) BETWEEN sysdate - 25 -- v_last_run_date
				                                                      AND p_run_date     -- epic.ef_epic_date_to_date(MACOMB.MCMB_FNT_INTERFACE_LASTRUN('GVT EXPORT'))
				order by 1,5;  -- was 1,4

	BEGIN
		-- process the inmates
		-- get the last run date to use in cursor above.
		SELECT max(import_date) 
		  INTO v_last_run_date
		  FROM OFFTRK_IMPORT_BATCHES;
		  
	     v_batch_id := Get_New_Batch();
	     v_charge_detail_id := 0;
	     COMMIT;
	   	FOR records in process_list
		LOOP    
			-- locate previous record and update the end date 
			--    v_charge_detail_id are set in this procedure for use in the 
			--    main IF structure and all record adds and updates.
			--  if start and end dates are equal then make zero days  
			--  Also sets the v_charge_detail_id  
			BEGIN
				SELECT NVL(max(charge_detail_id),0)
				  INTO v_charge_detail_id 
				  FROM CHARGE_DETAIL
				 WHERE booking_id = records.booking_id
				   AND STATUS_END_DATE is null;
		    EXCEPTION 
				when NO_DATA_FOUND then 
				    v_charge_detail_id := 0;
				when others then raise_application_error(-20011,'Charge details max record found');
		    END;
			if gv_debug = TRUE and gv_debug_inmate = records.offender_id THEN
				DBMS_OUTPUT.put_line(records.offender_id||' ' ||records.status_date||' ' ||records.status_end||' ' ||records.booking_id||' ' ||records.custody_status_id);
			end if;
			MP_MJRS_Enddate_charge_detail(records.offender_id, records.BOOKING_ID, records.STATUS_DATE, v_charge_detail_id);  
			 
 			-- Add/update inmate demographics
					-- check for inmate in system already, should be for all but new sentenced inmates 
			v_status := 'TRUE';
			-- is the inmate new?  or needs an update?
			IF (records.STATUS = 'NEW MISSING' /*or v_inmate_exists = 'NO'*/) THEN 					    

					MP_mjrs_inmate_insert(v_batch_id,records.offender_id,0,v_status);
	            INC_inmates_Batch(v_batch_id);
		    ELSIF (records.STATUS = 'STATUS UPDATE') THEN
				/*	  Create charge_detail row
					  Set "Inactive" status
					If charges row for this booking does not exist then 
						Create charges row
					End if
				*/
				mjrs_charge_add(   v_batch_id,
			                       records.offender_id,
			                       records.booking_id,
			                       records.custody_status_id,
		                           records.CUSTODY_STATUS,
			                       records.STATUS_DATE, -- start
			                       records.STATUS_END,
			                       v_charge_detail_id,  -- charge_detail_id max value set above
			                       v_status);
			ELSE
				dbms_output.put_line('invalid status: ' || records.STATUS);	
			END IF;	
			commit;
		END LOOP;
	END;


/
