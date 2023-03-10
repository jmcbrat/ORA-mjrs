insert into MT_JIL_inmate@INTTEMPD.REGRESS.RDBMS.DEV.US.ORACLE.COM
(ENTITY_ID_PK,ACTIVE,OFFENDER_ID,JUVENILE_FLAG,INMATECLASS,
LASTNAME ,FIRSTNAME,OTHERNAME,DOB,GENDER,CELL,
LEVEL4,LEVEL5,LEVEL6,LEVEL7,LEVEL8,PAID_RELEASE,
PROJECTED_RELEASE,RESTRICTIONUNTIL,SENT_TOTAL,
HOLD_TOTAL,BAIL_TOTAL,VEHICLE_ID,TOW_COMPANY,MUGPATH)
select      entity_id,
			'Y' AS ACTIVE,
            offender_id,
            juvenile_flag,
			inmateclass,
			lastname,
			firstname,
			othername,
			DOB,
   			gender,
			cell,
	   		Level4,
	   		Level5,
	  		Level6,
       		level7,
       		level8,
			paid_release,
    	   	Projected_release,--,
    	   	sent_total,
    	   	hold_total,
    	   	bail_total,
	    	restrictionuntil,
   			vehicle_id,
			tow_company,
			mugpath
from MV_ACTIVE_INMATE
