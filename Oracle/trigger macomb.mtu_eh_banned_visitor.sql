CREATE OR REPLACE
TRIGGER mtu_eh_banned_visitor
before UPDATE ON EPIC.eh_banned_visitor
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
					J. MCBRATNIE  	12/26/06		Created   

*/ 
BEGIN       
     
	mpk_jil.signal(mpk_jil.cs_JIL_BANNED_alert,:NEW.VISITOR_ID);
	RETURN;
END mtu_eh_banned_visitor;
/
