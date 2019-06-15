*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;

/**** 10.2 Grouped time series ****/
/**** Example: Australian prison population ****/
/**** https://otexts.com/fpp2/gts.html ****/

data mycas.fpp2_prison;
    set time.fpp2_prison;
    /* you can scale the prison variable as follows:*/
	prison_10e3 = prison/1000;
	drop prison;
run;

/* aggregating by state*legal */
proc tsmodel data = mycas.fpp2_prison outarray = mycas.prison_aggregated;
	id date interval = qtr accumulate = total;
	by state legal;
	var prison_10e3;
	
	/* if you prefer to scale the prison through tsmodel call and not data step, you should
	define prison and prison_10e3 as var and outarray, respectively:
	
	var prison;
	outarray prison_10e3;
	submit;
		do i = 1 to dim(prison);
			prison_10e3[i] = prison[i]/1000;
		end;
	endsubmit;
	*/
run;

/* aggregating by state*gender */
proc tsmodel data = mycas.fpp2_prison outarray = mycas.prison_aggregated;
	id date interval = qtr accumulate = total;
	by state gender;
	var prison_10e3;
	
	/* if you prefer to scale the prison through tsmodel call and not data step, you should
	define prison and prison_10e3 as var and outarray, respectively:
	
	var prison;
	outarray prison_10e3;
	submit;
		do i = 1 to dim(prison);
			prison_10e3[i] = prison[i]/1000;
		end;
	endsubmit;
	*/
run;

/* aggregating by gender*legal */
proc tsmodel data = mycas.fpp2_prison outarray = mycas.prison_aggregated;
	id date interval = qtr accumulate = total;
	by gender legal;
	var prison_10e3;
	
	/* if you prefer to scale the prison through tsmodel call and not data step, you should
	define prison and prison_10e3 as var and outarray, respectively:
	
	var prison;
	outarray prison_10e3;
	submit;
		do i = 1 to dim(prison);
			prison_10e3[i] = prison[i]/1000;
		end;
	endsubmit;
	*/
run;

/* total aggregating */
proc tsmodel data = mycas.fpp2_prison outarray = mycas.prison_aggregated;
	id date interval = qtr accumulate = total;
	var prison_10e3;
	
	/* if you prefer to scale the prison through tsmodel call and not data step, you should
	define prison and prison_10e3 as var and outarray, respectively:
	
	var prison;
	outarray prison_10e3;
	submit;
		do i = 1 to dim(prison);
			prison_10e3[i] = prison[i]/1000;
		end;
	endsubmit;
	*/
run;

/**** 10.3 The bottom-up approach ****/
/**** The hts package for R ****/
/**** https://otexts.com/fpp2/bottom-up.html ****/

proc tsmodel data = mycas.fpp2_prison outobj = (outfor = mycas.outfor);
	id date interval = qtr;
	var prison_10e3;
	by gender legal state;

	require atsm;

	submit;
		declare object dataframe(tsdf);
		declare object diagnose(diagnose);
		declare object diagspec(diagspec);
		declare object forecast(foreng);
		
		rc = dataframe.initialize();
		rc = dataframe.addy(prison_10e3);
		
		rc = diagspec.open();
		rc = diagspec.setarimax('identify', 'both');
		rc = diagspec.setoption('criterion', 'mape');
		rc = diagspec.close();
		
		rc = diagnose.initialize(dataframe);
		rc = diagnose.setspec(diagspec);
		rc = diagnose.run();
		
		rc = forecast.initialize(diagnose);
		rc = forecast.setoption('criterion','mape');
		rc = forecast.setoption('lead', 8);
		rc = forecast.run();
		
		declare object outfor(outfor);
		rc = outfor.collect(forecast);
	endsubmit;
quit;

/* aggregation bottom-up forecasts using ARIMA */
proc tsmodel data = mycas.outfor outarray = mycas.outfor_aggregated;
	id date interval = qtr accumulate = total;
	var predict;
run;

/**** 10.7 The optimal reconciliation approach ****/
/**** Example: Forecasting Australian prison population ****/
/**** https://otexts.com/fpp2/reconciliation.html ****/

proc tsmodel data = mycas.fpp2_prison outobj = (outfor = mycas.recoutfor);
	id date interval = qtr;
	var prison_10e3;
	by gender legal state;

	require atsm;

	submit;
		declare object dataframe(tsdf);
		declare object diagnose(diagnose);
		declare object diagspec(diagspec);
		declare object forecast(foreng);
		
		rc = dataframe.initialize();
		rc = dataframe.addy(prison_10e3);
		
		rc = diagspec.open();
		rc = diagspec.setarimax('identify', 'both');
		rc = diagspec.setoption('criterion', 'mape');
		rc = diagspec.close();
		
		rc = diagnose.initialize(dataframe);
		rc = diagnose.setspec(diagspec);
		rc = diagnose.setoption('back', 8);
		rc = diagnose.run();
		
		rc = forecast.initialize(diagnose);
		rc = forecast.setoption('criterion','mape');
		rc = forecast.setoption('back', 8);
		rc = forecast.setoption('lead', 8);
		rc = forecast.run();
		
		declare object outfor(outfor);
		rc = outfor.collect(forecast);
	endsubmit;
quit;

/* aggregation the results to get top-level forecast */
/* MAPE is saved in the table mycas.toplevelscalar */
proc tsmodel data = mycas.recoutfor outarray = mycas.toplevel_outfor_aggregated outscalar = mycas.toplevelscalar; 
	id date interval = qtr accumulate = total;
	var predict actual;
	outscalar mape;
	
	submit;
		mape = 0;
		n = 0;
		do i = dim(actual)-8+1 to dim(actual);
			mape = mape + abs(actual[i]-predict[i])/abs(actual[i]);
			n = n + 1;
		end;
		mape = 100*mape/n;
	endsubmit;
run;

/* aggregation the results to get State forecast */
/* MAPE is saved in the table mycas.Statescalar */
proc tsmodel data = mycas.recoutfor outarray = mycas.state_outfor_aggregated outscalar = mycas.statescalar; 
	id date interval = qtr accumulate = total;
	by state;
	var predict actual;
	outscalar mape;
	
	submit;
		mape = 0;
		n = 0;
		do i = dim(actual)-8+1 to dim(actual);
			mape = mape + abs(actual[i]-predict[i])/abs(actual[i]);
			n = n + 1;
		end;
		mape = 100*mape/n;
	endsubmit;
run;

/* aggregation the results to get Legal forecast */
/* MAPE is saved in the table mycas.Legalscalar */
proc tsmodel data = mycas.recoutfor outarray = mycas.legal_outfor_aggregated outscalar = mycas.legalscalar; 
	id date interval = qtr accumulate = total;
	by legal;
	var predict actual;
	outscalar mape;
	
	submit;
		mape = 0;
		n = 0;
		do i = dim(actual)-8+1 to dim(actual);
			mape = mape + abs(actual[i]-predict[i])/abs(actual[i]);
			n = n + 1;
		end;
		mape = 100*mape/n;
	endsubmit;
run;

/* aggregation the results to get Gender forecast */
/* MAPE is saved in the table mycas.Genderscalar */
proc tsmodel data = mycas.recoutfor outarray = mycas.gender_outfor_aggregated outscalar = mycas.genderscalar; 
	id date interval = qtr accumulate = total;
	by gender;
	var predict actual;
	outscalar mape;
	
	submit;
		mape = 0;
		n = 0;
		do i = dim(actual)-8+1 to dim(actual);
			mape = mape + abs(actual[i]-predict[i])/abs(actual[i]);
			n = n + 1;
		end;
		mape = 100*mape/n;
	endsubmit;
run;