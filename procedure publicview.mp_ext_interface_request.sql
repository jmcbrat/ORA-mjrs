CREATE OR REPLACE
PROCEDURE         mp_ext_interface_request 
	 (	p_name           IN     varchar2,
	    p_user           IN     varchar2,
	    p_pass           in     varchar2)     -- name NO path of the base file name entity_id of inmate

is 

f utl_file.file_type;
l_output varchar2(1000);
vCur     epic.epp_generic_ref_cursor.ref_cursor;


BEGIN   
	BEGIN
		-- build a grammar file for IVR
		mp_create_IVR_grammar_file();
	END;
	BEGIN
		-- write sql 
		   -- load MT_JIL_ALBUM  
		   -- load MT_JIL_MUG
				OPEN vCur FOR 
				    --the below query pulls back the header information
					select command 
					from (
						select 0 as orderby, 'variable http_resp VARCHAR2;' as command from dual union
						select 1 as orderby, 'variable http_resp_content_type VARCHAR2;' as command from dual union
						select 2 as orderby, 'BEGIN mpk_jil.jil_mug('||chr(39)||p_name||chr(39)||',null); END;' as command from dual union
						select 3 as orderby, '/' as command from dual union
		   -- http request
						select 4 as orderby, 'BEGIN http.get_gram('||chr(39)||
						                     'http://10.64.250.14:8080/grammarupload'||chr(39)||
						                     ',:http_resp,:http_resp_content_type,null,null); END;' from dual union
						select 5 as orderby, '/' as command from dual 
					    ORDER BY orderby
					 );   
										
			    f := utl_file.fopen('JIL_SQL', p_name ||'.'|| 'sql','W'); 
				LOOP
			      FETCH vCur INTO l_output;
			      EXIT WHEN  vCur%NOTFOUND;
			     	utl_file.put_line(f,l_output);
			   END LOOP;
			   CLOSE vCur;
			    utl_file.fclose(f);
	END;


-- write ftp 
	BEGIN  
			
		OPEN vCur FOR 
		    --the below query pulls back the header information
			select command 
			from (
				select 1 as orderby, 'USER epicftp' as command from dual union --||--chr(10)||
				select 2 as orderby, 'Epic1Ftp'as command from dual union --||--chr(10)||
				select 3 as orderby, 'lcd ..\images' as command from dual union --||--chr(10)||
				select 4 as orderby, 'binary' as command from dual 	union
				select --i.entity_id_pk,
						--i.offender_id,
						--mf_JILIVR_mug_name_entity(i.entity_id_pk) as image_name,
						5 as orderby,
						'get '||mf_JILIVR_mug_imagepath_entity(p_name)||mf_JILIVR_mug_name_entity(p_name)--,
						                                                      ||' '||mf_JILIVR_mug_name_entity(p_name)||'.jpg' as command
				from  dual
				union
				select 6 as orderby,
				       'bye'--||chr(10)
				from dual
			    ORDER BY orderby
			 );   
			 
			 
	    f := utl_file.fopen('JIL_FTP', p_name ||'.'|| 'FTP','W'); 
		LOOP
	      FETCH vCur INTO l_output;
	      EXIT WHEN  vCur%NOTFOUND;
	     	utl_file.put_line(f,l_output);
	   END LOOP;
	   CLOSE vCur;
	    utl_file.fclose(f);
	     	
	END; 
	
	
-- write grammar
-- write batch	
	BEGIN  
		OPEN vCur FOR 
		    --the below query pulls back the header information
			select command 
			from (
				--select 0 as orderby, 'c:' as command from dual union --||--chr(10)||
				--select 1 as orderby, 'cd:\ottest\mash\mugs' as command from dual union --||--chr(10)||
				select 2 as orderby, 'cd ..\ftp' as command from dual union --||--chr(10)||
				select 3 as orderby, 'FTP -n -s:..\ftp\'||p_name||'.ftp '||'photofile.macomb.county' as command from dual union --||--chr(10)||
				select 4 as orderby, 'cd..' as command from dual union --||--chr(10)||
				select 5 as orderby, 'copygrammar.bat ' as command from dual union --||--chr(10)||
				select 6 as orderby, 'cd SQL' as command from dual union --||--chr(10)||
				select 7 as orderby, 'c:\oracle\ora92\bin\sqlplus -L -S '||p_user||'/'||p_pass||'@ottest_macomb-data3  @'||p_name||'.sql' as command from dual union --||--chr(10)||
				select 8 as orderby, 'rem delete .\ftp\'||p_name||'.ftp ' as command from dual union
				select 9 as orderby, 'rem delete .\sql\'||p_name||'.sql' as command from dual union
				select 10 as orderby, 'rem delete .\image\'||mf_JILIVR_mug_name_entity(p_name)||'.jpg' as command from dual union
				select 11 as orderby, 'exit' as command from dual
			    ORDER BY orderby
			 );   
			 
			 
	    f := utl_file.fopen('JIL_BATCH', p_name ||'.'|| 'BAT','W'); 
		LOOP
	      FETCH vCur INTO l_output;
	      EXIT WHEN  vCur%NOTFOUND;
	     	utl_file.put_line(f,l_output);
	   END LOOP;
	   CLOSE vCur;
	    utl_file.fclose(f);
	     	
	END; 

END;
/
