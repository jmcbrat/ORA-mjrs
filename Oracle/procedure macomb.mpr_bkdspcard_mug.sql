CREATE OR REPLACE
PROCEDURE        mpr_BkDspCard_mug
	(	vCur 			out 	EPIC.epp_generic_ref_cursor.ref_cursor,
		p_EntityID		in		EPIC.eh_entity_person.entity_id%type,
		p_UserID		in		EPIC.epic_user_names.user_int_id%type
	)
		
IS
/*	
	Form Usage: 	CRSTL.XX60
	Crystal: 		BkDispCard.rpt
	Purpose:		To notify booking to prepare an inmate for release, along with the information
					needed to process the release
					
					Mug example: macomb.mf_mug_with_Path_entity('0IR6B8O000USJ1IR')  Paste results of 
					             this field into IE

	Author:			Rachel Stuve

	Change Log:		Changed By	Date Modified	Change Made
					----------	-------------	------------------------------------------
					R. Stuve    03/15/06		Created  
					J.McBratnie 02/20/2007      Added mug
*/
BEGIN

	OPEN vCur FOR
    	SELECT	EPIC.ef_offender_id(b.entity_id) as InmateNum,
				MACOMB.mcmb_fnt_alphabin_current(b.entity_id) as PropertyNum,
				EPIC.ef_offender_cell(b.entity_id) as RoomNum,
				EPIC.ef_offender_1st_last_name(b.entity_id) as InmateName,
				MACOMB.mcmb_fnt_primarycharge(b.booking_id) as Offense,
				EPIC.ef_get_username1stlast(p_UserID) as ReleasedBy,     --<input prompt based on current user> 
				--Orders of (Free text)
				--ReasonReleased (Free text)
				--ReleasedTo (Free text)
				--Received by (Signature)
				to_char(sysdate, 'MM/DD/YYYY') as DateOut,
				--Time Out (Free text)
				to_char(EPIC.ef_epic_date_to_date(bk.start_date), 'MM/DD/YYYY') as DateIn,
				to_char(EPIC.ef_epic_date_to_date(bk.start_date), 'HH12:MI AM') as TimeIn,
				--Remarks (Free text)
				MACOMB.mcmb_fnt_inmatefunds(b.entity_id) as Money,
				mf_mug_with_Path_entity(p_EntityID) as mug

		FROM	EPIC.eh_active_booking b,
				EPIC.eh_booking bk

		WHERE	b.booking_id = bk.booking_id
				and b.entity_id = p_EntityID;  --<input prompt based on current inmate>   

END;   
/
