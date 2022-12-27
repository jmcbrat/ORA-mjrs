CREATE OR REPLACE
procedure MP_INC_charges_Batch  ( p_batch_id IN VARCHAR2)

/*
	Purpose:		MJRS - Create a new batch for importing data
					
	Author:			Joe McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
                                ------------	 -------------	------------------------------------------
                                J. McBratnie     10/16/08        Created 
					                  
*/ 
IS  
v_status varchar2(3);
v_trans number;

BEGIN   
    select CHARGES into v_trans from OFFTRK_IMPORT_BACTHES where batch_id = p_batch_id ; 
    
    v_trans := v_trans + 1; 
   
	UPDATE OFFTRK_IMPORT_BACTHES
       SET CHARGES = v_trans
    where batch_id = p_batch_id;
    commit;
--  RETURN NVL(v_status,'yes');  
END MP_INC_charges_Batch;
/
