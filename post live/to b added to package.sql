CREATE OR REPLACE
 	--
	--	Procedure add trans_log
	--
	PROCEDURE MP_mjrs_trans_log 
	     (
			p_BATCH_ID				IN VARCHAR2, 
			p_OFFENDER_ID			IN VARCHAR2, 
			p_CHARGE_ID				IN number, 
			p_TRANSACTION_SEQ		IN number, 
			p_transaction_code		IN varchar2, 
			p_amount				IN number, 
			p_update_date			IN date
		 )
			
	IS
	/*	
		Purpose:		insert offendertrak transaction_log into mjrs batch log
						
		Author:			Joseph McBratnie
	
		Change Log:		Changed By	 Date Modified	Change Made
						----------	 -------------	------------------------------------------
						J. McBratnie 1/2/09 		Created 
	                  
	*/  
	v_inc_trans varchar2(3);
	
	
	BEGIN
		--insert into OFFTRK_IMPORT_CHARGE_LOG
		if gv_debug then
			dbms_output.put_line('Insert trans_log....'||p_offender_id ||', '||p_charge_id);
		END IF;
		INSERT INTO offtrk_import_tran_log 
		(BATCH_ID, OFFENDER_ID, CHARGE_ID, TRANSACTION_SEQ, transaction_code, amount, update_date)
		select p_BATCH_ID, p_OFFENDER_ID, p_CHARGE_ID, p_TRANSACTION_SEQ, p_transaction_code, p_amount, p_update_date
		from dual;
		
		
		COMMIT;  
 	END;
	--	
/
