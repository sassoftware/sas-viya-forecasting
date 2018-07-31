*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;

/**** 4.3 Regression and correlation ****/
/**** https://www.otexts.org/fpp/4/3 ****/

/** Example 4.1 Car emissions **/

*sending data from standard SAS to CAS;
data mycas.fpp_fuel;
	set time.fpp_fuel;
run;

*run Viya enabled regression PROC REGSELECT;
proc regselect data=mycas.fpp_fuel;
    
    *model option clb requests confidence limits;
	model carbon = city /clb; 
    
    *output the residules and copy the predictor variable City to the output table;
	output out=mycas.fpp_fuel_residual residual
	       copyvars = (city carbon); 
run;

/**** 4.5 Forecasting with Regression ****/
/**** https://www.otexts.org/fpp/4/5 ****/

/*to show the feature of table partitioning for regselect
we define a variable status and assign it to 'group1' and
'group2' for test and train observations, respectively.*/
data mycas.fpp_fuel_2;
	set time.fpp_fuel;
	status='group2';
run;

*add new observation for scoring;
data mycas.extra;
	length model $38 status $6; 
	input model $ cylinders litres barrels city highway cost carbon log_carbon log_city status $;
	datalines;
. . . . 30 . . . . . group1
;
run;

data mycas.fpp_fuel_2/sessref = mycas;
	set mycas.fpp_fuel_2 mycas.extra;
run;

*alpha=0.2 sets the significance level to be used for the construction of confidence intervals;
proc regselect data=mycas.fpp_fuel_2 alpha=0.2; 
	model carbon = city;
    *output upper (UCL) and lower (LCL) bound limit for fitted values;
	output out=mycas.fpp_fuel_pred ucl lcl 
	       copyvars = (city); 
    
    *partition observations with value status='group1' as the test group and status='group2' as the train group;
	partition rolevar=status(test='group1' train='group2'); 
run;

/**** 4.7 Non-linear Functional Forms ****/
/**** https://www.otexts.org/fpp/4/7 ****/

*Log-Log model regression;
data mycas.fpp_fuel/sessref = mycas;
	set mycas.fpp_fuel;
	log_carbon = log(carbon);
	log_city = log(city);
run;

proc regselect data=mycas.fpp_fuel;
	model log_carbon = log_city;

    *output the residules and copy the predictor variable Log_City to the output table;
	output out=mycas.fpp_fuel_log_residual residual
	       copyvars = (log_city);
run;

/**** 4.8 Regression with Time Series Data ****/
/**** https://www.otexts.org/fpp/4/8 ****/

/** Example 4.3 US consumption expenditure **/

*load data to CAS;
data mycas.fpp_usconsumption;
	set time.fpp_usconsumption;
run;

*use regression model to fit a model and examine the residuals and model validity;
proc regselect data=mycas.fpp_usconsumption;
	model consumption = income;
	output out=mycas.fpp_usconsumption_errors
	copyvars = (date) residual;
run;

/* Scenario based forecasting */
*create future input data for forecasting;
data mycas.new_consumption;
	input consumption income;
datalines;
. -1
. 1
;
run;

*combine the training data and the future forecast periods;
data mycas.fpp_usconsumption/sessref = mycas;
	set mycas.fpp_usconsumption mycas.new_consumption;
run;

*run regression model again to get the in-sample fits and future forecasts;
proc regselect data=mycas.fpp_usconsumption;
	model consumption = income /clb;
	output out=mycas.fpp_usconsumption_pred ucl lcl
	copyvars = (income) pred;
run;

/** Example 4.4 Linear trend **/
data mycas.fpp_austa;
	set time.fpp_austa;
run;

proc regselect data=mycas.fpp_austa;
	model tourist_arrivals = year;
	output out = mycas.fpp_austa_errors residual
	copyvars = (year);
run;

data mycas.extra;
	input year tourist_arrivals;
	datalines;
2011 .
2012 .
2013 .
2014 .
2015 .
;

data mycas.fpp_austa/sessref = mycas;
	set mycas.fpp_austa mycas.extra;
run;

proc regselect data=mycas.fpp_austa;
	model tourist_arrivals = year;
	output out = mycas.fpp_austa_pred ucl lcl pred
	copyvars = (year);
run;

/*Residual autocorrelation*/
proc tsmodel data=mycas.fpp_usconsumption_errors 
             outarray=mycas.fpp_usconsumption_acf;
	require tsa;
	id date interval=quarter;
	var residual;
	outarrays acf;
	submit;
        declare object tsa(tsa); 
        /* AUTOCORRELATION: This function computes autocorrelation and auto covariance for a time series array.
            Signature:
            rc = TSA.ACF(y, nlag, lags, df, mu, acov, acf, acfstd, acf2std, acfnorm, acfprob, acflprob);
        */
        *to calculate autocorrelation of residuals with lags 1 to 21;
		rc = tsa.acf(residual, 21, , , , , acf);
	endsubmit;
quit;

data mycas.fpp_austa_errors/sessref=mycas;
	set mycas.fpp_austa_errors;

    *variable Year is not in the date format, so we make another variable;
	years = mdy(1,1,year); 
	format years date9.;
run;

proc tsmodel data=mycas.fpp_austa_errors 
    outarray=mycas.fpp_austa_acf
		nthreads=1;
	require tsa;
	id years interval=year;
	var residual;
	outarrays acf;
	submit;
        declare object tsa(tsa);
        *calculate autocorrelation of residuals with lags 1 to 13;
		rc = tsa.acf(residual, 13, , , , , acf);
	endsubmit;
quit;

/*Spurious regression*/
data mycas.spurious;
	merge time.fpp_ausair time.fpp_guinearice;
	by year;
run;

proc regselect data=mycas.spurious;
	model passengers = rice;
	output out=mycas.spurious_errors residual
	copyvars = (year);
run;

data mycas.spurious_errors;
	set mycas.spurious_errors;
    *variable year is not in the date format, so we make another variable;
	years = mdy(1,1,year);
run;

proc tsmodel data=mycas.spurious_errors
             outarray=mycas.spurious_errors_acf;
	require tsa;
	id years interval=year;
	var residual;
	outarrays acf;
	submit;
        declare object tsa(tsa);
		rc = tsa.acf(residual, 21, , , , , acf);
	endsubmit;
quit;;
