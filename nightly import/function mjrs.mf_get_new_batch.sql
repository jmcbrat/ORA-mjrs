CREATE OR REPLACE
FUNCTION MF_Get_New_Batch
 RETURN NUMBER AS

/*
	Purpose:		MJRS - Create a new batch for importing data
					
	Author:			Joe McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
                                ------------	 -------------	------------------------------------------
                                J. McBratnie     10/16/08        Created 
					                  
*/  
v_batch_id number;

BEGIN
    
	INSERT 
	  INTO OFFTRK_IMPORT_BACTHES
           (batch_id, IMPORT_DATE, TRANSACTIONS)
    VALUES
           (import_batches.nextval,
            sysdate,
            0 
           );

	select import_batches.currval into v_batch_id from dual;
  
  RETURN v_batch_id;  
END MF_Get_New_Batch;
/
