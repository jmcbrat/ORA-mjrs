CREATE OR REPLACE
FUNCTION MF_pp_GET_CURRENT_BALANCE
( OffenderId IN VARCHAR2
) RETURN NUMBER AS

/*
	Purpose:		MJRS - Get total current balance for selected inmate
					
	Author:			Sue Dunn

	Change Log:		Changed By	 Date Modified	Change Made
                                ----------	 -------------	------------------------------------------
                                S. Dunn           10/13/08        Created 
					                  
*/  
curBal number;
BEGIN
   BEGIN
       select sum(nvl(TRANSACTION_AMT,0)) into curBal FROM pp_TRANSACTION_LOG
        WHERE (OFFENDER_ID = OffenderId and lower(IS_DELETED) = 'no'
        AND charge_id in (select charge_id from pp_charges where offender_id = OffenderId 
        and transaction_code != '4235' and transaction_code not like '5%'));
   EXCEPTION
    	when NO_DATA_FOUND then
              curBal := 0;
   END;    		
			
  RETURN nvl(curBal,0);  
END MF_pp_GET_CURRENT_BALANCE;
/
