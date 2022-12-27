CREATE OR REPLACE
FUNCTION        mf_pb_loginok
	 (	vUserID     IN     EPIC.epic_user_names.user_id%type)

/*
Purpose:		Returns a 'Y' value if a user has login rights

Author:			Joe McBratnie

Change Log:		Changed By  	Date Modified	Change Made
				------------	-------------	------------------------------------------
				J. McBratnie	02/14/07     	Created					
*/
RETURN VARCHAR2 AS 
	CURSOR curAdmin IS     	
		SELECT 	'Y'
		FROM 	EPIC.epic_user_names n,
    			EPIC.epic_user_roles r
		WHERE	n.user_int_id = r.user_int_id
				and EPIC.ef_epic_date_to_date(r.date_end) >= sysdate
				and EPIC.ef_epic_date_to_date(r.date_start) <= sysdate
				and UPPER(r.role_code) in('BOOKING OFFICER','JAIL OFFICE STAFF','ENTERPRISE ADMINISTRATOR')
	  			and n.user_id = UPPER(vUserID); 
	  			
vAdmin	varchar2(1); 

BEGIN
	OPEN curAdmin;
		FETCH curAdmin INTO vAdmin;
	CLOSE curAdmin;

	RETURN NVL (vAdmin,'N');

END;
/
