select
	id.OFFENDER_ID AS entity_id,
	pi.NAME_FAMILY as lastname,
	pi.NAME_FIRST  as firstname,
	NVL(NVL(to_char(epic.ef_epic_date_to_date(pi.DATE_OF_BIRTH),'MM/DD/YYYY'),
			to_char(epic.ef_epic_date_to_date(pi.BIRTH_DATE_APPROX),'MM/DD/YYYY')),
					'UNKNOWN_DOB') as DOB,
	decode(ei.imageref, null,null,
		'\\' || ev.volumeserver || '\F$\FTP\' || ev.volumepath || '\' || ei.imageref) as mugpath,
	decode(ep.CODE_GENDER,'_NOSP','U',ep.CODE_GENDER) as gender
from epic.EH_OFFENDER_IDS id,
	epic.EH_PERSON_IDENTITY pi,
	epic.eh_entity_person ep,
	epic.Epicvolume ev,
	epic.Epicimage ei,
	epic.Eh_entity_default_photo ph
where    id.entity_id = pi.entity_id
   and id.entity_id = ep.entity_id
   and  ei.imageref(+) = ph.photo_id
   and  ev.volumeid(+) = ei.volumeid
   and  ph.entity_id(+) = id.entity_id
   and  pi.code_name_type = 'MAS'
