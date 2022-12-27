CREATE OR REPLACE
FUNCTION mf_mug_name_entity
	(p_entity_id		in		EPIC.eh_entity_photo.Photo_ID%type)   
	
--Returns all of an inmate's alias names (one line, seperated by a '\')
	
RETURN  EPIC.epic_col_types.VARCHAR_2000%type
IS   

    CURSOR curPhotoPath IS
	    SELECT RTRIM(ei.imageref) ||'.JPG' as mugpath
    	FROM	epic.Epicvolume ev,
				epic.Epicimage ei,
				epic.Eh_entity_default_photo ph,
				epic.eh_entity_photo ep
		WHERE
				ei.imageref = ph.photo_id(+)
	  	  AND   ev.volumeid = ei.volumeid
		  AND   ph.entity_id = p_entity_id
		  AND   ep.photo_id = ei.imageref;

noPhotoLink EPIC.epic_col_types.VARCHAR_2000%type;
vPhotoLink EPIC.epic_col_types.VARCHAR_2000%type;

BEGIN  
	vPhotoLink := null;
	noPhotoLink := 'ftp://PHOTOFILE/PRODUCTION/NODATE/noimage.jpg';

	OPEN curPhotoPath;
	FETCH curPhotoPath INTO vPhotoLink;
	CLOSE curPhotoPath;                
	
	IF vPhotoLink IS NULL THEN
		vPhotoLink := noPhotoLink;
	END IF;
	
	RETURN vPhotoLink;
END;	

--JDM
/
