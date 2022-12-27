CREATE OR REPLACE
FUNCTION MF_Get_Rent
( p_code_custody_status IN VARCHAR2,
  p_number_of_days      IN number
) RETURN NUMBER AS

/*
	Purpose:		MJRS - Calculate the rent based on status
					
	Author:			Joe McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
                                ------------	 -------------	------------------------------------------
                                J. McBratnie     10/16/08        Created 
					                  
*/  
v_rent number;
BEGIN
   
	SELECT DAILY_RATE*p_number_of_days 
	  INTO v_rent
      FROM CHARGE_TYPE
     WHERE p_code_custody_status = OFFTRK_CODE 
       AND IS_ACTIVE = 'yes';
       
   EXCEPTION
    	when NO_DATA_FOUND then
              v_rent := 0;
			
  RETURN nvl(v_rent,0);  
END MF_Get_Rent;
/
