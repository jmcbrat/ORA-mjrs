CREATE OR REPLACE
FUNCTION MF_charge_end_date_calc
( p_booking_id          IN VARCHAR2,
  p_action_time         IN DATE
) RETURN date AS

/*
	Purpose:		MJRS - Calculate the charge end date or release date
					
	Author:			Joe McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
                                ------------	 -------------	------------------------------------------
                                J. McBratnie     1/06/09        Created 
					                  
*/  
  CURSOR curAgy IS 
		select epic.ef_epic_date_to_date(bcs.date_start)
		from epic.eh_booking_custody_status bcs
		where bcs.booking_id = p_booking_id
		  and epic.ef_epic_date_to_date(action_time) > p_action_time
		order by epic.ef_epic_date_to_date(bcs.action_time) asc;  
		
v_date date;
BEGIN

  	OPEN curAgy;
  		BEGIN
	  		FETCH curAgy INTO v_date;
			if v_date is null then
				Select epic.ef_epic_date_to_date(ACTUAL_RELEASE)
				into v_date
				from epic.eh_release
				where booking_id = p_booking_id
				 and rownum = 1;    
	  		end if;
	  	end;
  	CLOSE curAgy;

  RETURN v_date;  
END MF_charge_end_date_calc;
/
