CREATE OR REPLACE
PROCEDURE MP_mjrs_charge_insert_log (
		p_batch_id          IN      VARCHAR2,
		p_booking_id        IN      VARCHAR2,
		p_charge_id         IN      INTEGER
	 )
		
IS
/*	
	Purpose:		insert offendertrak charge/status into mjrs batch log
					
	Author:			Joseph McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
					----------	 -------------	------------------------------------------
					J. McBratnie 10/17/08		Created 
                  
*/  
v_inc_trans varchar2(3);


BEGIN
	--insert into OFFTRK_IMPORT_CHARGE_LOG
	--dbms_output.put_line('Insert charge/status....');

	INSERT INTO OFFTRK_IMPORT_CHARGE_LOG 
	SELECT p_batch_id, OFFENDER_ID, CHARGE_ID, TRANSACTIONLOG_SEQ.nextval, sysdate, TRANSACTION_CODE, 
	       BOOKING_DATE, END_DATE, OFFTRK_DAYS_IN, DAYS_IN, ORIGINAL_CHARGE_AMT, ADJUSTED_CHARGE_AMT, 
	       PROJ_RELEASE_DATE, STATUS_START_DATE, STATUS_END_DATE, 
	       BOOKING_ID, IS_CASH_SETTLEMENT, IS_WORK_RELEASE
	 FROM CHARGES
	WHERE booking_id = p_booking_id
	  AND charge_id = p_charge_id;
	
	
	COMMIT;
	 --    dbms_output.put_line('charge_status');

END;
/
