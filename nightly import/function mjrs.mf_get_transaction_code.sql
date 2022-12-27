CREATE OR REPLACE
FUNCTION MF_Get_Transaction_Code
( p_code_custody_status IN VARCHAR2
) RETURN varchar2 AS

/*
	Purpose:		MJRS - Find the transaction code
					
	Author:			Joe McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
                                ------------	 -------------	------------------------------------------
                                J. McBratnie     10/16/08        Created 
					                  
*/  
v_trans varchar2(15);
BEGIN 
	
	--dbms_output.put_line('trans code based on :'||p_code_custody_status);
    BEGIN
		SELECT TRANSACTION_CODE 
		  INTO v_trans
	      FROM CHARGE_TYPE
	     WHERE p_code_custody_status = OFFTRK_CODE 
	       AND IS_ACTIVE = 'yes';
     EXCEPTION
	   	  WHEN NO_DATA_FOUND THEN
	              v_trans := '-'||p_code_custody_status; 
   END;
			
  RETURN v_trans;  
END MF_Get_Transaction_Code;
/
