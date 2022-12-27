--create a batch job

--process new bookings
   -- locate
   -- instert demo, and statment
      MP_mjrs_inmate_insert(p_offender_id, p_user_id, :p_Status)
   -- insert  status,
   ;
   select * from charges
   ;
   --charge_book_date (charges tab)
   -- charge_dispose_date

-- process updated status
   -- enddate the old status with start_date of new status
   -- insert new status

--process releases
   -- enddate the old status
   -- insert new status
;

--insert status
select 'batch_id',
   offnder_id,
   'charge_id',
   booking_id,
   transaction_code, --- to become a lookup/function
   booking_date,
   end_date,
   offtrk_days_in,
   days_in,
   original_charge_amt,
   adjusted_charge_amt, --, IS_CASH_SETTLEMENT, 
   STATUS_START_DATE, 
   STATUS_END_DATE --, IS_WORK_RELEASE,
   PROJ_RELEASE_DATE)
values(     );

   