*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;

/**** Chapter 5 Time series regression models ****/
/**** 5.1 The linear model ****/
/**** https://otexts.org/fpp2/regression-intro.html ****/

*sending data from standard SAS to CAS;
data mycas.fpp2_uschange;
	set time.fpp2_uschange;
run;

/**** Simple linear regression ****/
/**** Example: US consumption expenditure ****/
proc regselect data=mycas.fpp2_uschange;
	model consumption = income;
    *output upper (UCL) and lower (LCL) bound limit for fitted values;
	output out=mycas.fpp2_uschange_pred predicted ucl lcl
	copyvars = (consumption income);
run;

/**** Multiple linear regression ****/
/**** Example: US consumption expenditure ****/
*calling the correlation action from the cas simple action set;
proc cas;
    session mycas;
    simple.correlation/
        inputs={"consumption", "income", "production", "savings", "unemployment"}
		table={name="fpp2_uschange"}
		pearsonOut={name="fpp2_uschange_correlation", replace=TRUE};
run;
quit;

/**** 5.2 Least squares estimation ****/
/**** https://otexts.org/fpp2/least-squares.html ****/
/**** Example: US consumption expenditure ****/
proc regselect data=mycas.fpp2_uschange;
	model consumption = income production unemployment savings;
    *fitted values and output upper (UCL) and lower (LCL) bound limit for fitted values;
	output out=mycas.fpp2_uschange_pred ucl lcl
	copyvars=(consumption date) residual pred; 
run;

/**** 5.3 Evaluating the regression model ****/
/**** https://otexts.org/fpp2/regression-evaluation.html ****/
/**** Spurious regression ****/

proc tsmodel data=mycas.fpp2_uschange_pred
             outarray=mycas.fpp2_uschange_pred_acf_wn;
	id date interval=quarter;
	var residual;
	outarrays acf outarrays lags df wn wnprob wnlprob;
	require tsa;
	submit;
        declare object tsa(tsa);

        /* AUTOCORRELATION: This function computes autocorrelation and auto covariance for a time series array.
           Signature:
           rc = TSA.ACF(y, nlag, lags, df, mu, acov, acf, acfstd, acf2std, acfnorm, acfprob, acflprob);
        */
        rc = tsa.acf(residual, 16, , , , , acf);
        
        /* WHITE NOISE: This function performs the white noise test for a time series array.
           Signature:
           rc = TSA.WHITENOISE(y, nlag, lags, df, wn, wnprob, wnlprob);
        */
        rc = tsa.whitenoise(residual, 8, lags,df, wn, wnprob, wnlprob);
	endsubmit;
quit;

*renaming the variable name to prevent confusion;
data time.fpp2_ausair_2011;
	set time.fpp2_ausair(rename=(value=aussies));
	where year(date)<=2011;
run;

*renaming the variable name to prevent confusion;
data time.fpp2_guinearice_2011;
	set time.fpp2_guinearice(rename=(value=guinearice));
run;

* combining two datasets;
data mycas.fpp2_combined;
	set time.fpp2_ausair_2011;
	set time.fpp2_guinearice_2011;
run;

proc regselect data=mycas.fpp2_combined;
	model aussies = guinearice;
	output out=mycas.fpp2_fit
	copyvars= (date) residual;
run;

proc tsmodel data=mycas.fpp2_fit
             outarray=mycas.fpp2_fit_acf_wn;
	id date interval=year;
	var residual;
	outarrays acf outarrays lags df wn wnprob wnlprob;
	require tsa;
	submit;
        declare object tsa(tsa);

        /* AUTOCORRELATION: This function computes autocorrelation and auto covariance for a time series array.
           Signature:
           rc = TSA.ACF(y, nlag, lags, df, mu, acov, acf, acfstd, acf2std, acfnorm, acfprob, acflprob);
        */
        rc = tsa.acf(residual, 16, , , , , acf);
        
        /* WHITE NOISE: This function performs the white noise test for a time series array.
           Signature:
           rc = TSA.WHITENOISE(y, nlag, lags, df, wn, wnprob, wnlprob);
        */
        rc = tsa.whitenoise(residual, 8, lags,df, wn, wnprob, wnlprob);
	endsubmit;
quit;

/**** 5.4 Some useful predictors ****/
/**** https://otexts.org/fpp2/useful-predictors.html ****/
/**** Example: Australian quarterly beer production ****/

data mycas.fpp2_ausbeer_1992;
    set time.fpp2_ausbeer;
	where year(date)>=1992;
run;

*create quarterly seasonal dummies;
proc tsmodel data=mycas.fpp2_ausbeer_1992
             outarray = mycas.fpp2_ausbeer_1992;
    id date interval=quarter;
	var ausbeer;
    outarrays q1 q2 q3 q4;
    submit;
        do i = 1 to dim(ausbeer);
            *initialize outarrays to 0's;
            q1[i] = 0; q2[i] = 0; q3[i] = 0; q4[i] = 0;

            *set outarray q's based on the pre-defined array _season_;
            if _season_[i] = 1 then q1[i] = 1;
            else if _season_[i] = 2 then q2[i] = 1;
            else if _season_[i] = 3 then q3[i] = 1;
            else q4[i] = 1;
        end;
    endsubmit;
quit;

*no need to define trend variable. proc tsmodel will generate _cycle_ variable which addresses time;
proc regselect data=mycas.fpp2_ausbeer_1992;
	model ausbeer = _cycle_ q2 q3 q4;
	output out=mycas.fpp2_ausbeer_1992_fit;
run;

proc tsmodel data=mycas.fpp2_ausbeer_1992
             outarray = mycas.fpp2_ausbeer_fourier;
    id date interval=quarter;
	var ausbeer;
    outarrays sin14 cos14 cos24;
    submit;
        do i = 1 to dim(ausbeer);
            /* set outarrays to the fourier coefficients using pre-defined _CYCLE_ number */
			sin14[i] = sin(constant("pi")*_CYCLE_[i]/2);
			cos14[i] = cos(constant("pi")*_CYCLE_[i]/2);
			cos24[i] = cos(constant("pi")*_CYCLE_[i]);
        end;
    endsubmit;
quit;

proc regselect data = mycas.fpp2_ausbeer_fourier;
	model ausbeer = _CYCLE_ sin14 cos14 cos24;
run;

/**** 5.5 Selecting predictors ****/
/**** https://otexts.org/fpp2/selecting-predictors.html ****/
/**** Example: US consumption ****/

proc regselect data=mycas.fpp2_uschange;
	model consumption = income production unemployment savings;
	selection method=stepwise(select=AICC);
run;

/**** 5.6 Forecasting with regression ****/
/**** https://otexts.org/fpp2/forecasting-regression.html ****/
/**** Example: Australian quarterly beer production ****/

data mycas.fpp2_ausbeer_1992;
    set time.fpp2_ausbeer;
	where year(date) >= 1992;
run;

* creating new data for forecast;
data mycas.newdata;
	do i=2010 to 2013;
		if i=2010 then do;
			do j=3 to 4;
				date = yyq(i,j);
				ausbeer = .;
				output;
			end;
		end;
		else do;
			do j=1 to 4;
				date = yyq(i,j);
				ausbeer = .;
				output;
			end;
		end;
	end;
	format date YYQC6.;
	keep date ausbeer;
run;

* merging the two datasets;
data mycas.fpp2_ausbeer_1992;
	set mycas.fpp2_ausbeer_1992 mycas.newdata;
run;

*create quarterly seasonal dummies;
proc tsmodel data=mycas.fpp2_ausbeer_1992
             outarray = mycas.fpp2_ausbeer_1992;
    id date interval=quarter;
	var ausbeer;
    outarrays q1 q2 q3 q4;
    submit;
        do i = 1 to dim(ausbeer);
            *initialize outarrays to 0's;
            q1[i] = 0; q2[i] = 0; q3[i] = 0; q4[i] = 0;

            *set outarray q's based on the pre-defined array _season_;
            if _season_[i] = 1 then q1[i] = 1;
            else if _season_[i] = 2 then q2[i] = 1;
            else if _season_[i] = 3 then q3[i] = 1;
            else q4[i] = 1;
        end;
    endsubmit;
quit;

* no need to define trend variable. proc tsmodel will generate _cycle_ variable which addresses time;
* pay attention to the Number of Observations Used (74) and Number of Observations Read (88) in the results;
proc regselect data=mycas.fpp2_ausbeer_1992;
	model ausbeer = _cycle_ q2 q3 q4;
	output out=mycas.fpp2_ausbeer_1992_fit ucl lcl
	copyvars = (date) pred;
run;

/**** Scenario based forecasting ****/
/**** https://otexts.org/fpp2/forecasting-regression.html ****/

data mycas.newdata_up;
	date = yyq(2016,4);
	Income =1;
	Savings=0.5;
	Unemployment=0;
	Consumption=.;
	output;
	do i = 1 to 3;
		date = yyq(2017,i);
		Income =1;
		Savings=0.5;
		Unemployment=0;
		Consumption=.;
		output;
	end;
	format date YYQC6.;
	keep date Consumption Income Savings Unemployment;
run;

data mycas.fpp2_uschange;
	set time.fpp2_uschange;
	keep date Consumption Income Savings Unemployment;
run;

data mycas.fpp2_uschange;
	set mycas.fpp2_uschange mycas.newdata_up;
run;

proc regselect data=mycas.fpp2_uschange;
	model consumption = income savings unemployment;
	output out=mycas.fpp2_uschange_up_fit ucl lcl
	copyvars = (date) pred;
run;

data mycas.newdata_down;
	date = yyq(2016,4);
	Income =-1;
	Savings=-0.5;
	Unemployment=0;
	Consumption=.;
	output;
	do i = 1 to 3;
		date = yyq(2017,i);
		Income =-1;
		Savings=-0.5;
		Unemployment=0;
		Consumption=.;
		output;
	end;
	format date YYQC6.;
	keep date Consumption Income Savings Unemployment;
run;

data mycas.fpp2_uschange;
	set time.fpp2_uschange;
	keep date Consumption Income Savings Unemployment;
run;

data mycas.fpp2_uschange;
	set mycas.fpp2_uschange mycas.newdata_down;
run;

proc regselect data=mycas.fpp2_uschange;
	model consumption = income savings unemployment;
	output out=mycas.fpp2_uschange_down_fit ucl lcl
	copyvars = (date) pred;
run;

/**** Prediction intervals ****/
/**** https://otexts.org/fpp2/forecasting-regression.html ****/

* creating new data points by dataline command;
data mycas.newdata;
	input year quarter Consumption Income;
	date = yyq(year,quarter);
	format date YYQ6.;
	keep date Consumption Income;
	datalines;
	2016 4 . 0.72
	2017 1 . 5
	;
run;

data mycas.fpp2_uschange;
	set time.fpp2_uschange;
	keep date Consumption Income;
run;

data mycas.fpp2_uschange;
	set mycas.fpp2_uschange mycas.newdata;
run;

proc regselect data=mycas.fpp2_uschange;
	model consumption = income;
	output out=mycas.fpp2_uschange_fit ucl lcl
	copyvars = (date income) pred;
run;

/**** 5.8 Nonlinear regression ****/
/**** https://otexts.org/fpp2/nonlinear-regression.html ****/
/**** Example: Boston marathon winning times ****/

* creating new data points;

data mycas.newdata;
	do year = 2017 to 2026;
		date = yyq(year,1);
		value = .;
		output;
	end;
	format date year4.;
	keep date value;
run;

data mycas.fpp2_marathon;
	set time.fpp2_marathon mycas.newdata;
run;

/* creating cycle numbers and transformation */
proc tsmodel data=mycas.fpp2_marathon
             outarray = mycas.fpp2_marathon;
    id date interval=year;
	var value;
	require tsa;
    outarrays log_value tb1 tb2 _cycle_2 _cycle_3 tb1_3 tb2_3;
    submit;
		declare object TSA(tsa);
		/*	TRANSFORM: This function performs transformation on input time series array.
			Signature:
			rc = TSA.TRANSFORM(y, type,inverse, c, x);
		*/
        rc = TSA.TRANSFORM(value, 'BOXCOX',0,0,log_value);

		do i = 1 to dim(value);
			tb1[i] = max(0,_cycle_[i] -1940+1897-1);
			tb2[i] = max(0,_cycle_[i] -1980+1897-1);
			tb1_3[i] = tb1[i]**3;
			tb2_3[i] = tb2[i]**3;
			_cycle_2[i] = _cycle_[i]**2;
			_cycle_3[i] = _cycle_[i]**3;
		end;
    endsubmit;
quit;

proc regselect data=mycas.fpp2_marathon;
	model value = _cycle_;
	output out=mycas.fpp2_marathon_fitlin ucl lcl
	copyvars = (date) pred;
run;

proc regselect data=mycas.fpp2_marathon;
	model log_value = _cycle_;
	output out=mycas.fpp2_marathon_fitexp ucl lcl
	copyvars = (date) pred;
run;

proc tsmodel data=mycas.fpp2_marathon_fitexp
             outarray = mycas.fpp2_marathon_fitexp;
    id date interval=year;
	var pred ucl lcl;
	require tsa;
    outarrays exp_pred exp_ucl exp_lcl;
    submit;
		declare object TSA(tsa);
		/*	TRANSFORM: This function performs transformation on input time series array.
			Signature:
			rc = TSA.TRANSFORM(y, type,inverse, c, x);
			the option inverse = 1 is selected.
		*/
        rc = tsa.transform(pred, 'boxcox',1,0,exp_pred);
		rc = tsa.transform(ucl, 'boxcox',1,0,exp_ucl);
		rc = tsa.transform(lcl, 'boxcox',1,0,exp_lcl);
    endsubmit;
quit;

proc regselect data=mycas.fpp2_marathon;
	model value = _cycle_ tb1 tb2;
	output out=mycas.fpp2_marathon_fitpw ucl lcl
	copyvars = (date) pred;
run;

proc regselect data=mycas.fpp2_marathon;
	model value = _cycle_ _cycle_2 _cycle_3 tb1_3 tb2_3;
	output out=mycas.fpp2_marathon_fitspline ucl lcl
	copyvars = (date) pred;
run;