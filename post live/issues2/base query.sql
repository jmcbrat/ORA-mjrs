			SELECT distinct id.offender_id AS OFFENDER_ID,
			                b.booking_id   AS BOOKING_ID,
				            custody_status_id as CUSTODY_STATUS_ID,
			                'NEW MISSING'  AS STATUS,
			                0              AS ORDER_BY,
			                bcs.code_custody_status  AS CUSTODY_STATUS,
							to_Date(decode(epic.ef_epic_date_to_date(date_start),
							                                   null,
							                                   null,
							                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
			                null                 AS STATUS_END
			FROM   epic.eh_sentence s,
			       epic.eh_charge c,
			       epic.eh_booking b,
			       epic.eh_booking_custody_status bcs,
			       epic.eh_offender_ids id
			WHERE  b.booking_id = c.booking_id
			  AND  b.booking_id = bcs.booking_id
			  AND  c.sentence_id = s.sentence_id
			  AND  c.sentence_id is not null
			  AND  b.entity_id = id.entity_id
			  AND  not bcs.code_custody_status in ('2','3','5','11','12','13','40')
			  AND  NOT EXISTS (select 1
					           from pp_inmates i
					           where id.offender_id = i.offender_id)
			UNION  -- create a new inmate
				SELECT distinct id.offender_id AS OFFENDER_ID,
				                b.booking_id   AS BOOKING_ID,
				                custody_status_id,
				                'NEW SENTENCE' AS STATUS,
				                1              AS ORDER_BY,
				                bcs.code_custody_status  AS CUSTODY_STATUS,
								to_Date(decode(epic.ef_epic_date_to_date(date_start),
								                                   null,
								                                   null,
								                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
				                null                AS STATUS_END
					FROM   epic.eh_sentence s,
					       epic.eh_charge c,
					       epic.eh_booking b,
					       epic.eh_booking_custody_status bcs,
					       epic.eh_offender_ids id
					WHERE  b.booking_id = c.booking_id
					  AND  b.booking_id = bcs.booking_id
 					  AND  not bcs.code_custody_status in ('2','3','5','11','12','13','40')
					  AND  c.sentence_id = s.sentence_id
					  AND  b.entity_id = id.entity_id
					  AND  epic.ef_epic_date_to_date(date_entered) BETWEEN to_date('12/09/2008')
					  											       AND sysdate
			UNION  -- newly release inmates
				SELECT distinct id.offender_id,
				                b.booking_id ,
				                custody_status_id,
				                'RELEASE INMATE',
				                4,                    -- note was 3
				                bcs.code_custody_status,
								to_Date(decode(epic.ef_epic_date_to_date(date_start),
								                                   null,
								                                   null,
								                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
								to_Date(decode(epic.ef_epic_date_to_date(ACTUAL_RELEASE),null,null,to_char(epic.ef_epic_date_to_date(ACTUAL_RELEASE), 'mm/dd/yyyy')||' 23:59:59')) as status_end
				FROM   epic.eh_booking_custody_status bcs,
				       epic.eh_release r,
				       epic.eh_booking b,
				       epic.eh_offender_ids id,
				       epic.eh_charge c
				WHERE  b.booking_id = r.booking_id
				  AND  b.entity_id = id.entity_id
				  AND  b.booking_id = c.booking_id
				  AND  b.booking_id = bcs.booking_id
				  AND  not bcs.code_custody_status in ('2','3','5','11','12','13','40')
				  AND  c.sentence_id is not null        -- at least one charge sentenced
				  AND  epic.ef_epic_date_to_date(r.actual_release) BETWEEN to_date('12/09/2008')
				                                                       AND sysdate
			UNION  -- new work releases (require special handling)
				SELECT distinct id.offender_id,
				                b.booking_id ,
				                custody_status_id,
				                'WORK RELEASE',
				                3,
				                code_custody_status,
								to_Date(decode(epic.ef_epic_date_to_date(date_start),
								                                   null,
								                                   null,
								                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
						       null as status_end
				FROM   epic.eh_booking b,
				       epic.eh_booking_custody_status bcs,
				       epic.eh_offender_ids id,
				       epic.eh_charge c
				WHERE  b.booking_id = bcs.booking_id
				  AND  b.entity_id = id.entity_id
				  AND  b.booking_id = c.booking_id
				  AND  bcs.code_custody_status in ('5')    -- work release only.
				  AND  c.sentence_id is not null
				  AND  epic.ef_epic_date_to_date(bcs.action_time) BETWEEN  to_date('12/09/2008')
				                                                      AND sysdate
			UNION  -- newly status changes
				SELECT distinct id.offender_id,
				                bcs.booking_id ,
				                custody_status_id,
				                'STATUS UPDATE',
				                2 ,
				                bcs.code_custody_status,
								to_Date(decode(epic.ef_epic_date_to_date(date_start),
								                                   null,
								                                   null,
								                                   to_char(epic.ef_epic_date_to_date(date_start), 'mm/dd/yyyy')||' 00:00:00')) as STATUS_DATE,
				                null AS STATUS_END
				FROM   epic.eh_booking_custody_status bcs,
				       epic.eh_booking b,
					   epic.eh_offender_ids id,
				       epic.eh_charge c
				WHERE  b.entity_id = id.entity_id
				  AND  b.booking_id = bcs.booking_id
				  AND  not bcs.code_custody_status in ('2','3','5','11','12','13','40')
				  AND  b.booking_id = c.booking_id
				  AND  c.sentence_id is not null        -- at least one charge sentenced
				  AND  epic.ef_epic_date_to_date(bcs.action_time) BETWEEN  to_date('12/09/2008')
				                                                      AND sysdate
				order by 2,7,5;  -- was 1,4
