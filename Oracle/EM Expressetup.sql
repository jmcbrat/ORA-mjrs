select name, cdb, con_id from v$database;
/*
OTMAIN	NO	0
*/

select instance_name, status, con_id from v$instance;
/*
  OTMAIN	NO	0OTMAIN	NO	0
*/

select dbms_xdb_config.gethttpsport() from dual;
/*
  5502
*/

select sys_context('USERENV','OTMAIN') from dual;

lsnrctl services;

exec DBMS_XDB_CONFIG.SETHTTPSPORT(5502);

SELECT * FROM v$version;
