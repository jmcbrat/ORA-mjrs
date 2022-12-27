CREATE OR REPLACE
PROCEDURE MP_mjrs_inmate_lk (
		p_fname				IN		VARCHAR2,
		p_lname				IN		VARCHAR2,
		p_offender_id       IN		VARCHAR2,
		p_ssn               IN		VARCHAR2,
		p_dob               IN		date,
		v_cur				   OUT	mjrs.epp_generic_ref_cursor.ref_cursor
	 )
		
IS
/*	
	Purpose:		Look up an active inmate in offendertrak to pull to gvt
					
	Author:			Joseph McBratnie

	Change Log:		Changed By	 Date Modified	Change Made
					----------	 -------------	------------------------------------------
					J. McBratnie 09/29/08		Created
*/                                    
v_dob varchar2 (12);

BEGIN    
	v_dob := '%' || to_char(v_DOB) || '%';

	open v_cur for 
		select  id.offender_id,
				pi.NAME_FAMILY as lastname,
				pi.NAME_FIRST  as firstname,
				pi.NAME_OTHER  as othername,
				MACOMB.mcmb_fnt_DOB_gvt_format(id.entity_id) as DOB,
				substr(pi.social_security_number,1,3)||'-'||substr(pi.social_security_number,4,2)||'-'||substr(pi.social_security_number,6,4) as SSN
		from    epic.eh_offender_ids id,
		        epic.EH_PERSON_IDENTITY pi
		where   epic.ef_is_active_booking(id.entity_id)='TRUE'
		  and   id.entity_id = pi.entity_id
		  and   macomb.mf_jil_master_alias(id.entity_id, pi.IDENTITY_ID) =1
		  and   (     -- data inputs from GUI
		             pi.name_family like p_lname ||'%'
		         and pi.NAME_FIRST like p_lname ||'%'
		         and pi.social_security_number like replace( '%' || p_ssn || '%','-','')
		         and epic.ef_epic_date_to_date(pi.date_of_birth) like v_dob --
		         and id.offender_id like p_offender_id ||'%'
		        );

END;   
/
