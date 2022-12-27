CREATE OR REPLACE
FUNCTION mf_new_sentence
	(p_entity_id	in		EPIC.eh_booking.entity_id%type)   
	
 /*	
	System: 		Macomb MJRS
	Purpose:		Returns Y if inmate an is newly sentenced.
	                
	Author:			Joe McBratnie
	
	Change Log:		Changed By	 Date Modified	Change Made
					----------	 -------------	------------------------------------------
					J. McBratnie 10/01/08		Created 
					
					
*/       


RETURN VARCHAR2 AS

vActive VARCHAR2(1);
  
BEGIN          
	vActive := 'N';
    BEGIN
		select 'Y' into vActive 
		from epic.eh_active_booking ab,
		     epic.eh_charge c,
		     epic.eh_Sentence s,
		     OFFTRK_IMPORT_BACTHES OTB
		where ab.booking_id = c.booking_id
		  and ab.entity_id = p_entity_id
		  and c.sentence_id = s.sentence_id
		  and epic.ef_epic_date_to_date(s.DATE_ENTERED) between OTB.Import_date --sysdate-1 -- last batch date from mjrs tables
		                                                    and sysdate;
    EXCEPTION
    	when NO_DATA_FOUND then
			vActive := 'N';
    	when OTHERS then
			vActive := 'N';
	END;    		
			
RETURN vActive;
END;
--JDM

/
