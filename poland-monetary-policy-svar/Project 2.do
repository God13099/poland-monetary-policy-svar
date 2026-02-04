/*------------------------------------------------------------------------------
  Project:  Monetary Policy Transmission in Poland: A Structural VAR Approach
  Author:   Liyuan Cao
  Date:     February 2026
  Dataset:  St. Louis FED (FRED) and Local CPI Supplements
  
  Objective:
  This script estimates a Sims (1980) style SVAR to evaluate the dynamic 
  effects of monetary policy shocks on Poland's GDP and inflation. 
  The analysis accounts for the WIBOR-WIRON transition and structural 
  shifts post-2004 inflation targeting.
------------------------------------------------------------------------------*/
* =======================================================
* 0. Initialization & Setup
* =======================================================
clear all
set more off
macro drop _all
capture log close
log using "Poland_SVAR_Master.log", replace

* Automatically install freduse
capture ssc install freduse

* =======================================================
* Step 0: Processing locally uploaded inflacja.csv 
* =======================================================
di "Step 0: Processing uploaded inflation CSV data..."

* 1. Import CSV file 
import delimited "inflacja.csv", clear varnames(1)

* 2. Rename variables 
rename label month_label
rename v2 y2022
rename v3 y2023
rename v4 y2024
rename v5 y2025

* 3. Convert month names to numbers
gen month = .
replace month = 1 if month_label == "January"
replace month = 2 if month_label == "February"
replace month = 3 if month_label == "March"
replace month = 4 if month_label == "April"
replace month = 5 if month_label == "May"
replace month = 6 if month_label == "June"
replace month = 7 if month_label == "July"
replace month = 8 if month_label == "August"
replace month = 9 if month_label == "September"
replace month = 10 if month_label == "October"
replace month = 11 if month_label == "November"
replace month = 12 if month_label == "December"

* Check if conversion was successful (there should be no missing values)
list month_label month if month == .

* 4. Reshape data from wide to long format
reshape long y, i(month) j(year)
rename y inflation_yoy_manual

* 5. Generate quarterly date and aggregate
* Convert monthly YoY inflation to quarterly average
gen qdate = yq(year, ceil(month/3))
format qdate %tq

collapse (mean) inflation_yoy_manual, by(qdate)

* Save as a temporary file for merging in later steps
tempfile manual_inflation
save `manual_inflation'

di "Step 0 Complete: CSV data processed and saved."

* =======================================================
* (a) Data download from FRED 
* =======================================================
di "Step (a): Downloading base data from FRED..."

capture freduse CLVMNACSCAB1GQPL POLCPALTT01IXNBM IR3TIB01PLM156N POPTOTPLA647NWDB, clear

if _rc != 0 {
    di as error "FRED download failed. Check internet connection."
    exit
}

rename CLVMNACSCAB1GQPL real_gdp
rename POLCPALTT01IXNBM cpi
rename IR3TIB01PLM156N  interest_rate_monthly
rename POPTOTPLA647NWDB population_annual

* ===========================================================================
* VARIABLE DEFINITION: Short-Term Interest Rate
* ===========================================================================
* The short-term interest rate is proxied by the 3-month interbank rate from 
* FRED (Series ID: IR3TIB01PLM156N).
*
* Context:
* In the Polish context, the 3-month interbank rate corresponds to the 
* WIBOR 3M fixing, which has been the main benchmark rate for monetary 
* policy transmission throughout the sample period (1998–2025).
*
* Note on Transition:
* Although Poland has recently started transitioning from WIBOR to WIRON, 
* WIBOR 3M remains the relevant policy rate for the historical period 
* analyzed in this paper.
* ===========================================================================

* =======================================================
* Date handling and quarterly conversion
* =======================================================
gen date_num = date(date, "YMD")
gen qdate = yq(year(date_num), quarter(date_num))
format qdate %tq

* 1. Aggregate CPI and interest rate to quarterly (mean)
* 2. Aggregate GDP and annual population (first/mean)
collapse (mean) cpi interest_rate_monthly population_annual (first) real_gdp, by(qdate)

rename interest_rate_monthly interest_rate

* =======================================================
* Interpolate Population (Annual to Quarterly)
* =======================================================
tsset qdate
* Interpolate annual population to fill quarterly values
ipolate population_annual qdate, gen(population_sa) epolate

di "Data download and interpolation complete."

* =======================================================
* (b) & (c) Time series declaration and sample definition
* =======================================================
di "Step (b) & (c): Declaring time series and defining analysis sample..."

* Declare quarterly time series
tsset qdate, quarterly

* Define post-inflation-targeting sample (starting 2004Q1)
gen sample_2004 = qdate >= yq(2004,1)
label var sample_2004 "Post-inflation-targeting sample (>=2004Q1)"

* Merge manually collected inflation data
merge 1:1 qdate using `manual_inflation'
drop _merge

* Reconstruct CPI using YoY inflation (for 2024–2025)
replace cpi = L4.cpi * (1 + inflation_yoy_manual/100) ///
    if cpi == . & year(dofq(qdate)) == 2024

replace cpi = L4.cpi * (1 + inflation_yoy_manual/100) ///
    if cpi == . & year(dofq(qdate)) == 2025

* check the result
di "Data Check: 2024-2025 CPI Index Reconstruction:"
list qdate cpi inflation_yoy_manual if qdate >= yq(2023,4)


* =======================================================
* (d) Growth rates and inflation (Final Variables)
* =======================================================
di "Step (d): Generating SVAR Variables (Per Capita)..."

* 1. Construct Real GDP Per Capita
gen real_gdp_capita = real_gdp / population_sa

* 2. Take natural logs
gen ln_cpi = ln(cpi)
gen ln_gdp_cap = ln(real_gdp_capita)

* 3. Compute annualized growth rates (400 * log difference)
gen inflation   = 400 * (ln_cpi - L.ln_cpi)
gen gdp_growth  = 400 * (ln_gdp_cap - L.ln_gdp_cap)

label var inflation     "CPI Inflation (Annualized)"
label var gdp_growth    "Real GDP Per Capita Growth (Annualized)"
label var interest_rate "WIBOR 3M"

* Check the data to ensure no significant missing values
list qdate inflation gdp_growth interest_rate in -5/l

* =======================================================
* (f) Stationarity tests (ADF) – 2004Q1–2025Q2
* =======================================================
di "Step (f): Unit root tests (Strict Sample, lag4)..."

* GDP growth (stationary by construction, with intercept)
dfuller gdp_growth    if inrange(qdate, yq(2004,1), yq(2025,2)), lags(4) drift

* Inflation rate (with intercept)
dfuller inflation     if inrange(qdate, yq(2004,1), yq(2025,2)), lags(4) drift

* Interest rate (with intercept)
dfuller interest_rate if inrange(qdate, yq(2004,1), yq(2025,2)), lags(4) drift

* ===========================================================================
* Unit Root Test Results (Robustness Check with 4 lags & drift):
*
* 1. GDP Growth: Strongly rejects the null hypothesis of a unit root at the 1% level (t = -5.034, p = 0.0000).
*
* 2. Inflation: Rejects the null hypothesis at the 1% level (t = -2.972, 
* p = 0.0020), showing stronger evidence of stationarity.
* (Note: Test statistic -2.972 < 1% critical value -2.374)
*
* 3. Interest Rate: Rejects the null hypothesis at the 5% level (t = -2.332, 
* p = 0.0111). It is borderline significant at the 1% level.
* (Note: Test statistic -2.332 < 5% critical value -1.664)
* ===========================================================================

* =======================================================
* (g) SVAR estimation: Sims (1980) –use lag4
* =======================================================
di "Step (g): Estimating SVAR with lag4..."

* =======================================================
* Lag selection for SVAR (based on VAR diagnostics)
* =======================================================
* Based on the VAR lag selection table (Sample: 2004Q1–2025Q2):
*   - AIC minimal at lag 4 (12.6741)
*   - FPE minimal at lag 4 (64.5533)
*   - LR test: addition of 4th lag significant (p = 0.004)
*   - HQIC minimal at lag 2; SBIC minimal at lag 1 (shorter lags)
* Decision:
*   - Choose lag 4 for the SVAR to capture quarterly dynamics
*   - This aligns with Sims (1980) style for quarterly macro data
*   - Although SBIC suggests shorter lag, lag 4 improves model fit 
*     and preserves impulse response dynamics.

* Lag selection 
varsoc gdp_growth inflation interest_rate if inrange(qdate, yq(2004,1), yq(2025,2))

* Identification Matrix (GDP -> Inflation -> Interest Rate)
matrix A = (1,0,0 \ ///
            .,1,0 \ ///
            .,.,1)
			
matrix B = (.,0,0 \ ///
            0,.,0 \ ///
            0,0,.)

* Using lag4 to estimate VAR
svar gdp_growth inflation interest_rate ///
     if inrange(qdate, yq(2004,1), yq(2025,2)), ///
     lags(1/4) aeq(A) beq(B)

irf set svar_poland_final, replace
irf create sims_strict, step(12) replace

* Clean Layout
irf graph oirf, ///
    yline(0, lcolor(black) lwidth(thin)) ///
    level(95) ///
    xlabel(0(4)12, labsize(small)) ///    
    ylabel(, labsize(small)) ///          
    xsize(10) ysize(8) ///                
    byopts( ///
        yrescale xrescale row(3) ///
        title("Structural Impulse Responses (Sims 1980, lag4)", size(medium)) /// 
        subtitle(, size(vsmall)) ///      
        note("") ///                      
        graphregion(margin(small)) ///    
    ) ///
    name(g1_main_clean, replace)


* =======================================================
* (h) Alternative ordering 
* =======================================================
di "Step (h): Alternative ordering (Inflation -> Interest Rate -> GDP, lag4)..."

matrix A_alt = (1,0,0 \ ///
                .,1,0 \ ///
                .,.,1)

matrix B = (.,0,0 \ ///
            0,.,0 \ ///
            0,0,.)
			
svar inflation interest_rate gdp_growth ///
     if inrange(qdate, yq(2004,1), yq(2025,2)), ///
     lags(1/4) aeq(A_alt) beq(B)

irf set svar_alt, replace
irf create alt_order, step(12) replace

irf graph oirf, ///
    impulse(interest_rate) ///
    response(gdp_growth inflation interest_rate) ///
    yline(0) level(95) ///
    xsize(10) ysize(6) ///
    title("Alternative Ordering: Monetary Policy Shock (lag4)") ///
    name(g2_alt, replace)


* =======================================================
* (i) Full sample estimation (1998Q1–2025Q2) 
* =======================================================
di "Step (i): Full sample estimation (lag4)..."

* Re-define Matrix A (Original Ordering) just to be safe
matrix A = (1,0,0 \ ///
            .,1,0 \ ///
            .,.,1)

* Ensure B is defined (Diagonal)
matrix B = (.,0,0 \ ///
            0,.,0 \ ///
            0,0,.)

svar gdp_growth inflation interest_rate ///
     if inrange(qdate, yq(1998,1), yq(2025,2)), ///
     lags(1/4) aeq(A) beq(B)

irf set svar_full, replace
irf create full_sample, step(12) replace

irf graph oirf, ///
    impulse(interest_rate) ///
    response(gdp_growth inflation interest_rate) ///
    yline(0) level(95) ///
    xsize(10) ysize(6) ///
    title("Full Sample Analysis (1998-2025, lag4)") ///
    name(g3_full, replace)


* =======================================================
* (j) Pre-COVID sample 
* =======================================================
di "Step (j): Pre-COVID sample (lag4)..."

svar gdp_growth inflation interest_rate ///
     if inrange(qdate, yq(2004,1), yq(2019,4)), ///
     lags(1/4) aeq(A) beq(B)

irf set svar_precovid, replace
irf create pre_covid, step(12) replace

irf graph oirf, ///
    impulse(interest_rate) ///
    response(gdp_growth inflation interest_rate) ///
    yline(0) level(95) ///
    xsize(10) ysize(6) ///
    title("Pre-COVID Sample (2004-2019, lag4)") ///
    name(g4_precovid, replace)

log close
di "All tasks completed successfully."
