CREATE OR REPLACE
TRIGGER mti_active_booking
before  INSERT  ON EPIC.EH_active_booking
REFERENCING NEW AS NEW
FOR EACH ROW
--
--	trigger to signal the insert record to JIL
--  
/*	Purpose:		Macomb IVR and Inmate Locator - Creates the signal to request an insert into 
                    the remote database
					
	Author:			Joe McBratnie
	
	Change Log:		Changed By	  Date Modified		Change Made
					------------  -------------		---------------------------------
					J. MCBRATNIE  	12/26/06		Created   

*/ 
BEGIN       
     
	mpk_jil.signal(mpk_jil.cs_JIL_INMATE_alert,:NEW.ENTITY_ID);
	mpk_jil.signal(mpk_jil.cs_JIL_BOOKING_alert,:NEW.ENTITY_ID);  
	mpk_jil.signal(mpk_jil.cs_JIL_CHARGE_alert,:NEW.ENTITY_ID);  	
	
	RETURN;
END mti_active_booking;
/
