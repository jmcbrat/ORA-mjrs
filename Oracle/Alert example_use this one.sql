create database link INTTEMPD.REGRESS.RDBMS.DEV.US.ORACLE.COM connect to IVR identified by IVR1 using 'IntTempdb';

DROP database link INTTEMPD.REGRESS.RDBMS.DEV.US.ORACLE.COM ;

describe MT_JIL_inmate@INTTEMPD.REGRESS.RDBMS.DEV.US.ORACLE.COM;

select * from MT_JIL_inmate@Link_IVR;

-- Computer one
execute mpk_jil.regwaitany;

--Computer two
select * from sys.dbms_alert_info

--signals the event
execute mpk_jil.signal(mpk_jil.cs_JIL_INMATE_alert,upper('ok got three'));

-- 1 alert per table in IVR
-- text field is the entity_id or booking_id


--clears the registered events
execute mpk_jil.unregister;

