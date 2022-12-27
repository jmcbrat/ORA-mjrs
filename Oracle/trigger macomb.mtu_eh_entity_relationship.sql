CREATE OR REPLACE
TRIGGER mtu_EH_ENTITY_RELATIONSHIP
before UPDATE ON EPIC.EH_ENTITY_RELATIONSHIP
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
     
	mpk_jil.signal(mpk_jil.cs_JIL_INMATE_alert,:NEW.ENTITY_ID);
	mpk_jil.signal(mpk_jil.cs_JIL_ALIAS_alert,:NEW.ENTITY_ID);
	mpk_jil.signal(mpk_jil.cs_JIL_VISITOR_alert,:NEW.ENTITY_ID);
	RETURN;
END mtu_EH_ENTITY_RELATIONSHIP;
/
