CREATE OR REPLACE
FUNCTION MF_EVENTLOG_BALANCES
( p_casenumber IN VARCHAR2, 
  p_category   in varchar2
) return VARCHAR2 AS
v_bal      varchar2(2000); 
cursor curBal is
Select 
translate(detaileddescription,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz`~!@#$%^&*()_-+={}|[]\:;"<,>?/ ',' ') 
  from jrls.eventlog                         
  where Casenumber = p_casenumber
  and category = p_category
  order by visitdt desc; 
BEGIN
  OPEN curBal;
    FETCH curBal INTO v_bal;    
  CLOSE curBal;      
  Return nvl(v_Bal,0);    
 END MF_EVENTLOG_BALANCES;

/
