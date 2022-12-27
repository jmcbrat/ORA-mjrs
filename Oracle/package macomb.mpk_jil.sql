CREATE OR REPLACE
package        MPK_JIL is
/*	Purpose:		Macomb JIL internet - This is the process to make the triggering of who gets copied and not.
	Process:		Register the request, signal the action in a trigger, create a job to run (that moves the 
					data from OT to JIL.  All procedures are included in this package to handle alert, signal, 
					and create job functionality.
					
					The selected data has its own procedures and functions that are more global in nature.
	                
					
	Author:			Joe McBratnie
	
	Change Log:		Changed By	  Date Modified		Change Made
					------------  -------------		---------------------------------
					J. MCBRATNIE  	08/15/06		Created 

*/ 	
	--
	--	8/15/2006 J McBratnie
	--
	--		This package contains the JIL interface procedures
	--		which can be called from various triggering events
	--
	--  
	cs_JIL_module			constant varchar2(255) := 'JIL';
	cs_JIL_ALIAS_alert		constant varchar2(255) := 'MCMB$JIL_ALIAS';
	cs_JIL_INMATE_alert		constant varchar2(255) := 'MCMB$JIL_INMATE';
	cs_JIL_CHARGE_alert		constant varchar2(255) := 'MCMB$JIL_CHARGE';
	cs_JIL_BOOKING_alert	constant varchar2(255) := 'MCMB$JIL_BOOKING';
	cs_JIL_SENTENCE_alert	constant varchar2(255) := 'MCMB$JIL_SENTENCE';
	cs_JIL_VISITOR_alert	constant varchar2(255) := 'MCMB$JIL_VISITOR';
	cs_JIL_BANNED_alert		constant varchar2(255) := 'MCMB$JIL_BANNED';
	cs_JIL_RELEASE_alert	constant varchar2(255) := 'MCMB$JIL_RELEASE';
	cs_JIL_BOOK_alert   	constant varchar2(255) := 'MCMB$JIL_INSERT'; -- do not use!!!
	cs_JIL_PHOTO_alert	    constant varchar2(255) := 'MCMB$JIL_PHOTO';

	--termination alerts
	cs_stop_alert			constant varchar2(255) := 'IOMS$TERMINATE';
	cs_stop_JIL_alert		constant varchar2(255) := 'JIL$TERMINATE';


	-----------------------------------
	--PUBLIC PROCEDURES and FUNCTIONS--
	-----------------------------------
	--
	--		procedure to initialize the "config.inf" file for the TCP/IP file transfer process
	--
	procedure init;
	--

	--
	--		procedure to register the alerts we care about
	--
	procedure register;
	--

	--
	--		procedure to remove the alerts we care about
	--
	procedure unregister;
	--                         
	
	--
	--		procedure to deal with waitany loop, termination and maintaining the mt_jil_alertmessage table
	--
	procedure waitany;                                                                                    
	--

	--
	--		procedure to Register and waitany loop. This will replace the need to call register and waitany procedures
	--
	procedure regwaitany;
	--

	procedure signal(                                                                                    
		p_alert	   				in		varchar2,
		p_message				in		epic.epic_col_types.varchar_255%type);
	
    -- See package body for internal procedures and functions for record processing
end MPK_JIL;
/
