CREATE OR REPLACE
TRIGGER mtu_eh_booking_holds
before UPDATE ON EPIC.EH_booking_holds
REFERENCING NEW AS NEW
FOR EACH ROW
--
--	trigger to signal the insert record to JIL
--  
/*	Purpose:		Macomb IVR and Inmate Locator - Creates the signal to request an update into 
                    the remote database
					
	Author:			Joe McBratnie
	
	Change Log:		Changed By	  Date Modified		Change Made
					------------  -------------		---------------------------------
					J. MCBRATNIE  	01/30/07		Created   

*/ 
BEGIN       
     
	mpk_jil.signal(mpk_jil.cs_JIL_CHARGE_alert,:NEW.BOOKING_ID);
	RETURN;
END mtu_eh_booking_holds;
/
