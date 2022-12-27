CREATE OR REPLACE
PACKAGE        mpk_avgdailypop_jdm
IS

/*	
Purpose:		Used by the Jail Administration to return the Average Daily Population for the 
				selected time period. This package is called by procedure ****** to run as a Crystal
				report through Offendertrak

Author:			Rachel Stuve

Change Log:		Changed By	Date Modified	Change Made
		 		----------	-------------	------------------------------------------
				R. Stuve	02/05/07		Created   
*/


--procedure to get the total population for the entire date range
PROCEDURE Calculate 
	(p_StartDate		in		EPIC.eh_housing_assignments.action_time%type,
	 p_EndDate			in		EPIC.eh_housing_assignments.action_time%type,
	 p_Cur 				in   OUT 	epic.epp_generic_ref_cursor.ref_cursor);
END;
/
