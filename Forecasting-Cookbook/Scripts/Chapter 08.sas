*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;

/**** 8.1 Stationarity and differencing ****/
/**** https://otexts.com/fpp2/stationarity.html ****/

data mycas.fpp2_goog200;
    set time.fpp2_goog200;
run;

/* test for seasonality and stationarity for different differencing */
proc tsmodel data=mycas.fpp2_goog200
             outarray=mycas.outarray
			 outscalar=mycas.outscalar;
    id index interval = obs;
    var value /acc = sum;
	outarray diffvalue lags acf diffacf;
	outscalars pvalue1 pvalue2 pvalue3 pvalue rc1 rc2 rc3;
    require tsa;
    submit;       
	declare object tsa(tsa);
	rc = tsa.acf(value, 25, lags, , , ,acf, , , , , );
	
	do i = 1 to dim(value)-1;
		diffvalue[i] = value[i+1]-value[i];
	end;
	rc = tsa.acf(diffvalue, 25, lags, , , ,diffacf, , , , , );

    rc1 = tsa.stationaritytest(value,1, ,10 ,"szm",pvalue1);
    rc2 = tsa.stationaritytest(value,1, ,10 ,"ssm",pvalue2);
    rc3 = tsa.stationaritytest(value,1, ,10 ,"str",pvalue3);
    pvalue = max(pvalue1,pvalue2,pvalue3);

	/* Return code for stationaritytest:
	rc = 0 indicates that time series is stationary with the default significance level of 0.05
	rc = 1 indicates that time series is not stationary with the default significance level of 0.05
	rc < 0 indicates computational failure
	*/
    endsubmit;
quit;

/**** 8.5 Non-seasonal ARIMA models ****/
/**** https://otexts.com/fpp2/non-seasonal-arima.html ****/
/**** US consumption expenditure ****/

data mycas.fpp2_uschange;
    set time.fpp2_uschange;
run;

*test for seasonality and stationarity for different differencing;
proc tsmodel data=mycas.fpp2_uschange
             outscalar=mycas.outscalar;
    id date interval = qtr;
    var consumption /acc = sum;
    outscalars diff pvalue;
    require tsa;
    submit;
        
        declare object tsa(tsa);
        do diff = 0 to 12; 
            *diff indicates number of differencing, increase differencing until stationarity is met;
            rc = tsa.stationaritytest(consumption,diff, , ,"szm",pvalue1);
            rc = tsa.stationaritytest(consumption,diff, , ,"ssm",pvalue2);
            rc = tsa.stationaritytest(consumption,diff, , ,"str",pvalue3);
            pvalue = max(pvalue1,pvalue2,pvalue3);
            if pvalue <0.05 then leave;
        end;
    endsubmit;
quit;

*obtain tentitive autoregressive order(p) and order of moving average (q) in arima models;
proc tsmodel data=mycas.fpp2_uschange
             outscalar=mycas.outorders;
    outscalar pscan qscan pesacf qesacf pminic qminic;
    id date interval = qtr;
    var consumption /acc = sum;
    require tsa;
    submit;
        declare object tsa(tsa);
        *tried three different methods;
        rc = tsa.armaorders(consumption,1,"scan", , , ,pscan,qscan);
        rc = tsa.armaorders(consumption,1,"esacf", , , ,pesacf, qesacf);
        rc = tsa.armaorders(consumption,1,"minic", , , ,pminic, qminic);
    endsubmit;
quit;

*estimate arima model coefficient;
proc tsmodel data     = mycas.fpp2_uschange
             outobj   = (outest = mycas.outest
                         outfor = mycas.outfor);
    id date interval = qtr;
    var consumption /acc = sum;
    require tsm;
    submit;
        declare object arima(arimaspec);
        declare object tsm(tsm);
        declare object outest(tsmpest);
        declare object outfor(tsmfor);

        *used the minic method output, so p=0 and q=4;
        array ma[4]/nosymbols;
        ma[1]=1;
		ma[2]=2;
		ma[3]=3;
		ma[4]=4;

        *specify arima model parameters;
        rc = arima.open();
        rc = arima.addmapoly(ma);
        rc = arima.setoption('method', 'ml');
        rc = arima.close();

        *set options: y variable, lead, model;
        rc = tsm.initialize(arima);
        rc = tsm.sety(consumption);
        rc = tsm.setoption('lead',10);
        rc = tsm.run();

        *collect the estimates into object called outest;
        rc = outfor.collect(tsm);
        rc = outest.collect(tsm);
    endsubmit;
quit;

*automatical diagnose the time seires to get candidate ARIMA models;
proc tsmodel data      = mycas.fpp2_uschange
             outobj    = (outest  = mycas.outest
                          outfor  = mycas.outfor
                          outstat = mycas.outstat);
    id date interval = qtr;
    var consumption /acc = sum;
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
        rc = dataframe.addy(consumption);

        *set diagnose parameter;
        rc = diagspec.open();
        rc = diagspec.setarimax('estmethod', 'ml'); *set arima models to be considered in diagnose;
        rc = diagspec.close();

        *run diagnose;
        rc = diagnose.initialize(dataframe);
        rc = diagnose.setspec(diagspec);
        rc = diagnose.run();

        *run forecast engine;
        rc = forecast.initialize(diagnose);
        rc = forecast.setoption('criterion','rmse');
        rc = forecast.setoption('lead',10);
        rc = forecast.run();

        *collect output;
        rc = outest.collect(forecast);
        rc = outfor.collect(forecast);
        rc = outstat.collect(forecast);
    endsubmit;
quit;

/**** Example: Seasonally adjusted electrical equipment orders ****/
/**** https://otexts.com/fpp2/arima-r.html ****/

data mycas.fpp2_elecequip;
    set time.fpp2_elecequip;
run;

proc tsmodel data=mycas.fpp2_elecequip
             outarray = mycas.decomp;
    id date interval=month;
	var elecequip/acc = sum;
    outarrays vtcc vsc vic vsa;
    require tsa;
    submit;
        declare object tsa(tsa);
        *mode="add" specifies the additive decomposition;
        rc = tsa.seasonaldecomp(elecequip,_seasonality_,"add", ,vtcc, ,vsc , , ,vic,vsa);
    endsubmit;
quit;

*perform arima model on the seasonally adjusted series in dataset mycas.decomp;
proc tsmodel data      = mycas.decomp
             outscalar = mycas.outscalar
             outobj    = (outest  = mycas.outest
                          outfor  = mycas.outfor
					      outspec = mycas.outspec);
    id date interval = month;
    var vsa /acc = sum;
    require tsa tsm;
    submit;
        declare object tsa(tsa);
        declare object arima(arimaspec);
        declare object tsm(tsm);
        declare object outest(tsmpest);
        declare object outfor(tsmfor);
        declare object outspec(tsmspec);
		
		*The ARIMA(3,1,1) configuration was taken from the book example;
        array ar[3]/nosymbols; 
        ar[1]=1;
		ar[2]=2;
		ar[3]=3;
        array ma[1]/nosymbols;
        ma[1]=1;
		array diff_array[1]/nosymbols;
		diff_array[1] = 1;

        rc = arima.open();
        rc = arima.setdiff(diff_array);
        rc = arima.addarpoly(ar); 
        rc = arima.addmapoly(ma);
        rc = arima.setoption('method', 'ml');
        rc = arima.close();

        rc = tsm.initialize(arima);
        rc = tsm.sety(vsa);
        rc = tsm.setoption('lead',10);
        rc = tsm.run();

        rc = outfor.collect(tsm);
        rc = outest.collect(tsm);
        rc = outspec.collect(tsm);
    endsubmit;
quit;

/**** 8.9 Seasonal ARIMA models ****/
/**** Example: European quarterly retail trade ****/
/**** https://otexts.com/fpp2/seasonal-arima.html ****/

data mycas.fpp2_euretail;
    set time.fpp2_euretail;
run;

*perform seasonal arima models;
proc tsmodel data      = mycas.fpp2_euretail
             outscalar = mycas.outscalar
             outobj    = (outest1  = mycas.outest1
						  outspec1 = mycas.outspec1
                          outfor1 = mycas.outfor1
                          outest2  = mycas.outest2
						  outspec2 = mycas.outspec2
                          outfor2 = mycas.outfor2);
    id date interval = qtr;
    var euretail /acc = sum;
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
		
		*The ARIMA(0,1,1)(0,1,1) configuration was taken from the book example;
        array ma_array1[1]/nosymbols;*non-seasonal MA;
        ma_array1[1]=1;
        array ma_array1s[1]/nosymbols;*seasonal ma;
        ma_array1s[1]=1;
		array diff_array1[2]/nosymbols;
		diff_array1[1] = 1;
		diff_array1[2] = .s; *represent the seasonality;

        rc = arima.open();
        rc = arima.setdiff(diff_array1);
        rc = arima.addmapoly(ma_array1, 1, 0);*adding non-seasonal ma. ;
		rc = arima.addmapoly(ma_array1s, 1, 1);*adding seasonal ma.;
        rc = arima.setoption('method', 'ml');
        rc = arima.close();

        rc = tsm.initialize(arima);
        rc = tsm.sety(euretail);
        rc = tsm.setoption('lead',12);
        rc = tsm.run();

        rc = outfor1.collect(tsm);
        rc = outest1.collect(tsm);
        rc = outspec1.collect(tsm);


		*The ARIMA(0,1,3)(0,1,1) configuration was also taken from the book example;
        array ma_array2[3]/nosymbols;
        ma_array2[1]=1;
		ma_array2[2]=2;
		ma_array2[3]=3;
        array ma_array2s[1]/nosymbols;
        ma_array2s[1]=1;
		array diff_array2[2]/nosymbols;
		diff_array2[1] = 1;
		diff_array2[2] = .s; *represent the seasonality;

        rc = arima.open();
        rc = arima.setdiff(diff_array2);
        rc = arima.addmapoly(ma_array2, 3, 0);*adding non-seasonal ma. ;
		rc = arima.addmapoly(ma_array2s, 1, 1);*adding seasonal ma.;
        rc = arima.setoption('method', 'ml');
        rc = arima.close();

        rc = tsm.initialize(arima);
        rc = tsm.sety(euretail);
        rc = tsm.setoption('lead',12);
        rc = tsm.run();

        rc = outfor2.collect(tsm);
        rc = outest2.collect(tsm);
        rc = outspec2.collect(tsm);


    endsubmit;
quit;

*automatical diagnose the time seires to get candidate ARIMA models;
proc tsmodel data      = mycas.fpp2_euretail
             outobj    = (outest  = mycas.outest
                          outfor  = mycas.outfor
                          outstat = mycas.outstat);
    id date interval = qtr;
    var euretail;
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
        rc = dataframe.addy(euretail);

        *set diagnose parameter;
        rc = diagspec.open();
        rc = diagspec.setarimax('estmethod', 'ml'); *set arima models to be considered in diagnose;
        rc = diagspec.close();

        *run diagnose;
        rc = diagnose.initialize(dataframe);
        rc = diagnose.setspec(diagspec);
		rc = diagnose.setoption('holdout', 12);
        rc = diagnose.run();

        *run forecast engine;
        rc = forecast.initialize(diagnose);
        rc = forecast.setoption('criterion','rmse');
		rc = forecast.setoption('holdout', 12);
        rc = forecast.setoption('lead',12);
        rc = forecast.run();

        *collect output;
        rc = outest.collect(forecast);
        rc = outfor.collect(forecast);
        rc = outstat.collect(forecast);
    endsubmit;
quit;


/**** 8.9 Seasonal ARIMA models ****/
/**** Example: Corticosteroid drug sales in Australia ****/
/**** https://otexts.com/fpp2/seasonal-arima.html ****/

data mycas.fpp2_h02;
    set time.fpp2_h02;
run;

/* Creat macros that set array for AR, MA and differencing*/
%macro setAR(arOrder=, Len=);
    array ar[&Len]/nosymbols;
    %do i = 1 %to &Len;
        ar[&i] = %scan(&arOrder, &i, ' ');
    %end;
%mend;

%macro setMA(maOrder=, Len=);
    array ma[&Len]/nosymbols;
    %do i = 1 %to &Len;
        ma[&i] = %scan(&maOrder, &i, ' ');
    %end;
%mend;

%macro setDiff(diff=, Len=);
    array diff_array[&Len]/nosymbols;
    %do i = 1 %to &Len;
        diff_array[&i] = %scan(&diff, &i, ' ');
    %end;
%mend;

/* Creat macros that set array for seasonal AR, MA*/
%macro setARs(arsOrder=, Len=);
    array ars[&Len]/nosymbols;
    %do i = 1 %to &Len;
        ars[&i] = %scan(&arsOrder, &i, ' ');
    %end;
%mend;

%macro setMAs(masOrder=, Len=);
    array mas[&Len]/nosymbols;
    %do i = 1 %to &Len;
        mas[&i] = %scan(&masOrder, &i, ' ');
    %end;
%mend;


/*Create Macro that take different AR, MA, and Diff orders and produce RMSE*/
%macro season_arima(arOrder=, arsOrder=, maOrder=, masOrder=,diff=, outfor=, outSummary=);

%let nAR=%sysfunc(countw(&arOrder,' ', mo));
%let nMA=%sysfunc(countw(&maOrder,' ', mo));
%let ndiff=%sysfunc(countw(&diff,' ', mo));

%let nARs=%sysfunc(countw(&arsOrder,' ', mo));
%let nMAs=%sysfunc(countw(&masOrder,' ', mo));

proc tsmodel data      = mycas.fpp2_h02
             outscalar = mycas.&outSummary
             outobj    = (outest  = mycas.outest
                          outfor  = mycas.&outfor
					      outspec = mycas.outspec);
    id date interval = month;
    var H02 /acc = sum;
    outscalar rmse;
    require tsm;
    submit;
        declare object arima(arimaspec);
        declare object tsm(tsm);
        declare object outest(tsmpest);
        declare object outfor(tsmfor);
        declare object outspec(tsmspec);
		
        %setAR(arOrder=&arOrder, Len=&nAR);
		%setMA(maOrder=&maOrder, Len=&nMA);
		%setDiff(diff=&diff, Len=&ndiff);

		%setARs(arsOrder=&arsOrder, Len=&nARs);
		%setMAs(masOrder=&masOrder, Len=&nMAs);

        rc = arima.open();
        rc = arima.setdiff(diff_array);
        if ar[1]>0 then rc = arima.addarpoly(ar, ,0); 
		if ars[1]>0 then rc = arima.addarpoly(ars, ,1); 
        if ma[1]>0 then rc = arima.addmapoly(ma, ,0);
		if mas[1]>0 then rc = arima.addmapoly(mas, ,1);
        rc = arima.setoption('method', 'ml');
        rc = arima.close();

        rc = tsm.initialize(arima);
        rc = tsm.sety(H02);
        rc = tsm.setoption('back',24);
        rc = tsm.setoption('lead',24);
        rc = tsm.run();

        rc = outfor.collect(tsm);
        rc = outest.collect(tsm);
        rc = outspec.collect(tsm);
        
        *compute RMSE;
		array predict[1]/nosymbols;
        
        *change array size based on the size of the variable H02;
		call dynamic_array(predict, dim(H02));
        rc = tsm.getforecast('predict', predict);
        absres2 = 0;
        n = 0;
        do i = dim(H02) to (dim(H02)-23) by -1;
            if H02[i] ne . and predict[i] ne . then do;
                absres2 = absres2 + (predict[i]-H02[i])**2;
                n = n + 1;
            end;
        end;
        if n > 0 then rmse = sqrt(absres2/n);
        else rmse = .;
    endsubmit;
quit;


%mend season_arima;
/*Trying different autoregressive, differencing and moving average orders*/
%season_arima(arOrder=%str(1 2 3), arsOrder=%str(1 2), maOrder=%str(0), masOrder=%str(0),diff=%str(12), outfor=outfor1, outSummary=outSummary1);
%season_arima(arOrder=%str(1 2 3), arsOrder=%str(1 2), maOrder=%str(1), masOrder=%str(0),diff=%str(12), outfor=outfor2, outSummary=outSummary2);
%season_arima(arOrder=%str(1 2 3), arsOrder=%str(1 2), maOrder=%str(2), masOrder=%str(0),diff=%str(12), outfor=outfor3, outSummary=outSummary3);
%season_arima(arOrder=%str(1 2 3), arsOrder=%str(1), maOrder=%str(1), masOrder=%str(0),diff=%str(12), outfor=outfor4, outSummary=outSummary4);
%season_arima(arOrder=%str(1 2 3), arsOrder=%str(0), maOrder=%str(1), masOrder=%str(1),diff=%str(12), outfor=outfor5, outSummary=outSummary5);
%season_arima(arOrder=%str(1 2 3), arsOrder=%str(0), maOrder=%str(1), masOrder=%str(1 2),diff=%str(12), outfor=outfor6, outSummary=outSummary6);
%season_arima(arOrder=%str(1 2 3), arsOrder=%str(1), maOrder=%str(1), masOrder=%str(1),diff=%str(12), outfor=outfor7, outSummary=outSummary7);
%season_arima(arOrder=%str(1 2 3 4), arsOrder=%str(0), maOrder=%str(1 2 3), masOrder=%str(1),diff=%str(12), outfor=outfor8, outSummary=outSummary8);
%season_arima(arOrder=%str(1 2 3), arsOrder=%str(0), maOrder=%str(1 2 3), masOrder=%str(1),diff=%str(12), outfor=outfor9, outSummary=outSummary9);
%season_arima(arOrder=%str(1 2 3 4), arsOrder=%str(0), maOrder=%str(1 2), masOrder=%str(1),diff=%str(12), outfor=outfor10, outSummary=outSummary10);
%season_arima(arOrder=%str(1 2 3), arsOrder=%str(0), maOrder=%str(1 2), masOrder=%str(1),diff=%str(12), outfor=outfor11, outSummary=outSummary11);
%season_arima(arOrder=%str(1 2), arsOrder=%str(0), maOrder=%str(1 2 3), masOrder=%str(1),diff=%str(1 12), outfor=outfor12, outSummary=outSummary12);
%season_arima(arOrder=%str(1 2), arsOrder=%str(0), maOrder=%str(1 2 3 4), masOrder=%str(1),diff=%str(1 12), outfor=outfor13, outSummary=outSummary13);
%season_arima(arOrder=%str(1 2), arsOrder=%str(0), maOrder=%str(1 2 3 4 5), masOrder=%str(1),diff=%str(1 12), outfor=outfor14, outSummary=outSummary14);

*automatical diagnose the time seires to get candidate ARIMA models;
proc tsmodel data      = mycas.fpp2_h02
             outobj    = (outest  = mycas.outest
                          outfor  = mycas.outfor
                          outstat = mycas.outSummary);
    id date interval = month;
    var H02;
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
        rc = dataframe.addy(H02);

        *set diagnose parameter;
        rc = diagspec.open();
        rc = diagspec.setarimax('estmethod','ml'); *set arima models to be considered in diagnose;
        rc = diagspec.close();

        *run diagnose;
        rc = diagnose.initialize(dataframe);
        rc = diagnose.setspec(diagspec);
		rc = diagnose.setoption('holdout', 12);
		rc = diagnose.setoption('back', 24);
        rc = diagnose.run();

        *run forecast engine;
        rc = forecast.initialize(diagnose);
        rc = forecast.setoption('criterion','rmse');
		rc = forecast.setoption('holdout', 12);
        rc = forecast.setoption('back', 24);
        rc = forecast.setoption('lead', 24);
        rc = forecast.run();

        *collect output;
        rc = outest.collect(forecast);
        rc = outfor.collect(forecast);
        rc = outstat.collect(forecast);
    endsubmit;
quit;