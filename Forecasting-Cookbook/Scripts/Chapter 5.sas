*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;

/**** 5.1 Introduction to multiple linear regression ****/
/**** https://www.otexts.org/fpp/5/1 ****/

/** Example credit scores **/

data mycas.fpp_credit;
    set time.fpp_credit;
run;

*running cas datastep using the sessref option;
data mycas.fpp_credit/sessref = mycas;
	set mycas.fpp_credit;
	log_savings = log(savings+1);
	log_income = log(income+1);
	log_address = log(time_address+1);
	log_employed = log(time_employed+1);
run;

*calling the correlation action from the cas simple action set;
proc cas;
    session mycas;
    simple.correlation result = r1/
        inputs={"score", "savings", "income", "time_address", "time_employed"}
        table={name="fpp_credit"};
run;
    simple.correlation result = r2/
        inputs={"score", "log_savings", "log_income", "log_address", "log_employed"}
        table={name="fpp_credit"};
run;
quit;


proc regselect data=mycas.fpp_credit;
	model score = log_savings log_income log_address log_employed;
	output out=mycas.fpp_credit_fitted
	copyvars=(score) residual pred; 
	/* This command copies the actual values from the original data table
	and calculates residuals and fitted values*/
run;

/*you can select the best model and the criteria is Adjusted R square.
  Stepwise regression is similar to forward selection, except that
  effects already in the model do not necessarily stay there.*/
proc regselect data=mycas.fpp_credit;
	model score = log_savings log_income log_address log_employed;
	selection method=stepwise(select=adjrsq);
run;

/**** 5.2 Some useful predictors ****/
/**** https://www.otexts.org/fpp/5/2 ****/

/** Example Australian quarterly beer production **/

data mycas.fpp_ausbeer;
    set time.fpp_ausbeer;
	keep date aus_beer;
	where 1992 <= year(date) < 2006;
run;

*create quarterly seasonal dummies;
proc tsmodel data=mycas.fpp_ausbeer
             outarray = mycas.fpp_ausbeer;
    id date interval=quarter;
	var aus_beer;
    outarrays q1 q2 q3 q4;
    submit;
        do i = 1 to dim(aus_beer);
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
proc regselect data=mycas.fpp_ausbeer;
	model aus_beer = _cycle_ q2 q3 q4;
	output out=mycas.fpp_ausbeer_fitted
	copyvars=(aus_beer date) residual;
run;

*diagnose regression residuals;
proc tsmodel data=mycas.fpp_ausbeer_fitted
             outarray=mycas.fpp_ausbeer_acf_wn;
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
        rc = tsa.whitenoise(residual, 3, lags,df, wn, wnprob, wnlprob);
	endsubmit;
quit;


/**** 5.5 Non-linear regression ****/
/**** https://www.otexts.org/fpp/5/5 ****/

/** Example 5.1 Car emissions continued **/
data mycas.fuel_nonlinear;
	set time.fpp_fuel;
	if city < 25 then under_25 = 0; 
    else under_25 = city - 25;
run;

proc regselect data=mycas.fuel_nonlinear;
	model carbon = city under_25;
	output out=mycas.carbon_pred;
run;

/*regression splines*/
data mycas.fuel_nonlinear_2;
	set time.fpp_fuel;
	if city < 25 then under_25 = 0; else under_25 = city - 25;
	city2 = city**2;
	city3 = city**3;
	under_25_2 = under_25**2;
	under_25_3 = under_25**3;
run;

proc regselect data=mycas.fuel_nonlinear_2;
	model carbon = city city2 city3 under_25_3;
	output out=mycas.carbon_pred2;
run;
