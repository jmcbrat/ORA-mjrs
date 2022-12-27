CREATE OR REPLACE
FUNCTION MF_INC_Batch  ( p_batch_id IN number)
 RETURN varchar2 AS

/*
	Purpose:		MJRS - Create a new batch for importing data
					
	Author:			Joe McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
                                ------------	 -------------	------------------------------------------
                                J. McBratnie     10/16/08        Created 
					                  
*/  
v_status varchar2(3);
v_trans number;

BEGIN
    v_status := 'yes';
 --   dbms_output.put_line(p_batch_id) ; 
    
    select transactions into v_trans from OFFTRK_IMPORT_BACTHES where batch_id = p_batch_id ; 
    
    v_trans := v_trans + 1; 
    
	UPDATE OFFTRK_IMPORT_BACTHES
       SET TRANSACTIONS = v_trans
    where batch_id = p_batch_id;
    commit;
  RETURN NVL(v_status,'yes');  
END MF_INC_Batch;
/
