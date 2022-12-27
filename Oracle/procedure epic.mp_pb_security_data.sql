CREATE OR REPLACE
PROCEDURE MP_PB_Security_data
	 (	vUserID     IN              EPIC.EPIC_USER_NAMES.USER_ID%type,
	    vCur 			out      	EPIC.epp_generic_ref_cursor.ref_cursor)
		
IS

 /*
	Purpose:		Used for pulling the data needed for the security Module.


	Author:			Joe McBratnie

	Change Log:		Changed By  	Date Modified	Change Made
					------------	-------------	------------------------------------------
					J. McBratnie    12/14/2006      Created  
					R. Stuve		01/04/07		Added sysdate check, mf_pb_security function
					J. McBratnie    02/14/07        Added loging ok
						
*/
 
 
BEGIN     
	OPEN vCur FOR
          	SELECT n.user_id,
			       n.user_int_id,
			       n.encrypted_password,
			       n.user_name_first,
			       n.user_name_last,
				   MACOMB.mf_pb_security(vUserID) Command,
				   MACOMB.mf_pb_loginok(vUserID) Login
			FROM   EPIC.epic_user_names n,
			       EPIC.epic_user_roles r
			WHERE n.user_int_id = r.user_int_id
  	              and n.user_id = UPPER(vUserID)
  	              and EPIC.ef_epic_date_to_date(r.date_end) >= sysdate
				  and EPIC.ef_epic_date_to_date(r.date_start) <= sysdate
				  and rownum = 1 ;     
END;
/
