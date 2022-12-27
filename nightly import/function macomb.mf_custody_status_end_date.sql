CREATE OR REPLACE
FUNCTION MACOMB.mf_custody_status_end_date
	(p_booking_id	in		epic.eh_booking.booking_id%type,
	 p_cur_custody_status_id in epic.eh_booking_custody_status.custody_status_id%type)
	
--Returns the latest inmate's custody status code (eh_booking_custody_status.code_custody_status)

RETURN VARCHAR2 AS

	CURSOR cur_Code IS
	select date_start, custody_status_id
	from epic.eh_booking_custody_status
	where booking_id = p_booking_id  
	order by date_start;
--      and date_start in
--		    (select max(date_start)
--		     from epic.eh_booking_custody_status
--		     where booking_id = p_booking_id);
					 
    v_Code		varchar2(128);
    v_custody_status_id varchar2(128);
    v_gotit     varchar2(16);
  
BEGIN
   v_gotit := 'NO';

   FOR cust_stat in cur_Code
   LOOP  
   		dbms_output.put_line(v_gotit||' '|| cust_stat.custody_status_id ||' with ' ||p_cur_custody_status_id || ' ' ||cust_stat.date_start);
       if v_gotit = 'NO' THEN
	       if cust_stat.custody_status_id = p_cur_custody_status_id then  
    	   	   v_gotit := 'YES';  
--    	   	   v_code := cust_stat.date_start;
      	   END IF;
       ELSE
       		v_code := cust_stat.date_start;
       		dbms_output.put_line('v_code '||v_code ||' '||cust_stat.date_start);
       		exit;
       END IF;	
   END LOOP;  

RETURN v_code;

END;
 --JDM
/
