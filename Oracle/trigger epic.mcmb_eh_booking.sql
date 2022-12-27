CREATE OR REPLACE
TRIGGER MCMB_eh_booking
After update On EH_BOOKING

--  12/7/05  J McBratnie
--	A custom trigger for Macomb County.  When a booking is accepted we need to 
--  create the correct booking fees.  10.00 County fee and 2.00 state fee.
--  the create booking fees are contained in a procedure called: mcmb_ep_set_booking_fee
--  Other functionality can be added at a later time.  
--  

FOR EACH ROW
Declare
        cs_mod						constant varchar2(255) := 'macomb_eh_booking';
		p_result        			epic_col_types.number_9%type;
 		p_result_msg   	 			epic_col_types.varchar_255%type;

		v_entity_id					char(16);
		v_process					boolean := false;
		v_success					varchar2(3);

--	main procedure start
begin                          
--	ep_log_info ( cs_mod, 'I', -1, 'Started');

	p_result := 0;
	p_result_msg := null;                     
	
	v_entity_id := :new.ENTITY_ID;
	                                            
--	ep_log_info ( cs_mod, 'D', -1, 'old remove reason: ' || :old.code_removed_reason);
--	ep_log_info ( cs_mod, 'D', -1, 'new remove reason: ' || :new.code_removed_reason);       

	if :old.ACCEPT_DATE is null then
		if not :new.ACCEPT_DATE is null then
			v_process := true;
		end if;
	end if;
	
	if v_process = true then
		-- Insert the booking fees (10.00 fee and the 2.00 fee)
		epic.mcmb_ep_set_booking_fee(v_entity_id, v_success);

	end if;

	return;

exception
	when others then                  
		p_result_msg := substr(sqlerrm || ' - ' || cs_mod, 1, 255);
		p_result := -1;
		ep_log_info ( cs_mod, 'E', -1, p_result_msg);
		return;
end MCMB_eh_booking;
/
