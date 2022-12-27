CREATE OR REPLACE
FUNCTION MF_pp_GET_LEGAL_BALANCE
( OffenderId IN VARCHAR2
) RETURN NUMBER AS

/*
	Purpose:		MJRS - Get total legal balance for selected inmate
					
	Author:			Sue Dunn

	Change Log:		Changed By	 Date Modified	Change Made
                                ----------	 -------------	------------------------------------------
                                S. Dunn           10/13/08        Created 
					                  
*/  
legBal number;
BEGIN
   BEGIN
        select sum(nvl(TRANSACTION_AMT,0)) into legBal FROM pp_TRANSACTION_LOG
        WHERE (OFFENDER_ID = OffenderId and lower(IS_DELETED) = 'no'
        AND charge_id in (select charge_id from pp_charges where offender_id = OffenderId 
        and transaction_code = '4235'));
   EXCEPTION
    	when NO_DATA_FOUND then
              legBal := 0;
   END;    		
			
  RETURN nvl(legBal,0);  
END MF_pp_GET_LEGAL_BALANCE;
/
