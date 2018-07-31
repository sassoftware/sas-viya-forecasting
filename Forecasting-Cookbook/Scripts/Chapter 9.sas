*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;


/**** 9.1 Dynamic regression models ****/
/**** Example 9.1 US Personal Consumption and Income ****/
/**** https://www.otexts.org/fpp/9/1 ****/

data mycas.Fpp_usconsumption;
    set time.Fpp_usconsumption;
run;

*perform arima models with income as covariates;
proc tsmodel data      = mycas.Fpp_usconsumption
             outscalar = mycas.outscalar
             outobj    = (
                          outest1  = mycas.outest1
						  outspec1 = mycas.outspec1
                          outfor1 = mycas.outfor1
                          outest2  = mycas.outest2
						  outspec2 = mycas.outspec2
                          outfor2 = mycas.outfor2                          )
             ;
    id date interval = qtr;
    var consumption income /acc = sum;
    require tsm;
    submit;
        declare object arima(arimaspec);
        declare object tsm(tsm);
        declare object outest1(tsmpest);
        declare object outfor1(tsmfor);
        declare object outspec1(tsmspec);
		declare object outest2(tsmpest);
        declare object outfor2(tsmfor);
        declare object outspec2(tsmspec);
		
		*The ARIMA(1,0,2) configuration was taken from the book example;
		array ar_array1[1]/nosymbols;
		ar_array1[1] = 1;
        array ma_array1[2]/nosymbols;
        ma_array1[1]=1;
		ma_array1[2]=2;


        rc = arima.open();
        rc = arima.addARPoly(ar_array1);
		rc = arima.addMAPoly(ma_array1);
		rc = arima.AddTF("income");*covariate income is added;
        rc = arima.close();

        rc = tsm.initialize(arima);
        rc = tsm.setY(consumption);
		rc = tsm.AddX(income,1);*covariate income is added;
        rc = tsm.setOption('lead',12);
        rc = tsm.run();

        rc = outfor1.collect(tsm);
        rc = outest1.collect(tsm);
        rc = outspec1.collect(tsm);


		*The ARIMA(2,0,0) configuration was taken from the book example;
		array ar_array2[2]/nosymbols;
		ar_array2[1] = 1;
		ar_array2[2] = 2;

        rc = arima.open();
        rc = arima.addARPoly(ar_array2);
		rc = arima.AddTF("income");*covariate income is added;
        rc = arima.close();

        rc = tsm.initialize(arima);
        rc = tsm.setY(consumption);
		rc = tsm.AddX(income,1);*covariate income is added;
        rc = tsm.setOption('lead',12);
        rc = tsm.run();

        rc = outfor2.collect(tsm);
        rc = outest2.collect(tsm);
        rc = outspec2.collect(tsm);

    endsubmit;
quit;


/**** Example 9.2  International visitors to Australia ****/
/**** https://www.otexts.org/fpp/9/1 ****/


*Create Trend;
data Fpp_austa;
	set time.Fpp_austa;
	obs=_n_;
	date = MDY(1,1,Year);
	format date date9.
run;

data mycas.Fpp_austa;
    set Fpp_austa;
run;

*automatic arima with deterministic trend;
proc tsmodel data=mycas.Fpp_austa outscalar = mycas.outscalar
               outobj     = (
                             outEst = mycas.outEst
                             outFor = mycas.outFor
                             outStat = mycas.outStat)
                  ;
      outscalar rc;
	  id date interval = year;
      var Tourist_Arrivals obs/acc = sum;
      require atsm;
      submit;
        declare object diagnose(diagnose);
		declare object diagspec(diagspec);
        declare object dataFrame(tsdf);
        declare object forecast(foreng);
        declare object outEst(outest);
        declare object outFor(outfor);
        declare object outStat(outstat);

		*specify dataframe information;
        rc = dataFrame.Initialize();
        rc = dataFrame.AddY(Tourist_Arrivals);
		rc = dataFrame.AddX(obs,'REQUIRED','YES');*force it to include this covariate;


		*set diagnose parameter;
        rc = diagspec.Open();
		rc = diagspec.SetARIMAX(); *set arima models to be considered in diagnose;
		rc = diagspec.SetUCM();
		rc = diagspec.SetCombine(); *set the combined model also be considered;
		rc = diagspec.Close();

		*run diagnose;
		rc = diagnose.Initialize(dataFrame);
		rc = diagnose.SetSpec(diagspec);
        rc = diagnose.Run();

		*run forecast engine;
        rc = forecast.Initialize(diagnose);
        rc = forecast.SetOption('criterion','rmse');
        rc = forecast.SetOption('lead',5);
        rc = forecast.Run();

		*collect output;
        rc = outEst.collect(forecast);
        rc = outFor.collect(forecast);
        rc = outStat.collect(forecast);
      endsubmit;
quit;



/**** Example 9.3  TV advertising and insurance quotations ****/
/**** https://www.otexts.org/fpp/9/1 ****/

*Create lag variables;
data Fpp_insurance;
	set TIME.Fpp_insurance;
	TV_lag1=lag1(TV_advert);
	TV_lag2=lag2(TV_advert);
	TV_lag3=lag3(TV_advert);
	rename TV_advert = TV;
	keep date quotes TV_advert TV_lag1 TV_lag2 TV_lag3;
run;

data mycas.Fpp_insurance;
	set Fpp_insurance;
run;


*automatic arima with lag variable and variable selection;
proc tsmodel data=mycas.Fpp_insurance outscalar = mycas.outscalar
               outobj     = (
                             outEst = mycas.outEst
                             outFor = mycas.outFor
                             outStat = mycas.outStat)
                  ;
      outscalar rc;
	  id date interval = month;
      var quotes TV TV_lag1 TV_lag2 TV_lag3/acc = sum;
      require atsm;
      submit;
        declare object diagnose(diagnose);
		declare object diagspec(diagspec);
        declare object dataFrame(tsdf);
        declare object forecast(foreng);
        declare object outEst(outest);
        declare object outFor(outfor);
        declare object outStat(outstat);

		*specify dataframe information;
        rc = dataFrame.Initialize();
        rc = dataFrame.AddY(quotes);
		rc = dataFrame.AddX(TV); *Without using required, variable selection is performed;
		rc = dataFrame.AddX(TV_lag1);
		rc = dataFrame.AddX(TV_lag2);
		rc = dataFrame.AddX(TV_lag3);


		*set diagnose parameter;
        rc = diagspec.Open();
		rc = diagspec.SetARIMAX(); *set arima models to be considered in diagnose;
		rc = diagspec.SetUCM();
		rc = diagspec.SetCombine(); *set the combined model also be considered;
		rc = diagspec.Close();

		*run diagnose;
		rc = diagnose.Initialize(dataFrame);
		rc = diagnose.SetSpec(diagspec);
        rc = diagnose.Run();

		*run forecast engine;
        rc = forecast.Initialize(diagnose);
        rc = forecast.SetOption('criterion','rmse');
        rc = forecast.SetOption('lead',5);
        rc = forecast.Run();

		*collect output;
        rc = outEst.collect(forecast);
        rc = outFor.collect(forecast);
        rc = outStat.collect(forecast);
      endsubmit;
quit;


/**** 9.3 Neural network models ****/
/**** Example 9.5 Credit scoring  ****/
/**** https://www.otexts.org/fpp/9/3 ****/

data mycas.Fpp_credit;
	set time.Fpp_credit;
run;

proc nnet data=mycas.Fpp_credit;
	input log_savings log_income log_address log_employed /level=INT;
	target score /level=INT;
	hidden 3;
	train outmodel=mycas.nnetmodel seed=12345;
	optimization algorithm=SGD seed=54321 regl2=0.1 maxiter=300;
run;
