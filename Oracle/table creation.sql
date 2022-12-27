/*	Purpose:		create tables for pre-booking

	Author:			Joe McBratnie

	Change Log:		Changed By	    Date Modified	Change Made
					----------  	-------------	------------------------------------------
					J. McBratnie	3/13/2006		Created
*/

-- Drop unneeded tables
drop table MACOMB.MT_PB_MUG_PRINT;
drop table MACOMB.mt_pb_arrest_property;

-- Create table for property
create table
MACOMB.mt_pb_arrest_property
(
Arrest_ID 	Varchar2(16)  not null,
Property_ID  Varchar2(16)  not null primary key,
Property    Varchar2(255) not null,
Description Varchar2(64)  not null,
Image       Varchar2(255) null,
QUANTITY     number(6) null,
Color       Varchar2(64) null
);

-- release the table to recreate it
drop table MACOMB.mt_pb_biometeric;

-- Load Bio table
create table
MACOMB.mt_pb_biometeric
(
biometeric_id Varchar2(16) NOT NULL PRIMARY KEY,
Arrest_ID Varchar2(16) NOT NULL,
bioType_ID Varchar2(16) NOT NULL,
bioDescription Varchar2(64) NOT NULL,
biovolumeserver Varchar2(255) NOT NULL,
biovolumepath Varchar2(255) NOT NULL,
bioimageref Varchar2(16) NOT NULL
);

-- Release the lookup table
drop table MACOMB.mt_pb_BioType;

-- Create Bio lookup table
CREATE TABLE
MACOMB.mt_pb_BioType
(
bioType_ID Varchar2(16) NOT NULL PRIMARY KEY,
bioDescription Varchar2(64) NOT NULL
);

-- Insert the needed rows for lookup
INSERT INTO MACOMB.mt_pb_BioType (bioType_ID, bioDescription) VALUES (EPIC.epic_ids.new_epic_id(),'Pre-Booking Mugshot');
INSERT INTO MACOMB.mt_pb_BioType (bioType_ID, bioDescription) VALUES (EPIC.epic_ids.new_epic_id(),'Booking Mugshot');
INSERT INTO MACOMB.mt_pb_BioType (bioType_ID, bioDescription) VALUES (EPIC.epic_ids.new_epic_id(),'Property');
INSERT INTO MACOMB.mt_pb_BioType (bioType_ID, bioDescription) VALUES (EPIC.epic_ids.new_epic_id(),'Thumb - Left');
INSERT INTO MACOMB.mt_pb_BioType (bioType_ID, bioDescription) VALUES (EPIC.epic_ids.new_epic_id(),'Thumb - Right');
INSERT INTO MACOMB.mt_pb_BioType (bioType_ID, bioDescription) VALUES (EPIC.epic_ids.new_epic_id(),'Palm');
INSERT INTO MACOMB.mt_pb_BioType (bioType_ID, bioDescription) VALUES (EPIC.epic_ids.new_epic_id(),'DNA');


DROP TABLE MACOMB.mt_pb_dept;
CREATE TABLE
MACOMB.mt_pb_dept
(
Department_ID	Varchar2(16) NOT NULL PRIMARY KEY,
DepartmentName	Varchar2(64) NOT NULL,
DepartmentCity	Varchar2(40) NOT NULL,
DepartmentState	Varchar2(64) NOT NULL,
DepartnemtZip	Varchar2(64) NOT NULL
);

INSERT INTO MACOMB.mt_pb_dept (DEPARTMENT_ID, DEPARTMENTNAME, DEPARTMENTCITY, DEPARTMENTSTATE, DEPARTNEMTZIP)
(select o.ENTITY_ID,o.organization_name,upper(CITY_TOWN_LOCALE),upper(STATE_PROVINCE_REGION), POSTAL_CODE  -- 0 MCSO, 1 Macomb others, 3 near counties, 4 others
--       decode(a.postal_code, '48041',1,'48043',0,'48045',2,'48046',1,
--                             '48047',1,'48048',1,'48060',3,'48062',3,
--                             '48091',1,'48089',1,'48021',1,'48080',1,
--                             '48081',1,'48066',1,'48015',1,'48092',1,
--                             '48093',1,'48026',1,'48082',1,'48045',1,
--                             '48035',1,'48036',1,'48312',1,'48310',1,
--                             '48314',1,'49313',1,'48038',1,'48036',1,
--                             '48317',1,'48094',1,'48096',1,'48048',1,
--                             '48051',1,'48047',1,'48094',1,'48095',1,
--                             '48096',1,'48050',1,'48065',1,'48005',1,
--                             '48062',1,'48065',1,'48066',1,'48067',3,
--                             '48069',3,'48070',3,'48071',3,'48072',3,
--                             '48076',3,'48076',3,'48084',3,'48226',3,
--                             '48234',3,'48236',3,'48242',3,'48313',1,
--                             '48316',1,'48079',3,'48081',3,'48093',3,
--                             '48317',1,'48341',2,'48342',2,'48413',3,'48455',1,4),
--       o.entity_id
from EPIC.EH_ENTITY_ORGANIZATION o,epic.eh_entity_roles r, epic.eh_address a
where r.code_entity_role in ('784')
  and o.entity_id = r.entity_id
  and r.effective_to >= EPIC.epicdatenow()
  and o.date_ceased_operating is null
  and o.entity_id = a.entity_id
  and a.postal_code in ('48041','48046',
                             '48047','48048','48060',
                             '48091','48089','48021','48080',
                             '48081','48066','48015','48092',
                             '48093','48026','48082','48045',
                             '48035','48036','48312','48310',
                             '48314','49313','48038','48036',
                             '48317','48094','48096','48048',
                             '48051','48047','48094','48095',
                             '48096','48050','48065','48005',
                             '48062','48065','48066','48313',
                             '48316','48317','48455'));

INSERT INTO MACOMB.mt_pb_dept (DEPARTMENT_ID, DEPARTMENTNAME, DEPARTMENTCITY, DEPARTMENTSTATE, DEPARTNEMTZIP) VALUES ('0IHWQYG0A0USJ0T2','OUT OF COUNTY CHECK OTHER','UNKNOWN','MI','48043');


Drop table MACOMB.mt_pb_arrest_charge;

CREATE TABLE
MACOMB.mt_pb_arrest_charge
(
Arrest_ID	Varchar2(16) 	NOT NULL,
Charge_ID	Varchar2(16)	NOT NULL PRIMARY KEY,
Charge		Varchar2(64)	NOT NULL,
PACC	    Varchar2(64)	NOT NULL,
IncidentNumber	Varchar2(64) NOT NULL,
crimeyear		Varchar2(4) NULL,
Count			number(2,0) NULL,
Class			Varchar2(64) NULL,
ArrestReason	Varchar2(64) NOT NULL,
CourtName		Varchar2(64) NULL,
ComplaintAgency	Varchar2(64) NOT NULL,
ArrestAgency	Varchar2(64) NOT NULL,
CNT				Varchar2(16) NULL,
TCN				Varchar2(16) NULL
);

ALTER TABLE MT_PB_ARREST_CHARGE
 ADD CTN varchar2(16) null;
ALTER TABLE MT_PB_ARREST_CHARGE
  drop column CNT ;
ALTER TABLE MT_PB_ARREST_CHARGE
 ADD statute_id varchar2(16) null;


Drop table MACOMB.mt_pb_language;

CREATE TABLE
MACOMB.mt_pb_language
(
Language_ID	Varchar2(16) NOT NULL PRIMARY KEY,
Arrest_ID	Varchar2(16) NOT NULL,
LanguageType	Varchar2(64) NOT NULL,
OtherLanguageSpoken	Varchar2(64) NULL,
OtherLanguageRead	Varchar2(64) NULL,
OtherLanguageWritten	Varchar2(64) NULL

);

drop table MACOMB.mt_pb_phone_detail;

/*CREATE TABLE
MACOMB.mt_pb_phone_detail
(
Phone_ID	Varchar2(16) NOT NULL PRIMARY KEY,
Arrest_ID	Varchar2(16) NOT NULL  ,
PHONE_COUNTRY_CODE Varchar2(4) NULL,
PHONE_AREA_CODE	Char(3) NULL,
PHONE_NUMBER Varchar2(10) NOT NULL,
PHONE_EXTENSION	Varchar2(6) NULL,
Phone_Type	Varchar2(64) NOT NULL
);*/

Drop Table MACOMB.mt_pb_keep_separate;

CREATE TABLE
MACOMB.mt_pb_keep_separate
(
KEEP_SEPARATE_ID	Varchar2(16) NOT NULL PRIMARY KEY,
ORIGIN_ENTITY_ID	Varchar2(16) NOT NULL,
SEPARATE_ENTITY_ID	Varchar2(16) NOT NULL,
Location_ID			Varchar2(64) NOT NULL
);

Drop table MACOMB.mt_pb_person_alias;

CREATE TABLE
MACOMB.mt_pb_person_alias
(
Alias_ID	Varchar2(16) NOT NULL PRIMARY KEY,
Arrest_ID	Varchar2(16) NOT NULL,
FirstName	Varchar2(32) NOT NULL,
LastName	Varchar2(32) NOT NULL,
NameType	Varchar2(64) NOT NULL,
OT_Data     varchar2(1)      null
);

ALTER TABLE mt_pb_person_alias
 ADD DOB date null;

ALTER TABLE mt_pb_person_alias
 ADD SSN varchar2(11) null;

drop table MACOMB.mt_pb_officers;

CREATE TABLE
MACOMB.mt_pb_officers
(
Officer_ID	Varchar2(16)         NOT NULL PRIMARY KEY,
Arrest_ID	Varchar2(16)		 NOT NULL,
OfficerDepartment	Varchar2(16) NULL,
OfficerRole			Varchar2(64) NULL,
OfficerName			Varchar2(64) NULL,
OfficerBadge		Varchar2(64) NULL
);

drop table MACOMB.mt_pb_tow_details;

CREATE TABLE
MACOMB.mt_pb_tow_details
(
TowComany_ID	Varchar2(16) NOT NULL PRIMARY KEY,
TowCompanyName	Varchar2(255) NOT NULL,
PHONE_COUNTRY_CODE Varchar2(4) NULL,
PHONE_AREA_CODE Char(3) NULL,
PHONE_NUMBER Varchar2(10) NULL,
PHONE_EXTENSION Varchar2(6) NULL,
TowCompanyLocation Varchar2(64) NULL,
TowCompanyCity Varchar2(40) NULL,
TowCompanyState Varchar2(64) NULL,
TowCompanyZip Varchar2(64) NULL
);

ALTER TABLE mt_pb_tow_details
 ADD TowCompanyCode varchar2(64) null;

INSERT INTO MACOMB.mt_pb_tow_details (TowComany_ID, TowCompanyName, PHONE_AREA_CODE,PHONE_NUMBER, TowCompanyLocation,TowCompanyCity, TowCompanyState, TowCompanyZip, PHONE_COUNTRY_CODE ) VALUES (EPIC.epic_ids.new_epic_id(),'Alecks','586','752-3645','217 Fairgrove','Romeo','MI','48065', '01');
INSERT INTO MACOMB.mt_pb_tow_details (TowComany_ID, TowCompanyName, PHONE_AREA_CODE,PHONE_NUMBER, TowCompanyLocation,TowCompanyCity, TowCompanyState, TowCompanyZip, PHONE_COUNTRY_CODE ) VALUES (EPIC.epic_ids.new_epic_id(),'Ballors','586','749-5117','57760 Main St','New Haven','MI','48048', '01');
INSERT INTO MACOMB.mt_pb_tow_details (TowComany_ID, TowCompanyName, PHONE_AREA_CODE,PHONE_NUMBER, TowCompanyLocation,TowCompanyCity, TowCompanyState, TowCompanyZip, PHONE_COUNTRY_CODE ) VALUES (EPIC.epic_ids.new_epic_id(),'Big Mikes','586','468-8244','25350 Joy Blvd','Harrison Twp','MI','48045', '01');
INSERT INTO MACOMB.mt_pb_tow_details (TowComany_ID, TowCompanyName, PHONE_AREA_CODE,PHONE_NUMBER, TowCompanyLocation,TowCompanyCity, TowCompanyState, TowCompanyZip, PHONE_COUNTRY_CODE ) VALUES (EPIC.epic_ids.new_epic_id(),'B and G Towing','586','977-5920','7200 18 Mile Rd','Sterling Hts','MI','48314', '01');
INSERT INTO MACOMB.mt_pb_tow_details (TowComany_ID, TowCompanyName, PHONE_AREA_CODE,PHONE_NUMBER, TowCompanyLocation,TowCompanyCity, TowCompanyState, TowCompanyZip, PHONE_COUNTRY_CODE ) VALUES (EPIC.epic_ids.new_epic_id(),'Garfield & Canal Towing','586','286-1357','16933 Canal','Clinton Twp','MI','48035', '01');
INSERT INTO MACOMB.mt_pb_tow_details (TowComany_ID, TowCompanyName, PHONE_AREA_CODE,PHONE_NUMBER, TowCompanyLocation,TowCompanyCity, TowCompanyState, TowCompanyZip, PHONE_COUNTRY_CODE ) VALUES (EPIC.epic_ids.new_epic_id(),'Glens','586','752-3906','396 Sisson','Romeo','MI','48065', '01');
INSERT INTO MACOMB.mt_pb_tow_details (TowComany_ID, TowCompanyName, PHONE_AREA_CODE,PHONE_NUMBER, TowCompanyLocation,TowCompanyCity, TowCompanyState, TowCompanyZip, PHONE_COUNTRY_CODE ) VALUES (EPIC.epic_ids.new_epic_id(),'Hugos','586','752-9497','12093 31 Mile Rd','Romeo','MI','48065', '01');
INSERT INTO MACOMB.mt_pb_tow_details (TowComany_ID, TowCompanyName, PHONE_AREA_CODE,PHONE_NUMBER, TowCompanyLocation,TowCompanyCity, TowCompanyState, TowCompanyZip, PHONE_COUNTRY_CODE ) VALUES (EPIC.epic_ids.new_epic_id(),'Nicks/Kings','586','463-3500','42870 North Walnut','Mt Clemens','MI','48043', '01');
INSERT INTO MACOMB.mt_pb_tow_details (TowComany_ID, TowCompanyName, PHONE_AREA_CODE,PHONE_NUMBER, TowCompanyLocation,TowCompanyCity, TowCompanyState, TowCompanyZip, PHONE_COUNTRY_CODE ) VALUES (EPIC.epic_ids.new_epic_id(),'Michigan Marine Salvage','586','468-2430','32475 South River Rd','Harrison Twp','MI','48045', '01');
INSERT INTO MACOMB.mt_pb_tow_details (TowComany_ID, TowCompanyName, PHONE_AREA_CODE,PHONE_NUMBER, TowCompanyLocation,TowCompanyCity, TowCompanyState, TowCompanyZip, PHONE_COUNTRY_CODE ) VALUES (EPIC.epic_ids.new_epic_id(),'Motor City','586','784-5361','20951 32 Mile Rd','Armada','MI','48005', '01');
INSERT INTO MACOMB.mt_pb_tow_details (TowComany_ID, TowCompanyName, PHONE_AREA_CODE,PHONE_NUMBER, TowCompanyLocation,TowCompanyCity, TowCompanyState, TowCompanyZip, PHONE_COUNTRY_CODE ) VALUES (EPIC.epic_ids.new_epic_id(),'Road One Official','586','771-6840','19801 Pleasant','St Clair Shores','MI','48080', '01');
INSERT INTO MACOMB.mt_pb_tow_details (TowComany_ID, TowCompanyName, PHONE_AREA_CODE,PHONE_NUMBER, TowCompanyLocation,TowCompanyCity, TowCompanyState, TowCompanyZip, PHONE_COUNTRY_CODE ) VALUES (EPIC.epic_ids.new_epic_id(),'Ruehles Towing','586','468-6666','205 N Gratiot','Mt Clemens','MI','48043', '01');




DROP TABLE MACOMB.mt_pb_arrestee;

CREATE TABLE
MACOMB.mt_pb_arrestee
(
Arrest_ID	Varchar2(16) NOT NULL PRIMARY KEY,
Arrive_time date not null,
action_time date null,
LastName	Varchar2(32) NOT NULL,
MiddleName	Varchar2(64) NULL,
FirstName	Varchar2(32) NOT NULL,
NAME_SUFFIX Varchar2(64) NULL,
NAME_TITLE  Varchar2(10) NULL,
MaidenNAME  Varchar2(32) NULL,
Offender_ID	Varchar2(64) NULL,
State_ID	Varchar2(64) NULL,
FBI_ID		Varchar2(64) NULL,
SSN			Varchar2(11) NULL,
action_by	Varchar2(16) NOT NULL,
MatchedOffender_ID	Varchar2(16) NULL,
Mug_ID		Varchar2(16) NULL,
Print_ID		Varchar2(16) NULL,
TempHousingLocation	Varchar2(64) NULL,
-- home address information
RS_Address_id			VARCHAR2(16) null,
RS_DWELLING_NAME		VARCHAR2(40) NULL,
RS_FLAT_NO_OR_FLOOR_LEVEL		VARCHAR2(8) NULL,
RS_STREET_NUMBER		VARCHAR2(20) NULL,
RS_STREET_NAME		VARCHAR2(40) NULL,
RS_CITY_TOWN_LOCALE		VARCHAR2(40) NULL,
RS_STATE_PROVINCE_REGION		VARCHAR2(64) NULL,
RS_POSTAL_CODE		VARCHAR2(64) NULL,
RS_CODE_COUNTRY		VARCHAR2(64) NULL,
RS_phone_id         varchar2(16) null,
RS_PHONE_COUNTRY_CODE			Varchar2(16) NULL,
RS_PHONE_AREA_CODE			Char(3) NULL,
RS_PHONE_NUMBER			Varchar2(10) NULL,
RS_PHONE_EXTENSION			Varchar2(64) NULL,
RS_Phone_Type	Varchar2(64) NULL,
CL_Phone_ID		Varchar2(16) null,
CL_PHONE_COUNTRY_CODE			Varchar2(16) NULL,
CL_PHONE_AREA_CODE			Char(3) NULL,
CL_PHONE_NUMBER			Varchar2(10) NULL,
CL_PHONE_EXTENSION			Varchar2(64) NULL,
CL_Phone_Type	Varchar2(64) NULL,
DOB			Date NULL,
Height		Varchar2(64) NULL,
Weight			Varchar2(64) NULL,
Race	Varchar2(64) NULL,
Gender	Varchar2(64) NULL,
EyeRight	Varchar2(64) NULL,
EyeLeft	Varchar2(64) NULL,
Hair	Varchar2(64) NULL,
Complexion	Varchar2(64) NULL,
MaritalStatus	Varchar2(64) NULL,
BirthCity			Varchar2(40) NULL,
BirthState	Varchar2(64) NULL,
BirthCountry	Varchar2(64) NULL,
ReligiousPref	Varchar2(64) NULL,
DL_ID			Varchar2(16) NULL,
DLNumber			Varchar2(64) NULL,
DLState			Varchar2(64) NULL,
DLExpire		Date	NULL,
ENGLISHSpoken	Varchar2(64) NULL,
ENGLISHRead	Varchar2(64) NULL,
ENGLISHWritten	Varchar2(64) NULL,
EducationLevel	Varchar2(64) NULL,
EMPLOYEMENT_ID  VARCHAR2(16) NULL,
Occupation		Varchar2(64) NULL,
EmployerName	Varchar2(64) NULL,
EM_Address_id   varchar2(16) NULL,
EM_DWELLING_NAME		VARCHAR2(40) null,
EM_FLAT_NO_OR_FLOOR_LEVEL		VARCHAR2(8) null,
EM_STREET_NUMBER		VARCHAR2(20) null,
EM_STREET_NAME		VARCHAR2(40) null ,
EM_CITY_TOWN_LOCALE		VARCHAR2(40) null,
EM_STATE_PROVINCE_REGION		VARCHAR2(64) null,
EM_POSTAL_CODE		VARCHAR2(64) null,
EM_Phone_ID         varchar2(16) NULL,
EM_CODE_COUNTRY		VARCHAR2(64) NULL,
EM_PHONE_COUNTRY_CODE			Varchar2(16) NULL,
EM_PHONE_AREA_CODE			Char(3) NULL,
EM_PHONE_NUMBER			Varchar2(10) NULL,
EM_PHONE_EXTENSION			Varchar2(64) NULL,
EM_Phone_Type	Varchar2(64) NULL,
EC_Person_ID varchar2(16) NULL,
EmergencyContact			Varchar2(64) NULL,
EC_Phone_ID varchar2(16) NULL,
EC_PHONE_COUNTRY_CODE			Varchar2(16) NULL,
EC_PHONE_AREA_CODE			Char(3) NULL,
EC_PHONE_NUMBER			Varchar2(10) NULL,
EC_PHONE_EXTENSION			Varchar2(64) NULL,
EC_Phone_Type	Varchar2(64) NULL,
EmergencyRelationship	Varchar2(64) NULL,
AssultiveFlag	Char(1) NULL,
medicalFlag	Char(1) NULL,
SuicideFlag	Char(1) NULL,
SprayFlag	Char(1) NULL,
SprayWhen	Date NULL,
ElectroShockFlag	Char(1) NULL,
ElectroShockWhen	Date	NULL,
CautionComment	Varchar2(255) NULL
);

ALTER TABLE MT_PB_Arrestee
 ADD Homeless char(1) null;

ALTER TABLE MT_PB_Arrestee
 ADD Build varchar2(64) null;

ALTER TABLE MT_PB_Arrestee
 ADD USCitizen char(1) null;

ALTER TABLE MT_PB_ARRESTEE
 add CONSTRAINT MATCHEDOFFENDER_ID_unique UNIQUE (MATCHEDOFFENDER_ID, ARREST_ID);

ALTER TABLE MT_PB_ARRESTEE
  enable CONSTRAINT MATCHEDOFFENDER_ID_unique;

drop table MACOMB.mt_pb_arrest_officer;

CREATE TABLE
MACOMB.mt_pb_arrest_officer
(
arrestofficer_pk varchar(35) NOT NULL PRIMARY KEY,
Arrest_ID	Varchar2(16) NOT NULL,
Officer_ID	Varchar2(16) NOT NULL,
OfficerDepartment	Varchar2(64) NULL,
OfficerRole	Varchar2(64) NULL,
OfficerName	Varchar2(64) NULL,
OfficerBadge	Varchar2(64) NULL
);

ALTER TABLE MACOMB.mt_pb_arrest_officer
	drop column Officer_ID;

drop table MACOMB.mt_pb_arrest_detail;

CREATE TABLE
MACOMB.mt_pb_arrest_detail
(
Arrest_ID	Varchar2(16) NOT NULL PRIMARY KEY,
ArrestDateTime	DATE	 NULL,
ArrestedWith_ID	Varchar2(16) NULL,
ArrestLocation	Varchar2(64) NULL,
ArrestCity		Varchar2(40) NULL,
ArrestState		Varchar2(64) NULL,
ArrestPrevHeld	Varchar2(64) NULL,
VehicleTowedTo	Varchar2(16) NULL
);

ALTER TABLE mt_pb_arrest_detail
 ADD ArrestDateTime  Date;



drop table MACOMB.mt_pb_timing;

CREATE TABLE
MACOMB.mt_pb_timing
(
timing_id   varchar2(16) NOT NULL PRIMARY KEY,
arrest_id	varchar2(16) NOT NULL,
action_by	varchar2(16)  NOT NULL,
step_id     varchar2(64)  NOT NULL,
duration    number(12,4) NULL
);

CREATE TABLE
MACOMB.mt_pb_step_lk
(
step_ID Varchar2(16) NOT NULL PRIMARY KEY,
stepDescription Varchar2(64) NOT NULL
);

INSERT INTO MACOMB.mt_pb_step_lk (step_ID, stepDescription) VALUES (EPIC.epic_ids.new_epic_id(),'PB_Pre Arrest');
INSERT INTO MACOMB.mt_pb_step_lk (step_ID, stepDescription) VALUES (EPIC.epic_ids.new_epic_id(),'PB_Lookup');
INSERT INTO MACOMB.mt_pb_step_lk (step_ID, stepDescription) VALUES (EPIC.epic_ids.new_epic_id(),'PB_Demographics');
INSERT INTO MACOMB.mt_pb_step_lk (step_ID, stepDescription) VALUES (EPIC.epic_ids.new_epic_id(),'PB_Charge');
INSERT INTO MACOMB.mt_pb_step_lk (step_ID, stepDescription) VALUES (EPIC.epic_ids.new_epic_id(),'PB_Property');
INSERT INTO MACOMB.mt_pb_step_lk (step_ID, stepDescription) VALUES (EPIC.epic_ids.new_epic_id(),'PB_Biometerics');

drop table MACOMB.mt_pb_temp_housing;

CREATE TABLE
MACOMB.mt_pb_temp_housing
(
housing_id	varchar2(16) NOT NULL PRIMARY KEY,
CELL_NAME	varchar2(4)  NOT NULL,
Gender      char(1)      NOT NULL
);

INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'HC02','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'HC01','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'HC03','F');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'HC03','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'HC04','F');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'HC05','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'HC06','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'HC07','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'HC08','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'HC09','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'HC10','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'HC11','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'DC01','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'DC02','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'DC01','F');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'DC02','F');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'GYM','M');
INSERT INTO MACOMB.mt_pb_temp_housing (housing_id, cell_name, gender) VALUES (EPIC.epic_ids.new_epic_id(),'GYM','F');

drop table MACOMB.mt_pb_property_lk;

CREATE TABLE
MACOMB.mt_pb_property_lk
(
property_id	varchar2(16) NOT NULL PRIMARY KEY,
description	varchar2(64)  NOT NULL,
sortorder   varchar2(2)
);
-- add code
ALTER TABLE mt_pb_property_lk
 ADD item_name varchar2(64) null;


INSERT INTO MACOMB.mt_pb_property_lk (property_id, description, sortorder) VALUES (EPIC.epic_ids.new_epic_id(),'SHIRT','1');
INSERT INTO MACOMB.mt_pb_property_lk (property_id, description, sortorder) VALUES (EPIC.epic_ids.new_epic_id(),'SHORTS','2');
INSERT INTO MACOMB.mt_pb_property_lk (property_id, description, sortorder) VALUES (EPIC.epic_ids.new_epic_id(),'SHOES','3');
INSERT INTO MACOMB.mt_pb_property_lk (property_id, description, sortorder) VALUES (EPIC.epic_ids.new_epic_id(),'PANTS','4');
INSERT INTO MACOMB.mt_pb_property_lk (property_id, description, sortorder) VALUES (EPIC.epic_ids.new_epic_id(),'BOOTS','5');
INSERT INTO MACOMB.mt_pb_property_lk (property_id, description, sortorder) VALUES (EPIC.epic_ids.new_epic_id(),'COAT','6');
INSERT INTO MACOMB.mt_pb_property_lk (property_id, description, sortorder) VALUES (EPIC.epic_ids.new_epic_id(),'HAT','7');
INSERT INTO MACOMB.mt_pb_property_lk (property_id, description, sortorder) VALUES (EPIC.epic_ids.new_epic_id(),'VALUABLES','8');
INSERT INTO MACOMB.mt_pb_property_lk (property_id, description, sortorder) VALUES (EPIC.epic_ids.new_epic_id(),'NO VALUABLES','8');
INSERT INTO MACOMB.mt_pb_property_lk (property_id, description, sortorder) VALUES (EPIC.epic_ids.new_epic_id(),'NO PROPERTY','8');
INSERT INTO MACOMB.mt_pb_property_lk (property_id, description, sortorder) VALUES (EPIC.epic_ids.new_epic_id(),'OTHER','9');

CREATE TABLE MACOMB.MT_PB_PROPERTY_COND
	(CondID					VARCHAR2(16) not null,
	 Description			VARCHAR2(64) not null,
	 SortOrder				NUMBER,
	 Code_Item_Condition  	VARCHAR2(64),
	 CONSTRAINT cond_pk PRIMARY KEY(CondID));


INSERT INTO MACOMB.mt_pb_property_cond (condid, description, code_item_condition)
(select epic.epic_ids.new_epic_id(),text_full, lookup_code from epic.epic_lookups where lookup_class = 'PROPERTY CONDITION TYPE' and effective_end_date > epic.epicdate(sysdate));

CREATE TABLE MACOMB.MT_PB_PROPERTY_COLOR
	(ColorID			VARCHAR2(16) not null,
	 Description		VARCHAR2(64) not null,
	 SortOrder			NUMBER,
	 Code_Item_Color    VARCHAR2(64),
	 CONSTRAINT color_pk PRIMARY KEY(ColorID));


INSERT INTO MACOMB.mt_pb_property_color (colorid, description, code_item_color)
(select epic.epic_ids.new_epic_id(),text_full, lookup_code from epic.epic_lookups where lookup_class = 'COLOUR TYPE' and effective_end_date > epic.epicdate(sysdate));


commit;

