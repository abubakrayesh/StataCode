global dir "C:\Users\Abubakr Ayesh\Dropbox\School Location\Peru Internet\Data\Censo Escolar"
global temp "C:\Users\Abubakr Ayesh\Dropbox\School Location\Abubakr\Temp"
global output "C:\Users\Abubakr Ayesh\Dropbox\School Location\Abubakr\Out"

**DESCRIPTION:	Program creates a 2016 cross section of schools, with variables that can then be appended with other years.**


**Within each year:**
**1 Cut school roster to just primary&secondary schools (niv_mod=="B0&F0"), and then keep schools with tiporeg==1 in cases where there are duplicates**
**		by cod_mod and anexo. Then, for now, keep just identifier variables (cod_mod, anexo, and codlocal).**
**2 Merge survey datasets into school cross section, creating variables that can be harmonized across years.**
**3 *3 Make identifiers consistent with test score data (i.e. create year variable and rename cod_mod to codmodular), then merge with scores**
**4 Merge with basic characteristics data (Eduardo's ready-made file schoollistECE.dta).**

set more off

**1**
use "${dir}\2016\data\marco censal 2016.dta", clear
keep if (niv_mod=="F0"|niv_mod=="B0")
bys cod_mod anexo: gen place = _n
keep if place==1
gen 		public_ce=1 if (ges_dep=="A1" | ges_dep=="A2" | ges_dep=="A3" | ges_dep=="A4")
replace 	public_ce=0 if public_ce==.
label var 	public_ce "Public \ private (from CE)"
gen 		dpto_ce=substr(codgeo,1,2)
destring 	dpto_ce, replace
label var 	dpto_ce "Department (CE)"

gen 		unipoli=cod_car
label def 	unipoli 1 "Single teacher" 
label def 	unipoli 2 "Mult grades, mult teachers", add
label def 	unipoli 3 "Full mult teachers", add
label var 	unipoli unipoli
replace unipoli=. if unipoli==4

label def 	area_ce 1 "Urban" 2 "Rural"
label val 	area_ce area_ce
label var 	area_ce "Urban \ Rural (from CE)"
keep cod_mod anexo codlocal public_ce dpto_ce unipoli area_ce niv_mod
save "${temp}\Temp2016\2016.dta", replace

**Do the same for the teacher file(s)**
use "${dir}\2016\data\3 - Primaria y Secundaria - 300 Personal docente y no docente 301-302.dta", clear
sort cod_mod anexo tiporeg
bys cod_mod anexo: gen place = _n
keep if place==1
drop place
egen comp_privfund = rowtotal(c3301_174 c3301_175)
egen aula_privfund = rowtotal(c3301_154 c3301_204 c3301_155 c3301_205)
save "${temp}\Temp2016\2016_teachers.dta", replace

use "${dir}\2016\data\3 - Primaria y Secundaria - 300 Personal docente y no docente 307.dta", clear
gen cs_degree=1 if c3307_0128!=.
replace cs_degree=0 if cs_degree==.
bys cod_mod anexo tiporeg: egen cs = max(cs_degree)
drop if cs==1 & cs_degree!=1
duplicates drop cod_mod anexo tiporeg, force
sort cod_mod anexo tiporeg
bys cod_mod anexo: gen place = _n
keep if place==1
drop cs_degree
save "${temp}\Temp2016\2016_teachers_2.dta", replace



**2 VARIABLES**

**Textbooks: By grade and subject**
use "${dir}\2016\data\3 - primaria y secundaria - 400 materiales educativos 403-404 y 407.dta", clear
local subjname "comm math person science soc lang"
forvalues subjno = 1 / 4 {
	local sjnm : word `subjno' of `subjname'
	forvalues gr = 1 / 6 {
	capture egen textbooks_g`gr'_`sjnm' = rowtotal(c3403_0`gr'`subjno' c3404_0`gr'`subjno'), m
	}
}
local subjname "comm math person science soc lang"
**Textbooks of previous years not available for history\soc and languages**
forvalues subjno = 5 / 6 {
	local sjnm : word `subjno' of `subjname'
	forvalues gr = 1 / 6 {
		rename c3403_0`gr'`subjno' textbooks_g`gr'_`sjnm'
	}
}
keep cod_mod anexo tiporeg textbooks*
sort cod_mod anexo tiporeg
bys cod_mod anexo: gen place = _n
keep if place==1
drop place
save "${temp}\Temp2016\2016_textbooks.dta", replace


**Collapse the enrollment data and reshape as needed so that there is one observation per school**
use "${dir}\2016\data\3 - primaria y secundaria - 200 matricula y secciones 201.dta", clear
sort cod_mod anexo tiporeg
bys cod_mod anexo: gen place = _n
keep if place==1
local h = 1
local m = 2
local hf "0"
local mf "0"
forvalues g=1/6 {
	if(`h'>9){
		local hf ""
		}
	if(`m'>9){
		local mf ""
		}
	egen g`g'_enroll = rowtotal(c3201_`hf'`h'* c3201_`mf'`m'*)
	label var g`g'_enroll "Grade `g' enrollment"
	local h = `h' + 2
	local m = `m' + 2
	}
keep cod_mod anexo g1_enroll - g6_enroll
save "${temp}\Temp2016\2016_enrollment.dta", replace

**Transfer students (use data from this year)**
use "${dir}\2016\data\3 - primaria y secundaria - 200 matricula y secciones 202-203.dta", clear
sort cod_mod anexo tiporeg
bys cod_mod anexo: gen place = _n
keep if place==1
local h = 1
local m = 2
local hf "0"
local mf "0"
forvalues g=1/6 {
	if(`h'>9){
		local hf ""
		}
	if(`m'>9){
		local mf ""
		}
	
	capture egen g`g'_transfer_promoted = rowtotal(c3202_`hf'`h'3 c3202_`mf'`m'3)
	capture label var g`g'_transfer_promoted "Transfers from outside promoted to grade `g'"
	egen g`g'_transfer_retained = rowtotal(c3202_`hf'`h'5 c3202_`mf'`m'5)
	label var g`g'_transfer_retained "Transfers from outside repeating grade `g'"
	
	capture egen g`g'_reentered_promoted = rowtotal(c3202_`hf'`h'6 c3202_`mf'`m'6)
	capture label var g`g'_reentered_promoted "Re-entrants promoted to grade `g' following interruption"
	egen g`g'_reentered_retained = rowtotal(c3202_`hf'`h'7 c3202_`mf'`m'7)
	label var g`g'_reentered_retained "Re-entrants repeating grade `g' following interruption"
	
	local h = `h' + 2
	local m = `m' + 2
	}
keep cod_mod anexo g1_transfer_retained - g6_reentered_retained
save "${temp}\Temp2016\2016_transfer_students.dta", replace


**Passing, failing, and dropping out	(2016 data is in 2016 CE)**
use "${dir}\2016\data\3 - Primaria y Secundaria-100-200 Resultado del ejercicio educativo a diciembre 2016.dta", clear
sort cod_mod anexo tiporeg
bys cod_mod anexo: gen place = _n
keep if place==1
local h = 1
local m = 2
local hf "0"
local mf "0"
forvalues g=1/6 {
	if(`h'>9){
		local hf ""
		}
	if(`m'>9){
		local mf ""
		}

	egen g`g'_passed_initially = rowtotal(C3101_`hf'`h'1 C3101_`mf'`m'1)
	label var g`g'_passed_initially "Students passing initial evaluation"
	egen g`g'_passed_reeval = rowtotal(C3201_`hf'`h'1 C3201_`mf'`m'1)
	label var g`g'_passed_reeval "Students passing upon reevaluation"
	
	egen g`g'_failed_initially = rowtotal(C3101_`hf'`h'5 C3101_`mf'`m'5)
	label var g`g'_failed_initially "Students failing initial evaluation"
	egen g`g'_failed_reeval = rowtotal(C3201_`hf'`h'2 C3201_`mf'`m'2)
	label var g`g'_failed_reeval "Students failing upon reevaluation"
	
	egen g`g'_dropout = rowtotal(C3101_`hf'`h'8 C3101_`mf'`m'8)
	label var g`g'_dropout "Students dropping out before evaluation"
	
	local h = `h' + 2
	local m = `m' + 2
	}
keep cod_mod anexo g1_passed_initially - g6_dropout
save "${temp}\Temp2016\2016_passfail.dta", replace


**Grade retention (data from following year)**

use "${dir}\2017\data\Matricula_02.dta", clear
rename *, lower

keep if cuadro=="C202"

sort cod_mod anexo tiporeg
bys cod_mod anexo: gen place = _n
keep if place==1

local h = 1
local m = 2
local hf "0"
local mf "0"
forvalues g=1/6 {
	if(`h'>9){
		local hf ""
		}
	if(`m'>9){
		local mf ""
		}
	egen g`g'_retained = rowtotal(d`hf'`h' d`mf'`m') if tipdato=="04"
	label var g`g'_retained "Students (not tranfers) repeating grade `g'"
	local h = `h' + 2
	local m = `m' + 2
	}

keep cod_mod anexo g1_retained - g6_retained

save "${temp}\Temp2016\2016_grade_retention.dta", replace

**Maternal language**
use "${dir}\2016\data\3 - primaria y secundaria - 200 matricula y secciones 208.dta", clear
forvalues g=1/6 {
	rename c3208_0`g'1 g`g'_span_lang
	label var g`g'_span_lang "Students whose maternal lang. is Spanish"
	}
forvalues g=1/6 {
	egen g`g'_oth_lang = rowtotal(c3208_0`g'*)
	label var g`g'_oth_lang "Students with maternal lang. other than Spanish"
	}

sort cod_mod anexo tiporeg
bys cod_mod anexo: gen place = _n
keep if place==1
keep cod_mod anexo g1_span_lang-g6_span_lang g1_oth_lang-g6_oth_lang
foreach var of varlist g* {
	replace `var' = 0 if `var'==.
	}
save "${temp}\Temp2016\2016_maternal_lang.dta", replace

**Creating Internet, Computer Room and No. of Computers (for All Schools)**
use "${dir}\2016\data\3 - Primaria y Secundaria - 500 Otros recursos para la ensenanza 502.dta", clear
encode c3502_chk1, gen(equipment)
recode equipment (1=0) (2=1)
**school has internet**
gen internet=.
replace internet=1 if tipdato==1 & equipment==1
replace internet=0 if tipdato==1 & equipment==0
label var equipment "School has the mentioned equipment"
label var internet "school has internet"
**no of computers**
gen computers=.
replace computers = c3502_02 if tipdato==3
replace computers = c3502_02 if tipdato==4
replace computers = c3502_02 if tipdato==5
label var computers "no. of types of computers"
**school has a computer room**
gen comproom_all = .
replace comproom_all = 0 if tipdato==8 & equipment==0
replace comproom_all = 1 if tipdato==8 & equipment==1
label var comproom_all "school has a computer room"
**no of computers used for instruction**
encode c3502_chk3, gen(c3502_chk3num)
recode c3502_chk3num (2=0) (3=1), gen(learning)
drop if learning==4
label var learning "=1 if equipment is used for learning"
gen icomputers=.
replace icomputers = c3502_02 if tipdato==3 & learning==1
replace icomputers = c3502_02 if tipdato==4 & learning==1
replace icomputers = c3502_02 if tipdato==5 & learning==1
label var icomputers "no. of computers used for instruction"
rename computers ncomp
rename icomputers ncompin

foreach var of varlist ncomp ncompin comproom_all internet {
local i`var' : var label `var'
} 
collapse (sum) ncomp ncompin (max)comproom_all internet, by(cod_mod anexo tiporeg)
foreach var of varlist ncomp ncompin comproom_all internet {
label var `var' "`i`var''"
}
save "${temp}\Temp2016\2016_internet_ncomp_comproom.dta", replace

**Creating some variables for public schools only**
 use "${dir}\2016\data\11 - local escolar 304.dta", clear

**Public school has computer room**
gen is_comproom = 0 if p304_1==.
replace is_comproom = 1 if p304_1==2
bys codlocal: egen comproom_plc = max(is_comproom)
label var comproom_plc "Public School has a computer room"
**Public school has administrative offices**
gen is_admin = 0 if p304_1!=.
replace is_admin = 1 if p304_1==7
bys codlocal: egen adminoffice = max(is_admin)
label var adminoffice "School has administrative office(s)"
**Public school has workshop**
gen is_workshop = 0 if p304_1!=.
replace is_workshop = 1 if p304_1==4
bys codlocal: egen workshop = max(is_workshop)
label var workshop "School has a workshop"
**Public school has teachers' room**
gen is_tchrm = 0 if p304_1!=.
replace is_tchrm = 1 if p304_1==5
bys codlocal: egen facroom = max(is_tchrm)
label var facroom "School has teachers' room(s)"
**number of toilets**
*gen is_toilet=0 if p304_1==.
*replace is_toilet=1 if p304_1==9
*replace is_toilet=1 if p304_1==10
*bys codlocal: egen ntoilets = max(is_toilet)
*label var ntoilets "Number of toilets in school"

drop p304_1-p304_52 is_* p304_nro
duplicates drop

foreach var of varlist comproom_plc workshop adminoffice facroom {
local i`var' : var label `var'
}
collapse (max)comproom_plc workshop facroom adminoffice, by(codlocal)
foreach var of varlist comproom_plc workshop adminoffice facroom {
label var `var' "`i`var''"
}
save "${temp}\Temp2016\2016_public_schools.dta", replace


**FACILITY INFRASTRUCTURE**
use "${dir}\2016\data\11 - local escolar.dta", clear	
duplicates drop
drop if codlocal==""
bys codlocal: gen dups = _n
drop if dups>1

**merging some variables for public schools variables**
merge 1:m codlocal using "${temp}\Temp2016\2016_public_schools.dta"
*keep if _merge==3
drop if _merge==2
drop _merge
duplicates drop

merge 1:m codlocal using "${temp}\Temp2016\2016.dta"	
keep if (_merge==2 | _merge==3)
gen missinfrastr=(_m==2)
drop _merge

**number of classrooms**
destring p301_edu, gen(nclassrooms)
label var nclassrooms "Number of classrooms in school"
**school has full perimeter fence**
destring p222 p223 p225 p229, replace
gen fence_full = 1 if  p229==1
replace fence_full = 0 if p229>1 & p229~=.
label var fence_full "School has a full perimeter fence"
**school has a full or partial perimeter fence**
gen fence_any = 1 if  p229==1 | p229==2
replace fence_any = 0 if p229== 3
label var fence_any "School has a full or partial perimeter fence"
**school has electricity**
recode p222 (5=0) (nonm=1), gen(electricity)
label var electricity "School has electricity"
**school connected to public drinking water network**
recode p223 (1=1) (nonm=0), gen(water)
label var water "School connected to public drinking water network"
**school connected to public sewage network**
recode p225 (1=1) (nonm=0), gen(sewage)
label var sewage "School connected to public sewage network"
**school has library**
encode p203, gen(p203_num)
drop if p203_num==1
recode p203_num (2=0) (3=1), gen(library)
label var library "School has library"
**school has laboratory**
encode p201, gen(p201_num)
recode p201_num (1=0) (2=1), gen(laboratory)
label var laboratory "School has lab(s)"

**population center has electricity**
encode p601_1, gen(p601_1_num)
recode p601_1_num (2=0) (3=1), gen(ccpp_electricity)
label var ccpp_electricity "Population center has electricity"
**population center has public drinking water network**
encode p601_2, gen(p601_2_num)
recode p601_2_num (2=0) (3=1), gen(ccpp_water)
label var ccpp_water "Population center has public drinking water network"
**population center has public sewage network**
encode p601_3, gen(p601_3_num)
recode p601_3_num (2=0) (3=1), gen(ccpp_sewage)
label var ccpp_sewage "Population center has public sewage network"
**population center has medical outpost or health center**
encode p601_4, gen(p601_4_num)
recode p601_4_num (2=0) (3=1), gen(ccpp_health)
label var ccpp_health "Population center has med outpost or health center"
**population center has community telephone**
encode p601_61, gen(p601_61_num)
recode p601_61_num (2=0) (3=1), gen(ccpp_phone)
label var ccpp_phone "Population center has communal telephone"
**population center has an internet booth**
encode p601_7, gen(p601_7_num)
recode p601_7_num (2=0) (3=1), gen(ccpp_intbooth)
label var ccpp_intbooth "Population center has internet booth(s)"
**population center has bank agency**
encode p601_8, gen(p601_8_num)
recode p601_8_num (2=0) (3=1), gen(ccpp_bank)
label var ccpp_bank "Population center has bank agency"
**population center has municipal library**
encode p601_9, gen(p601_9_num)
recode p601_9_num (2=0) (3=1), gen(ccpp_library)
label var ccpp_library "Population center has municipal library"

bys cod_mod: gen place=_n
count if place>1
keep if place==1
**Only 26 observations are dropped, so it not an issue**
drop place

**merging internet, ncomp and comproom variables**
merge 1:m cod_mod using "${temp}\Temp2016\2016_internet_ncomp_comproom.dta"
*keep if _merge==3
drop if _merge==2
drop _merge
duplicates drop

**School has a computer room**
replace comproom_all=. if comproom_plc==1 & comproom_all==1
egen comproom = rowtotal( comproom_plc comproom_all )
label var comproom "school has a computer room"

keep cod_mod anexo codlocal ///
	 electricity water sewage library laboratory facroom adminoffice  workshop ///
	 nclassrooms ccpp_electricity ccpp_water comproom fence_full fence_any ///
	 ccpp_sewage ccpp_health ccpp_phone ccpp_intbooth ccpp_bank ccpp_library missinfr ///
	 public_ce dpto_ce unipoli area_ce niv_mod internet comproom ncomp ncompin

bys cod_mod: gen place=_n
count if place>1
keep if place==1
**Only 20 observations are dropped, so it not an issue**
drop place

**TEACHERS**
merge 1:1 cod_mod anexo using "${temp}\Temp2016\2016_teachers.dta", ///
	 keepusing(c3301_171 c3301_172 c3301_173 comp_privfund c3301_151 c3301_201 c3301_152 c3301_202 c3301_153 c3301_203 aula_privfund)

drop if _merge==2
drop _merge

merge 1:1 cod_mod anexo using "${dir}\2016\data\3 - primaria y secundaria - 300 Personal docente y no docente 303-304.dta", ///
	 keepusing(c3303_011 c3303_012 c3303_091 c3303_092 c3303_111 c3303_112 c3303_161 c3303_162 ///
	 c3303_181 c3303_182 c3303_191 c3303_192 c3303_221 c3303_222 c3303_211 c3303_212)

drop if _merge==2
drop _merge

merge 1:1 cod_mod anexo using "${dir}\2016\data\3 - primaria y secundaria - 300 Personal docente y no docente 305.dta", ///
	 keepusing(c3305_171 c3305_172 c3305_173 c3305_174 c3305_175 c3305_176 c3305_177 c3305_178 c3305_179 ///
	 c3305_151 c3305_152 c3305_153 c3305_154 c3305_155 c3305_156 c3305_157 c3305_158 ///
	 c3305_159 c3305_201 c3305_202 c3305_203 c3305_204 c3305_205 c3305_206 c3305_207 c3305_208 ///
	 c3305_209)

drop if _merge==2
drop _merge

merge 1:1 cod_mod anexo using "${temp}\Temp2016\2016_teachers_2.dta", ///
	 keepusing(c3307_0128 c3307_0228 c3307_0328 c3307_0428)

drop if _merge==2
drop _merge
	
**Number of computer teachers financed by the education sector**
rename c3301_171 tch_comp_fin_edu
label var tch_comp_fin_edu "No. of computer teachers paid by educ sector"
**Number of computer teachers financed by other public sector or (armed forces? It says F.F.A.A.)**
rename c3301_172 tch_comp_fin_pub
label var tch_comp_fin_pub "No. of computer teachers paid by other pub sector"
**Number of computer teachers financed by the municipality**
rename c3301_173 tch_comp_fin_mun
label var tch_comp_fin_mun "No. of computer teachers paid by municipality"
**Number of computer teachers financed by families, institutions, or community**
rename comp_privfund tch_comp_fin_priv
label var tch_comp_fin_priv "No. of computer teachers paid by families, instit., or community"
**Number of computer teachers with pedagogic studies: Total**
rename c3305_171 tch_comp_pd
label var tch_comp_pd "No. of computer teachers w\ pedag. studies: total"
**Number of computer teachers with pedagogic studies: Completed with degree**
rename c3305_172 tch_comp_pd_deg
label var tch_comp_pd_deg "No. of computer teachers w\ pedag. studies: degree"
**Number of computer teachers with pedagogic studies: Completed but no degree**
rename c3305_173 tch_comp_pd_nod
label var tch_comp_pd_nod "No. of computer teachers w\ pedag. studies: no degree"
**Number of computer teachers with pedagogic studies: Did not complete**
rename c3305_174 tch_comp_pd_inc
label var tch_comp_pd_inc "No. of computer teachers w\ pedag. studies: did not finish"
**Number of computer teachers with higher education (non pedagogic): Total**
rename c3305_175 tch_comp_sup
label var tch_comp_sup "No. of computer teachers w\ higher ed (non pedag.): total"
**Number of computer teachers with higher education (non pedagogic): Completed with degree**
rename c3305_176 tch_comp_sup_deg
label var tch_comp_sup_deg "No. of computer teachers w\ higher ed (non pedag.): degree"
**Number of computer teachers with higher education (non pedagogic): Completed but no degree**
rename c3305_177 tch_comp_sup_nod
label var tch_comp_sup_nod "No. of computer teachers w\ higher ed (non pedag.): no degree"
**Number of computer teachers with higher education (non pedagogic): Did not complete**
rename c3305_178 tch_comp_sup_inc
label var tch_comp_sup_inc "No. of computer teachers w\ higher ed (non pedag.): did not finish"
**Number of computer teachers with only secondary education**
rename c3305_179 tch_comp_sec
label var tch_comp_sec "No. of computer teachers w\ only secondary education"
**Number of teachers with pedagogic studies degree specifically in computer science (male)**
egen tch_pd_cs_male = rowtotal (c3307_0128 c3307_0328)
label var tch_pd_cs_male "No. of male teachers w\ pedag. degree in comp sci"
**Number of teachers with pedagogic studies degree specifically in computer science (female)**
egen tch_pd_cs_female = rowtotal (c3307_0228 c3307_0428)
label var tch_pd_cs_female "No. of female teachers w\ pedag. degree in comp sci"
**Number of classroom teachers financed by the education sector**
egen tch_aula_fin_edu = rowtotal(c3301_151 c3301_201) 
label var tch_aula_fin_edu "No. of classroom teachers paid by educ sector"
**Number of classroom teachers financed by other public sector or (armed forces? It says F.F.A.A.)**
egen tch_aula_fin_pub = rowtotal(c3301_152 c3301_202)
label var tch_aula_fin_pub "No. of classroom teachers paid by other pub sector"
**Number of classroom teachers financed by the municipality**
egen tch_aula_fin_mun = rowtotal(c3301_153 c3301_203)
label var tch_aula_fin_mun "No. of classroom teachers paid by municipality"
**Number of classroom teachers financed by families, institutions, or community**
rename aula_privfund tch_aula_fin_priv
label var tch_aula_fin_priv "No. of classroom teachers paid by families, instit., or community"
**Number of classroom teachers with pedagogic studies: Total**
egen tch_aula_pd = rowtotal(c3305_151 c3305_201)
label var tch_aula_pd "No. of classroom teachers w\ pedag. studies: total"
**Number of classroom teachers with pedagogic studies: Completed with degree**
egen tch_aula_pd_deg = rowtotal(c3305_152 c3305_202)
label var tch_aula_pd_deg "No. of classroom teachers w\ pedag. studies: degree"
**Number of classroom teachers with pedagogic studies: Completed but no degree**
egen tch_aula_pd_nod = rowtotal(c3305_153 c3305_203)
label var tch_aula_pd_nod "No. of classroom teachers w\ pedag. studies: no degree"
**Number of classroom teachers with pedagogic studies: Did not complete**
egen tch_aula_pd_inc = rowtotal(c3305_154 c3305_204)
label var tch_aula_pd_inc "No. of classroom teachers w\ pedag. studies: did not finish"
**Number of classroom teachers with higher education (non pedagogic): Total**
egen tch_aula_sup = rowtotal(c3305_155 c3305_205)
label var tch_aula_sup "No. of classroom teachers w\ higher ed (non pedag.): total"
**Number of classroom teachers with higher education (non pedagogic): Completed with degree**
egen tch_aula_sup_deg = rowtotal(c3305_156 c3305_206)
label var tch_aula_sup_deg "No. of classroom teachers w\ higher ed (non pedag.): degree"
**Number of classroom teachers with higher education (non pedagogic): Completed but no degree**
egen tch_aula_sup_nod = rowtotal(c3305_157 c3305_207)
label var tch_aula_sup_nod "No. of classroom teachers w\ higher ed (non pedag.): no degree"
**Number of classroom teachers with higher education (non pedagogic): Did not complete**
egen tch_aula_sup_inc = rowtotal(c3305_158 c3305_208)
label var tch_aula_sup_inc "No. of classroom teachers w\ higher ed (non pedag.): did not finish"
**Number of classroom teachers with only secondary education**
egen tch_aula_sec = rowtotal(c3305_159 c3305_209)
label var tch_aula_sec "No. of classroom teachers w\ only secondary education"
**Number of directors with teaching assignment**
egen tch_director = rowtotal(c3303_011 c3303_012)
label var tch_director "No. of directors with teaching assignment"
**Number of sub directors with teaching assignment**
egen tch_subdirector = rowtotal(c3303_091 c3303_092)
label var tch_subdirector "No. of subdirectors with teaching assignment"
**Number of coordinators with teaching assignment**
egen tch_coordinator = rowtotal(c3303_111 c3303_112)
label var tch_coordinator "No. of coordinators with teaching assignment"
**Number of PE teachers**
egen tch_pe = rowtotal(c3303_161 c3303_162)
label var tch_pe "No. of physical education teachers"
**Number of teachers for "Aula de Innovacion"**
egen tch_aula_innov = rowtotal(c3303_181 c3303_182)
label var tch_aula_innov "No. of teachers for Aula de Innovacion"
**Number of other special teachers**
egen tch_oth_special = rowtotal(c3303_191 c3303_192)
label var tch_oth_special "No. of other special teachers"
**Number of assistants with class hours**
egen tch_aux = rowtotal(c3303_221 c3303_222)
label var tch_aux "No. of assistants with class hours"
**Number of other teachers**
egen tch_other = rowtotal(c3303_211 c3303_212)
label var tch_other "No. of other teachers"

drop c3303_011 c3303_012 c3303_091 c3303_092 c3303_111 c3303_112 c3303_161 c3303_162 ///
	 c3303_181 c3303_182 c3303_191 c3303_192 c3303_221 c3303_222 c3303_211 c3303_212

**ENROLLMENT, GRADE RETENTION, AND MATERNAL LANGUAGE**
merge 1:1 cod_mod anexo using "${temp}\Temp2016\2016_enrollment.dta"
drop if _merge==2
drop _merge
merge 1:1 cod_mod anexo using "${temp}\Temp2016\2016_transfer_students.dta"
drop if _merge==2
drop _merge
merge 1:1 cod_mod anexo using "${temp}\Temp2016\2016_passfail.dta"
drop if _merge==2
drop _merge
merge 1:1 cod_mod anexo using "${temp}\Temp2016\2016_grade_retention.dta"
drop if _merge==2
drop _merge	
merge 1:1 cod_mod anexo using "${temp}\Temp2016\2016_maternal_lang.dta"
drop if _merge==2
drop _merge
merge 1:1 cod_mod anexo using "${temp}\Temp2016\2016_textbooks.dta"
drop if _merge==2
drop _merge

gen year = 2016
rename cod_mod codmodular

save 	"${temp}\Temp2016\CE2016_all.dta", replace
