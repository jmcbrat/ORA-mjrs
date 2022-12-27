CREATE OR REPLACE
FUNCTION MF_pp_GET_CURRENT_BAL_ID 
( OffenderId IN VARCHAR2,
  ChargeId IN NUMBER
) RETURN number AS

/*
	Purpose:		MJRS - Get total charge balance for selected inmate
					
	Author:			Sue Dunn

	Change Log:		Changed By	 Date Modified	Change Made
                                ----------	 -------------	------------------------------------------
                                S. Dunn           10/13/08        Created 
					                  
*/  
curBal number;
BEGIN
   BEGIN
	select SUM(nvl(TRANSACTION_AMT,0)) into curBal
        from pp_TRANSACTION_LOG
        where OFFENDER_ID = OffenderId AND CHARGE_ID = ChargeId AND lower(IS_DELETED) = 'no';
   EXCEPTION
    	when NO_DATA_FOUND then
              curBal := 0;
   END;    		
			
  RETURN nvl(curBal,0);  

END MF_pp_GET_CURRENT_BAL_ID;
/
