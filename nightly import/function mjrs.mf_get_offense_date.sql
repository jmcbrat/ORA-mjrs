CREATE OR REPLACE
FUNCTION MF_Get_offense_date
( p_booking_id          IN VARCHAR2
) RETURN date AS

/*
	Purpose:		MJRS - Calculate the offense date
					
	Author:			Joe McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
                                ------------	 -------------	------------------------------------------
                                J. McBratnie     10/16/08        Created 
					                  
*/  
v_offense_date date;
BEGIN
    BEGIN
		SELECT epic.ef_epic_date_to_date(offense_date) 
		  INTO v_offense_date
	      FROM epic.eh_charge
	     WHERE booking_id = p_booking_id
	       AND ROWNUM = 1
	       ORDER BY offense_date desc;
	       
	   EXCEPTION
	    	when NO_DATA_FOUND then
	              v_offense_date := NULL;
	END;			
  RETURN v_offense_date;  
END MF_Get_offense_date;
/
