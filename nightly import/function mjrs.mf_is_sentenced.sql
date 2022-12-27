CREATE OR REPLACE
FUNCTION MF_is_sentenced
( p_booking_id          IN VARCHAR2
) RETURN varchar2 AS

/*
	Purpose:		MJRS - Calculate the offense date
					
	Author:			Joe McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
                                ------------	 -------------	------------------------------------------
                                J. McBratnie     10/16/08        Created 
					                  
*/  
v_sentenced varchar2(3);
BEGIN
    BEGIN
		SELECT DECODE(count(*),0,'NO','YES') 
		INTO v_sentenced
		FROM epic.eh_charge
		WHERE booking_id = p_booking_id
		  AND NOT sentence_id IS NULL;
   EXCEPTION
	    	when NO_DATA_FOUND then
	              v_sentenced := 'NO';
	END;			
  RETURN v_sentenced;  
END MF_is_sentenced;
/
