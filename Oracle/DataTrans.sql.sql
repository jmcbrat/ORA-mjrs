

select mf_mug_with_Path_entity('0IR6B8O000USJ1IR') from dual;


select * from MT_EH_ENTITY_PHOTO;

select 'ftp://' || ev.volumeserver ||'/'|| ev.volumepath || '/' || ei.imageref as mugpath,
nm.*
from EPIC.EPICVOLUME ev,
     macomb.MT_EPICIMAGE ei,
     macomb.MT_EH_NIST_MUGSHOT nm,
     macomb.MT_EH_ENTITY_PHOTO dp
where ev.volumeid(+) = ei.volumeid
and ei.imageref = nm.photo_id
and ei.imageref = dp.photo_id;


SELECT 'ftp://' || ev.volumeserver ||'/'|| ev.volumepath || '/' || ei.imageref as mugpath
    	FROM	epic.Epicvolume ev,
				epic.Epicimage ei,
				epic.Eh_entity_default_photo ph,
				epic.eh_entity_photo ep
		WHERE
				ei.imageref = ph.photo_id(+)
	  	  AND   ev.volumeid = ei.volumeid
		  AND   ph.entity_id = p_entity_id
		  AND   ep.photo_id = ei.imageref;
