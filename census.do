***	This do file merges, cleans and edits National Agriculture Census data.	***

global gtd "D:\ConflictViolence\Peru\Data\Stata\GTD"
global census "D:\ConflictViolence\Peru\Data\Stata\National Agricultural Census"
global temp "D:\ConflictViolence\Peru\Data\Stata\Temp\National Agricultural Census"
global albertus "D:\ConflictViolence\Peru\Data\Stata\Michael_Albertus"
global final "D:\ConflictViolence\Peru\Data\Stata\Final"
global spatial "D:\ConflictViolence\Peru\Data\Stata\Spatial"


clear 
set more off

local i = 6
local j = 3
*filelist, dir("${census}") pat("*_01.dta")


foreach dist in Amazonas Ancash Apurimac Arequipa Ayacucho Cajamarca Callao Cusco Huancavelica ///
				Huanuco Ica Junin LaLibertad Lambayeque Lima Loreto MadredeDoise Moquegua Pasco Piura ///
				Puno SanMartin Tacna Tumbes	Ucayali	{
				
local i = `i' + 1
				
if (`i'>9)	{
	local i = 0
	local j = `j' + 1
	}
		
				
* Module 1	*
use "${census}/`dist'/3`j'`i'_01.dta", clear

rename *, lower

destring p001 p002 p003 p007x p008 nprin, replace

egen unit_id = group (p001 p002 p003 p007x p008)

gen department = p001
gen province = p002
gen district = p003
gen sector = p007x
gen unit = p008
gen farmer_id = nprin

bys farmer_id: gen place = _n
drop if place>1
drop place

gen read_write = .
replace read_write = 0			if p017==2
replace read_write = 1			if p017==1
label var read_write "=1 if can read and write"

gen no_parcel_worked = p019
replace no_parcel_worked = 0	if p019_01!=.
label var no_parcel worked "No of parcels worked in own district"

gen area_farmed = p020_01
replace area_farmed = 0			if p019_01!=.
label var area_farmed "Area farmed in own district"

gen live_parcel_farmed = .
replace live_parcel_farmed = 0	if p021==2
replace live_parcel_farmed = 1	if p021==1

gen parcel_other_dist = .
replace parcel_other_dist = 0		if p022==2
replace parcel_other_dist = 1		if p022==1
label var parcel_other_dist "=1 if parcels farmed in other districts"

gen no_parcel_worked_other_dist = p022_01
label var no_parcel_worked_other_dist "No of parcels worked in other districts"

egen total_parcel_worked = rowtotal(no_parcel_worked no_parcel_worked_other_dist)
label var total_parcel_worked "Total parcels worked on"

gen arable_land = wsup03
label var arable_land "area that is arable"

gen arable_irrigated_land = wsup03a
label var arable_irrigated_land "area of arable land under irrigation"

gen arable_nonirrigated_land = wsup03b
label var arable_irrigated_land "area of arable land under dry land"

gen nonag_land = wsup04
label var nonag_land "area that is non agricultural land"

gen other_land = wsup05
label var other_land "area that is other land"

gen temp_crop_land = wsup07
label var temp_crop_land "area that has temporary crops"

gen fallow_land = wsup08
label var fallow_land "area that is fallow land"

gen atrest_land = wsup09
label var atrest_land "area that is not used currently"

gen perm_crop_land = wsup10
label perm_crop_land "area with permanent crops"

gen cultiv_pasture_land = wsup11
label var cultiv_pasture_land "area that is cultivated pastures"

gen forest_crop_land = wsup12
label var forest_crop_land "area that is forest crops"

gen forest_pasture_land = wsup14 
label var forest_pasture_land "area that is natural pasture land"

gen manag_pasture_land = wsup15 
label var manag_pasture_land "area that is managed pasture land"

gen unmanag_pasture_land = wsup16
label var unmanag_pasture_land "area that is unmanaged pasture land"

gen forest_mount_land = wsup17
label var forest_mount_land "area that is mountains and forests"

gen cultiv_area = wsup18
label var cultiv_area "area that is cultivated"

gen hhsize = wp109
label var hhsize "Household size"

gen female = .
replace female = 0				if wp111==1
replace female = 1				if wp111==2
label var female "=1 if female"

gen age = wp112
label var age "age in years"

gen education = wp114
label var education "education in years"

gen altitude = waltitud
label var altitude "altitude of the ag. sector"

gen longitude_sector = long_deci
label var longitude_sector "longitude of the ag. sector"

gen latitude_sector = lat_deci
label var latitude_sector "latitude of the ag. sector"

keep department province district sector unit unit_id farmer_id  ///
	 read_write *_parcel_* parcel_* hhsize female age education ///
	 altitude *_sector *_land area_farmed cultiv_area
		
save "${temp}/`dist'/basic.dta", replace



** Module 2	**
use "${census}/`dist'/3`j'`i'_02.dta", clear

rename *, lower

destring p001 p002 p003 p007x p008 nprin, replace

gen area_farmed_other_district = p023_04

gen farmer_id = nprin

collapse (sum) area_farmed_other_district, by(p001 p002 p003 p007x p008 farmer_id)
label var area_farmed_other_district "area farmed in other districts"

bys farmer_id: gen place = _n
drop if place>1
drop place

egen unit_id = group (p001 p002 p003 p007x p008)

gen department = p001
gen province = p002
gen district = p003
gen sector = p007x
gen unit = p008


keep 	area_farmed_other_district department province district sector unit ///
		unit_id farmer_id

save "${temp}/`dist'/basic_2.dta", replace


** Module 3 **
*Creating the number of plots variable
use "${census}/`dist'/3`j'`i'_03.dta", clear

rename *, lower

destring p001 p002 p003 p007x p008 nprin, replace

gen farmer_id = nprin

gen plot_no = nparcx

egen number_plots = max(plot_no), by(farmer_id)

collapse (max) number_plots, by(p001 p002 p003 p007x p008 farmer_id) 

label var  number_plots "number of plots per farmer"
label var plot_no "plot id"

bys farmer_id: gen place = _n
drop if place>1
drop place

gen department = p001
gen province = p002
gen district = p003
gen sector = p007x
gen unit = p008

egen unit_id = group (p001 p002 p003 p007x p008)

save "${temp}/`dist'/number_plots.dta", replace


* Creating plot_no for merging later
use "${census}/`dist'/3`j'`i'_03.dta", clear

rename *, lower

destring p001 p002 p003 p007x p008 nprin, replace

gen farmer_id = nprin

gen plot_no = nparcx

collapse (max) p001 p002 p003 p007x p008, by(farmer_id plot_no) 

label var plot_no "plot id"

gen department = p001
gen province = p002
gen district = p003
gen sector = p007x
gen unit = p008

egen unit_id = group (p001 p002 p003 p007x p008)

save "${temp}/`dist'/plot_no.dta", replace


* Creating plot use information
use "${census}/`dist'/3`j'`i'_03.dta", clear

rename *, lower

destring p001 p002 p003 p007x p008 nprin, replace

gen department = p001
gen province = p002
gen district = p003
gen sector = p007x
gen unit = p008
gen farmer_id = nprin

egen unit_id = group (p001 p002 p003 p007x p008)

gen plot_no = nparcx
label var plot_no "plot id"

gen for_sale = .
replace for_sale = 0 			if p028!=1
replace for_sale = 1 			if p028==1
label var for_sale "=1 if crop for sale"

gen for_consumption = .
replace for_consumption = 0 	if p028!=2 & p028!=3
replace for_consumption = 1 	if p028==2 | p028==3
label var for_consumption "=1 if for own consumption"

gen for_livestock = .
replace for_livestock = 0 		if p028!=4
replace for_livestock = 1 		if p028==4
label var for_livestock "=1 if for livestock consumption"

drop if 		for_sale==. | for_consumption==. | for_livestock==.		//0 obervation deleted//

rename	p024_01 crop_no
label var ctop_no "crop id"

rename 	p025 	crop_area
label var crop_area "area covered by the crop"

keep department province district sector unit unit_id farmer_id plot_no for_* crop_*

save "${temp}/`dist'/crop_details.dta", replace



** Module 4	** 
use "${census}/`dist'/3`j'`i'_04.dta", clear

rename *, lower

destring p001 p002 p003 p007x p008 nprin, replace

gen department = p001
gen province = p002
gen district = p003
gen sector = p007x
gen unit = p008
gen farmer_id = nprin

egen unit_id = group (p001 p002 p003 p007x p008)

gen plot_no = nparcy

gen land_owner = 0
replace land_owner = 1			if p037_01_01 == 1
label var land_owner "=1 if own the land"

forvalues g = 1/4	{
	gen ownership_`g' = .
	replace ownership_`g' = 0	if p037_01_01 == 1
	replace ownership_`g' = 1	if p037_01_03==`g' & p037_01_01==1
		}

rename ownership_1 ownership_title_reg
label var ownership_title_reg "=1 if owner with registered title"

rename ownership_2 ownership_title_notreg
label var ownership_title_notreg "=1 if owner without registered title"

rename ownership_3 ownership_wait_title
label var ownership_wait_title "=1 if owner and waiting for title"

rename ownership_4 ownership_no_title
label var ownership_no_title "=1 if owner without title"


gen land_communitymem = 0
replace land_communitymem = 1	if p037_02_01 == 1
label var land_communitymem "=1 if land is community owned"

gen land_renter = 0
replace land_renter = 1			if p037_03_01 == 1
laber var land_renter "=1 if renting the land"

gen land_possessor = 0
replace land_possessor = 1		if p037_04_01 == 1
label var land_possessor "=1 if possessor of the land"

gen land_other = 0
replace land_other = 1			if p037_05_01 == 1
label var land_other "=1 if any other type of land ownership status"

local k = 1
foreach var of varlist land_owner land_communitymem land_renter land_possessor	///
							land_other {
	gen `var'_size = p037_0`k'_02		if p037_0`k'_01==1 
	label `var'_size "area of land if `var' "
	local k = `k' + 1
	}	
	
foreach var of varlist ownership_title_reg ownership_title_notreg ///
				ownership_wait_title ownership_no_title	{
	gen `var'_size = p037_01_02 		if p037_01_01==1 & `var'==1
	label `var'_size "area of land if owner is `var' "
	}
	
gen plot_unsown = 0
replace plot_unsown = 1			if p036!=.
label car plot_unsown "=1 if plot is not sown with seeds"

keep department province district sector unit unit_id farmer_id plot_no land_* ownership_* plot_unsown

bys farmer_id plot_no: gen place = _n
drop if place>1
drop place
	
save "${temp}/`dist'/land_ownership.dta", replace


**	Merging the datasets	**
use "${temp}/`dist'/basic.dta", clear

merge 1:1 farmer_id using "${temp}/`dist'/basic_2.dta", keepusing (area_farmed_other_district)
drop if _merge==2
drop _merge

merge 1:1 farmer_id using "${temp}/`dist'/number_plots.dta", keepusing (number_plots)
drop if _merge==2
drop if _merge==1	//783 observations deleted//
drop _merge

merge 1:m farmer_id using "${temp}/`dist'/plot_no.dta", keepusing (plot_no)
drop if _merge==2
drop _merge

merge 1:1 farmer_id plot_no using "${temp}/`dist'/land_ownership.dta", keepusing (land_* ownership_* plot_unsown)
drop if _merge==2
drop _merge

save "${temp}/`dist'/final.dta", replace

merge 1:m farmer_id plot_no using "${temp}/`dist'/crop_details.dta", keepusing (plot_no for_* crop_*)
drop if _merge==2
drop _merge

save "${temp}/`dist'/final_2.dta", replace

}



** Appending the final datasets for each department	**
use "${temp}/Amazonas/final.dta", clear

foreach dist in Ancash Apurimac Arequipa Ayacucho Cajamarca Callao Cusco Huancavelica ///
				Huanuco Ica Junin LaLibertad Lambayeque Lima Loreto MadredeDoise Moquegua Pasco Piura ///
				Puno SanMartin Tacna Tumbes	Ucayali	{
				
	append using "${temp}/`dist'/final.dta", force
				}
				
bys farmer_id plot_no: gen place = _n
drop if place>1		//255 observations deleted//
drop place

egen plot_id = group(farmer_id plot_no)
								
geoinpoly lat lon using "${spatial}\outline_coor_p.dta"			
tab _ID, missing
drop if _ID==.
drop _ID			
geoinpoly lat lon using "${spatial}\dept_coor.dta"		
merge m:1 _ID using "${spatial}\dept_data.dta", ///
		keep(match using)
drop if _merge==2
drop _merge	
rename _ID dept
drop Shape_Leng Shape_Area ADM1_ES ADM1_REF ADM1ALT1ES ADM1ALT2ES ///
		ADM1_PCODE ADM0_EN ADM0_PCODE ADM0_ES date ///
		validOn validTo

geoinpoly lat lon using "${spatial}\outline_coor_p.dta"			
tab _ID, missing
drop if _ID==.
drop _ID			
geoinpoly lat lon using "${spatial}\province_coor.dta"		
merge m:1 _ID using "${spatial}\province_data.dta", ///
		keep(match using)
drop if _merge==2
drop _merge	
rename _ID prov
drop Shape_Leng Shape_Area ADM2_ES ADM2_REF ADM2ALT1ES ADM2ALT2ES ///
		ADM2_ES ADM1_ES ADM2_PCODE ADM1_PCODE ADM0_EN ADM0_PCODE ADM0_ES date ///
		validOn validTo
		
geoinpoly lat lon using "${spatial}\outline_coor_p.dta"				
tab _ID, missing
drop if _ID==.
drop _ID				
geoinpoly lat lon using "${spatial}\district_coor.dta"				
merge m:1 _ID using "${spatial}\district_data.dta", ///
		keep(match using)
drop if _merge==2
drop _merge	
rename _ID dist
drop Shape_Leng Shape_Area ADM3_PCODE ADM3_REF ADM3ALT1ES ADM3ALT2ES ///
		ADM2_PCODE ADM1_PCODE ADM0_EN ADM0_PCODE date ///
		validOn validTo
		
save "${final}/final_census.dta", replace



use "${temp}/Amazonas/final_2.dta", clear

foreach dist in Ancash Apurimac Arequipa Ayacucho Cajamarca Callao Cusco Huancavelica ///
				Huanuco Ica Junin LaLibertad Lambayeque Lima Loreto MadredeDoise Moquegua Pasco Piura ///
				Puno SanMartin Tacna Tumbes	Ucayali	{
				
	append using "${temp}/`dist'/final_2.dta", force
				}	
				
egen plot_id = group(farmer_id plot_no)
				
geoinpoly lat lon using "${spatial}\outline_coor_p.dta"			
tab _ID, missing
drop if _ID==.
drop _ID			
geoinpoly lat lon using "${spatial}\dept_coor.dta"		
merge m:1 _ID using "${spatial}\dept_data.dta", ///
		keep(match using)
drop if _merge==2
drop _merge	
rename _ID dept
drop Shape_Leng Shape_Area ADM1_ES ADM1_REF ADM1ALT1ES ADM1ALT2ES ///
		ADM1_PCODE ADM0_EN ADM0_PCODE ADM0_ES date ///
		validOn validTo

geoinpoly lat lon using "${spatial}\outline_coor_p.dta"			
tab _ID, missing
drop if _ID==.
drop _ID			
geoinpoly lat lon using "${spatial}\province_coor.dta"		
merge m:1 _ID using "${spatial}\province_data.dta", ///
		keep(match using)
drop if _merge==2
drop _merge	
rename _ID prov
drop Shape_Leng Shape_Area ADM2_ES ADM2_REF ADM2ALT1ES ADM2ALT2ES ///
		ADM2_ES ADM1_ES ADM2_PCODE ADM1_PCODE ADM0_EN ADM0_PCODE ADM0_ES date ///
		validOn validTo
		
geoinpoly lat lon using "${spatial}\outline_coor_p.dta"				
tab _ID, missing
drop if _ID==.
drop _ID				
geoinpoly lat lon using "${spatial}\district_coor.dta"				
merge m:1 _ID using "${spatial}\district_data.dta", ///
		keep(match using)
drop if _merge==2
drop _merge	
rename _ID dist
drop Shape_Leng Shape_Area ADM3_PCODE ADM3_REF ADM3ALT1ES ADM3ALT2ES ///
		ADM2_PCODE ADM1_PCODE ADM0_EN ADM0_PCODE date ///
		validOn validTo
		
save "${final}/final_census_2.dta", replace
