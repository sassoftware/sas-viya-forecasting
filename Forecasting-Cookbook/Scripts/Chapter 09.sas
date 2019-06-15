*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;

/**** 9.2 Regression with ARIMA errors in R ****/
/**** Example: US Personal Consumption and Income ****/
/**** https://otexts.com/fpp2/regarima.html ****/

data mycas.fpp2_uschange;
    set time.fpp2_uschange;
run;

*perform arima models with income as covariates;
proc tsmodel data      = mycas.fpp2_uschange
             outscalar = mycas.outscalar
             outobj    = (outest = mycas.outest outspec = mycas.outspec outfor = mycas.outfor);
    id date interval = qtr;
    var consumption income /acc = sum;
    require tsm;
    submit;
        declare object arima(arimaspec);
        declare object tsm(tsm);
        declare object outest(tsmpest);
        declare object outfor(tsmfor);
        declare object outspec(tsmspec);
		
		*the arima(1,0,2) configuration was taken from the book example;
		array ar_array[1]/nosymbols;
		ar_array[1] = 1;
        array ma_array[2]/nosymbols;
        ma_array[1]=1;
		ma_array[2]=2;

        rc = arima.open();
        rc = arima.addarpoly(ar_array);
		rc = arima.addmapoly(ma_array);
		rc = arima.addtf("income"); *covariate income is added;
        rc = arima.close();

        rc = tsm.initialize(arima);
        rc = tsm.sety(consumption);
		rc = tsm.addx(income,1); *covariate income is added;
        rc = tsm.setoption('lead',12);
        rc = tsm.run();

        rc = outfor.collect(tsm);
        rc = outest.collect(tsm);
        rc = outspec.collect(tsm);
    endsubmit;
quit;

/**** 9.5 Dynamic harmonic regression ****/
/**** Example: Example: Australian eating out expenditure ****/
/**** https://otexts.com/fpp2/dhr.html ****/

data mycas.fpp2_cafe04;
    set time.fpp2_cafe04;
run;

/* In the following forecast, the case K=6 is considered */
proc tsmodel data      = mycas.fpp2_cafe04
             outobj    = (outest = mycas.outest outfor = mycas.outfor);
    id date interval = month;
    var _numeric_;
    require atsm;
    submit;
        declare object dataframe(tsdf);
		declare object diagnose(diagnose);
		declare object diagspec(diagspec);
		declare object forecast(foreng);
		declare object outfor(outfor);
		declare object outest(outest);
		
		rc = dataframe.initialize();
		rc = dataframe.addy(expenditure);
		rc = dataframe.addx(s1,'required','yes');
		rc = dataframe.addx(c1,'required','yes');
		rc = dataframe.addx(s2,'required','yes');
		rc = dataframe.addx(c2,'required','yes');
		rc = dataframe.addx(s3,'required','yes');
		rc = dataframe.addx(c3,'required','yes');
		rc = dataframe.addx(s4,'required','yes');
		rc = dataframe.addx(c4,'required','yes');
		rc = dataframe.addx(s5,'required','yes');
		rc = dataframe.addx(c5,'required','yes');
		rc = dataframe.addx(s6,'required','yes');
		rc = dataframe.addx(c6,'required','yes');
		
		/* the option 'required' is set to 'yes' to 
		forecefully put the x variable in the model */
		
		rc = diagspec.open();
		rc = diagspec.setarimax('identify', 'both');
		rc = diagspec.close();
		
		rc = diagnose.initialize(dataframe);
		rc = diagnose.setspec(diagspec);
		rc = diagnose.run();
		
		rc = forecast.initialize(diagnose);
		rc = forecast.setoption('lead', 12);
		rc = forecast.run();

		rc = outfor.collect(forecast);
		rc = outest.collect(forecast);
    endsubmit;
quit;

data mycas.fpp2_insurance;
	set time.fpp2_insurance;
run;

*automatic arima with lag variable and variable selection;
proc tsmodel data=mycas.fpp2_insurance outscalar = mycas.outscalar
	outobj = (outest = mycas.outest outfor = mycas.outfor outstat = mycas.outstat);
	id date interval = month;
	var quotes TV TV_lag1 TV_lag2 TV_lag3/acc = sum;
	require atsm;
		submit;
			declare object diagnose(diagnose);
			declare object diagspec(diagspec);
			declare object dataframe(tsdf);
			declare object forecast(foreng);
			declare object outest(outest);
			declare object outfor(outfor);
			declare object outstat(outstat);
			
			*specify dataframe information;
			rc = dataframe.initialize();
			rc = dataframe.addy(quotes);
			rc = dataframe.addx(TV); *without using 'required', variable selection is performed;
			rc = dataframe.addx(TV_lag1);
			rc = dataframe.addx(TV_lag2);
			rc = dataframe.addx(TV_lag3);

			rc = diagspec.open();
			rc = diagspec.setarimax('identify', 'both'); * set arima models to be diagnose;
			rc = diagspec.setucm();
			rc = diagspec.setcombine(); *set the combined model also be considered;
			rc = diagspec.close();

			*run diagnose;
			rc = diagnose.initialize(dataframe);
			rc = diagnose.setspec(diagspec);
			rc = diagnose.run();

			*run forecast engine;
			rc = forecast.initialize(diagnose);
			rc = forecast.setoption('lead',5);
			rc = forecast.run();

			*collect output;
			rc = outest.collect(forecast);
			rc = outfor.collect(forecast);
			rc = outstat.collect(forecast);
		endsubmit;
quit;