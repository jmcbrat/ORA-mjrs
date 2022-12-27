CREATE OR REPLACE
FUNCTION MF_pp_GET_COLLECTION_BALANCE 
( OffenderId IN VARCHAR2
) RETURN NUMBER AS

/*
	Purpose:		MJRS - Get total collection balance for selected inmate
					
	Author:			Sue Dunn

	Change Log:		Changed By	 Date Modified	Change Made
                                ----------	 -------------	------------------------------------------
                                S. Dunn           10/13/08        Created 
					                  
*/  
colBal number;
BEGIN
   BEGIN
        select sum(nvl(TRANSACTION_AMT,0)) into colBal FROM pp_TRANSACTION_LOG
        WHERE (OFFENDER_ID = OffenderId and lower(IS_DELETED) = 'no'
        AND charge_id in (select charge_id from pp_charges where offender_id = OffenderId 
        and transaction_code like '5%'));
   EXCEPTION
    	when NO_DATA_FOUND then
              colBal := 0;
   END;    		
			
  RETURN nvl(colBal,0);  
END MF_pp_GET_COLLECTION_BALANCE;
/
