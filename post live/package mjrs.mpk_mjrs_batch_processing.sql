CREATE OR REPLACE
package      MPK_mjrs_Batch_Processing is
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
	--termination alerts
	cs_stop_alert			constant varchar2(255) := 'IOMS$TERMINATE';
	cs_stop_JIL_alert		constant varchar2(255) := 'JIL$TERMINATE';


	-----------------------------------
	--PUBLIC PROCEDURES and FUNCTIONS--
	-----------------------------------
	PROCEDURE MP_mjrs_inmate_insert 
	     (
			p_batch_id			IN		number,		 -- batch_run_number
			p_offender_id       IN		VARCHAR2,    -- Used in locating correct reocrd in OT
			p_user_id           IN      INTEGER,	 -- User who created the transaction		
			p_Status			   OUT	VARCHAR2     -- Return Code (TRUE/FALSE)
		 );


/*	
	--
	--	Procedure add inmate to log
	--
	PROCEDURE MP_mjrs_inmate_insert_log 
	     (
			p_batch_id          IN      NUMBER,     -- batch_run_number
			p_offender_id       IN		VARCHAR2,   -- Used in locating correct reocrd in OT
			p_user_id           IN      INTEGER,	-- User who created the transaction	
			p_Status			   OUT	VARCHAR2    -- Return Code (TRUE/FALSE)
		 );
*/
/*	
	--
	--	Procedure add charge/status
	--
	PROCEDURE MP_mjrs_inmate_STMT_insert 
	     (
			p_batch_id          IN       NUMBER     -- batch_run_n umber
		    p_offender_id       IN		 VARCHAR2,  -- Used in locating correct reocrd in OT
			p_Status			   OUT	 VARCHAR2   -- Return code (TRUE/FALSE)
		 );
*/
	
  	--
	--
	--	Procedure add charge/status
	--
 	PROCEDURE mjrs_charge_add 
	     (
			 p_batch_id          IN     number,    -- batch_run_n umber
			 p_offender_id       IN		VARCHAR2,  -- Used in locating correct reocrd in OT
			 p_booking_id        IN     VARCHAR2,  -- Used in locating correct reocrd in OT
			 p_custody_status_id IN     VARCHAR2,  -- Used in locating correct reocrd in OT
			 p_cust_status       IN     VARCHAR2,  -- Start date of charge/status code
	         p_status_start		 IN		DATE,      -- Start date of charge/status code
	         p_status_end		 IN		DATE,      -- End date of charge/status if known
	         p_charge_detail_id  IN     number,    -- Charge_detail_id
			 p_Status			   OUT	VARCHAR2   -- Return code (TRUE/FALSE)
		 );
 
	PROCEDURE MP_mjrs_work_release_inmate 
	     (
			p_batch_id          IN      number,
 			p_offender_id       IN		VARCHAR2,
 			p_charge_detail_id	IN 		number,
 			p_booking_id		IN		VARCHAR2,
 			p_custody_status_id IN      VARCHAR2,
 			p_cust_status       IN      VARCHAR2,
	        p_status_start		IN		DATE, 
	        p_STATUS_END		IN		DATE,
			p_Status			   OUT	VARCHAR2
		 );
/*	
	--
	--	Procedure release old charge/status
	--
	PROCEDURE MP_mjrs_charge_release 
	     (
			p_batch_id          IN      number,    -- batch_run_number
 			p_offender_id       IN		VARCHAR2,  -- OT Offender id (123456)
	        p_status_start		IN		DATE,      -- Start date of the new status used as end date
			p_Status			   OUT	VARCHAR2   -- Return code (TRUE/FALSE)
		 );
*/
/*	--
	--	Procedure add chrage/status log
	--
	PROCEDURE MP_mjrs_charge_insert_log 
	     (
			p_batch_id          IN      number,    -- batch run number
			p_booking_id        IN      VARCHAR2,    -- booking_id you are processing now
			p_charge_id         IN      number       -- current charge_id value (number)
		 );
*/
	--
	--      procedure for main processing of the batch
	--
	
	PROCEDURE MP_mjrs_Batch_Run 
	     (
			p_run_date          IN      Date        -- Sysdate normally, first run will be cut off date
		 );
	

--	PROCEDURE MP_mjrs_inital_load
--	     (
--			p_run_date          IN      Date        -- Sysdate normally, first run will be cut off date
--		 );
	
    -- See package body for internal procedures and functions for record processing
end MPK_mjrs_Batch_Processing;
/
