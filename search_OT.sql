select  id.entity_id, id.offender_id,
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
             pi.name_family like 'SM%'
         and pi.NAME_FIRST like '%J%'
         and pi.social_security_number like replace('%','-','')
         and epic.ef_epic_date_to_date(pi.date_of_birth) like '%06/28/1985%' --
         and id.offender_id like '%'
        );



