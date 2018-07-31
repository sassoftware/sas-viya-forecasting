*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;

/**** 8.1 Stationarity and differencing ****/
/**** https://www.otexts.org/fpp/8/1 ****/

data mycas.fpp_a10;
    set time.fpp_a10;
run;

*test for seasonality and stationarity for different differencing;
proc tsmodel data=mycas.fpp_a10
             outscalar=mycas.outscalar
             outarray=mycas.outarray;
    id date interval = month end='31DEC2007'd;
    var log_sales /acc = sum;
    outscalars seasonal1 seasonal2 diff pvalue;
    outarray aic1 aic2;
    require tsa;
    submit;
        
        declare object tsa(tsa);
        *seasonal tests;
        seasonal1 = 0; *indicator for seasonality without detrending;
        rc = tsa.seasontest(log_sales,_seasonality_,0,0,,aic1);
        if rc > 0 then seasonal1= 1;
        seasonal2 = 0; *indicator for seasonality with detrending;
        rc = tsa.seasontest(log_sales,_seasonality_,1,0,,aic2);
        if rc > 0 then seasonal2= 1;
        
        *stationary test;
		if seasonal1 = 1 OR seasonal2 = 1 then seasonality=_seasonality_;
		else seasonality=1;

        do diff = 0 to 12; 
            *diff indicates number of differencing, increase differencing until stationarity is met;
            rc = tsa.stationaritytest(log_sales,diff,seasonality,2,"szm",pvalue1);
            rc = tsa.stationaritytest(log_sales,diff,seasonality,2,"ssm",pvalue2);
            rc = tsa.stationaritytest(log_sales,diff,seasonality,2,"str",pvalue3);
            pvalue = max(pvalue1,pvalue2,pvalue3);
            if rc < 0 or rc >= 0 and pvalue <0.01 then leave;
        end;

    endsubmit;
quit;

proc print data=mycas.outscalar;
run;



/**** 8.5 Non-seasonal ARIMA models ****/
/**** https://www.otexts.org/fpp/8/5 ****/
data mycas.Fpp_usconsumption;
    set time.Fpp_usconsumption;
run;

*test for seasonality and stationarity for different differencing;
proc tsmodel data=mycas.Fpp_usconsumption
             outscalar=mycas.outscalar
             outarray=mycas.outarray;
    id date interval = qtr;
    var consumption /acc = sum;
    outscalars diff pvalue;
    outarray aic1 aic2;
    require tsa;
    submit;
        
        declare object tsa(tsa);

        do diff = 0 to 12; 
            *diff indicates number of differencing, increase differencing until stationarity is met;
            rc = tsa.stationaritytest(consumption,diff,,2,"szm",pvalue1);
            rc = tsa.stationaritytest(consumption,diff,,2,"ssm",pvalue2);
            rc = tsa.stationaritytest(consumption,diff,,2,"str",pvalue3);
            pvalue = max(pvalue1,pvalue2,pvalue3);
            if rc < 0 or rc >= 0 and pvalue <0.01 then leave;
        end;

    endsubmit;
quit;

proc print data=mycas.outscalar;
run;

*obtain tentitive autoregressive order(p) and order of moving average (q) in arima models;
proc tsmodel data=mycas.Fpp_usconsumption
             outscalar=mycas.outorders;
    outscalar pscan qscan pesacf qesacf pminic qminic;
    id date interval = qtr;
    var consumption /acc = sum;
    require tsa;
    submit;

        declare object tsa(tsa);
        *setting upper and lower search limit for the order of autoregressive;
        array p[2]/nosymbols; 
        p[1]=0; 
        p[2]=5; 

        *setting upper and lower search limit for the order of moving average;
        array q[2]/nosymbols;
        q[1]=0;
        q[2]=5; 

        *tried three different methods;
        rc = tsa.armaorders(consumption,1,"scan",p,q,,pscan,qscan);
        rc = tsa.armaorders(consumption,1,"esacf",p,q,,pesacf, qesacf);
        rc = tsa.armaorders(consumption,1,"minic",p,q,,pminic, qminic);

    endsubmit;
quit;

proc print data=mycas.outorders;
run;

*estimate arima model coefficient;
proc tsmodel data     = mycas.Fpp_usconsumption
             outobj   = (
                         outest = mycas.outest
                         outfor = mycas.outfor
                         )
             ;
    id date interval = qtr;
    var consumption /acc = sum;
    require tsm;
    submit;
        declare object arima(arimaspec);
        declare object tsm(tsm);
        declare object outest(tsmpest);
        declare object outfor(tsmfor);

        array diff[1]/nosymbols; 
        diff[1]=1; *from the stationary test results;

        *used the minic method output, so p=3 and q=0;
        array ar[3]/nosymbols;
        ar[1]=1;
		ar[2]=2;
		ar[3]=3; 

        *specify arima model parameters;
        rc = arima.open();
        rc = arima.setDiff(diff);
        rc = arima.addARPoly(ar);
        rc = arima.setOption('method', 'ml');
        rc = arima.close();

        *set options: y variable, lead, model;
        rc = tsm.initialize(arima);
        rc = tsm.setY(consumption);
        rc = tsm.setOption('lead',10);
        rc = tsm.run();

        *collect the estimates into object called outest;
        rc = outfor.collect(tsm);
        rc = outest.collect(tsm);
        ;
    endsubmit;
quit;


*doing everything in one tsmodel step;
proc tsmodel data      = mycas.Fpp_usconsumption
             outscalar = mycas.outscalar
             outobj    = (
                          outest  = mycas.outest
                          outfor  = mycas.outfor
					      outspec = mycas.outspec
                          )
             ;
    outscalar diff1 pminic qminic;
    id date interval = qtr;
    var consumption /acc = sum;
    require tsa tsm;
    submit;
        declare object tsa(tsa);
        declare object arima(arimaspec);
        declare object tsm(tsm);
        declare object outest(tsmpest);
        declare object outfor(tsmfor);
        declare object outspec(tsmspec);
		
        do diff1 = 0 to 12;
            rc = tsa.stationaritytest(consumption,diff1,,2,"szm",pvalue1);
            rc = tsa.stationaritytest(consumption,diff1,,2,"ssm",pvalue2);
            rc = tsa.stationaritytest(consumption,diff1,,2,"str",pvalue3);
            pvalue = max(pvalue1,pvalue2,pvalue3);
            if rc < 0 or rc >= 0 and pvalue <0.01 then leave; 
        end;

        array p[2]/nosymbols;
        p[1]=0; 
        p[2]=5; 
        array q[2]/nosymbols;
        q[1]=0; 
        q[2]=5;
        rc = tsa.armaorders(consumption,diff1,"minic",p,q,,pminic, qminic);

		array ar[5]/nosymbols;
		if pminic >0 then do;
			do i =1 to pminic;
				ar[i] = i;
			end;
		end;

		array ma[5]/nosymbols;
		if qminic >0 then do;
            do j = 1 to qminic;
				ma[j]= j; 
	        end;
		end;


		array diff_array[1]/nosymbols;
		diff_array[1] = diff1;

        rc = arima.open();
        rc = arima.setDiff(diff_array);

        *only addARPoly if ar order not equal to zero;
        if pminic >0 then rc = arima.addARPoly(ar,pminic); 
        if qminic >0 then rc = arima.addMAPoly(ma,qminic);
        rc = arima.setOption('method', 'ml');
        rc = arima.close();

        rc = tsm.initialize(arima);
        rc = tsm.setY(consumption);
        rc = tsm.setOption('lead',10);
        rc = tsm.run();

        rc = outfor.collect(tsm);
        rc = outest.collect(tsm);
        rc = outspec.collect(tsm);
    endsubmit;
quit;


*automatical diagnose the time seires to get candidate ARIMA models;
proc tsmodel data      = mycas.Fpp_usconsumption
             outobj    = (
                          outest  = mycas.outest
                          outfor  = mycas.outfor
                          outstat = mycas.outstat
                          )
             ;
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
        rc = dataframe.addY(consumption);

        *set diagnose parameter;
        rc = diagspec.open();
        rc = diagspec.setArimax('estmethod', 'ml'); *set arima models to be considered in diagnose;
        rc = diagspec.setCombine(); *set the combined model also be considered;
        rc = diagspec.close();

        *run diagnose;
        rc = diagnose.initialize(dataframe);
        rc = diagnose.setSpec(diagspec);
        rc = diagnose.run();

        *run forecast engine;
        rc = forecast.initialize(diagnose);
        rc = forecast.setOption('criterion','rmse');
        rc = forecast.setOption('lead',10);
        rc = forecast.run();

        *collect output;
        rc = outest.collect(forecast);
        rc = outfor.collect(forecast);
        rc = outstat.collect(forecast);
    endsubmit;
quit;


/**** Example 8.2 Seasonally adjusted electrical equipment orders ****/
/**** https://www.otexts.org/fpp/8/7 ****/

data mycas.Fpp_elecequip;
    set time.Fpp_elecequip;
run;

proc tsmodel data=mycas.Fpp_elecequip
             outarray = mycas.decomp;
    id date interval=month;
	var noi/acc = sum;
    outarrays vtcc vsc vic vsa;
    require tsa;
    submit;
        declare object tsa(tsa);
        *mode="add" specifies the additive decomposition;
        rc = tsa.seasonaldecomp(noi,_seasonality_,"add", ,vtcc, ,vsc , , ,vic,vsa);
    endsubmit;
quit;

*perform arima model on the seasonally adjusted series in dataset mycas.decomp;
proc tsmodel data      = mycas.decomp
             outscalar = mycas.outscalar
             outobj    = (
                          outest  = mycas.outest
                          outfor  = mycas.outfor
					      outspec = mycas.outspec
                          )
             ;
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
        rc = arima.setDiff(diff_array);
        rc = arima.addARPoly(ar); 
        rc = arima.addMAPoly(ma);
        rc = arima.setOption('method', 'ml');
        rc = arima.close();

        rc = tsm.initialize(arima);
        rc = tsm.setY(vsa);
        rc = tsm.setOption('lead',10);
        rc = tsm.run();

        rc = outfor.collect(tsm);
        rc = outest.collect(tsm);
        rc = outspec.collect(tsm);
    endsubmit;
quit;


/**** 8.9 Seasonal ARIMA models ****/
/**** Example 8.3 European quarterly retail trade ****/
/**** https://www.otexts.org/fpp/8/9 ****/

data mycas.Fpp_euretail;
    set time.Fpp_euretail;
run;

*perform seasonal arima models;
proc tsmodel data      = mycas.Fpp_euretail
             outscalar = mycas.outscalar
             outobj    = (
                          outest1  = mycas.outest1
						  outspec1 = mycas.outspec1
                          outfor1 = mycas.outfor1
                          outest2  = mycas.outest2
						  outspec2 = mycas.outspec2
                          outfor2 = mycas.outfor2                          )
             ;
    id date interval = qtr end='31DEC2008'd;
    var Retail_Index /acc = sum;
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
        array ma_array1s[1]/nosymbols;*seasonal MA;
        ma_array1s[1]=1;
		array diff_array1[2]/nosymbols;
		diff_array1[1] = 1;
		diff_array1[2] = .s; *represent the seasonality;

        rc = arima.open();
        rc = arima.setDiff(diff_array1);
        rc = arima.addMAPoly(ma_array1, 1, 0);*Adding non-seasonal MA. ;
		rc = arima.addMAPoly(ma_array1s, 1, 1);*Adding seasonal MA.;
        rc = arima.setOption('method', 'ml');
        rc = arima.close();

        rc = tsm.initialize(arima);
        rc = tsm.setY(Retail_Index);
        rc = tsm.setOption('lead',12);
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
        rc = arima.setDiff(diff_array2);
        rc = arima.addMAPoly(ma_array2, 3, 0);*Adding non-seasonal MA. ;
		rc = arima.addMAPoly(ma_array2s, 1, 1);*Adding seasonal MA.;
        rc = arima.setOption('method', 'ml');
        rc = arima.close();

        rc = tsm.initialize(arima);
        rc = tsm.setY(Retail_Index);
        rc = tsm.setOption('lead',12);
        rc = tsm.run();

        rc = outfor2.collect(tsm);
        rc = outest2.collect(tsm);
        rc = outspec2.collect(tsm);


    endsubmit;
quit;

*automatical diagnose the time seires to get candidate ARIMA models;
proc tsmodel data      = mycas.Fpp_euretail
             outobj    = (
                          outest  = mycas.outest
                          outfor  = mycas.outfor
                          outstat = mycas.outstat
                          )
             ;
    id date interval = qtr end='31DEC2008'd;
    var Retail_Index /acc = sum;
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
        rc = dataframe.addY(Retail_Index);

        *set diagnose parameter;
        rc = diagspec.open();
        rc = diagspec.setArimax('estmethod', 'ml'); *set arima models to be considered in diagnose;
        rc = diagspec.setCombine(); *set the combined model also be considered;
        rc = diagspec.close();

        *run diagnose;
        rc = diagnose.initialize(dataframe);
        rc = diagnose.setSpec(diagspec);
		rc = diagnose.SetOption('holdout', 12);
        rc = diagnose.run();

        *run forecast engine;
        rc = forecast.initialize(diagnose);
        rc = forecast.setOption('criterion','rmse');
		rc = forecast.SetOption('holdout', 12);
        rc = forecast.setOption('lead',12);
        rc = forecast.run();

        *collect output;
        rc = outest.collect(forecast);
        rc = outfor.collect(forecast);
        rc = outstat.collect(forecast);
    endsubmit;
quit;


/**** 8.9 Seasonal ARIMA models ****/
/**** Example 8.4 Cortecosteroid drug sales in Australia ****/
/**** https://www.otexts.org/fpp/8/9 ****/

data mycas.Fpp_H02;
    set time.Fpp_H02;
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

proc tsmodel data      = mycas.Fpp_H02
             outscalar = mycas.&outSummary
             outobj    = (
                          outest  = mycas.outest
                          outfor  = mycas.&outfor
					      outspec = mycas.outspec
                          )
             ;
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
        rc = arima.setDiff(diff_array);
        if ar[1]>0 then rc = arima.addARPoly(ar, ,0); 
		if ars[1]>0 then rc = arima.addARPoly(ars, ,1); 
        if ma[1]>0 then rc = arima.addMAPoly(ma, ,0);
		if mas[1]>0 then rc = arima.addMAPoly(mas, ,1);
        rc = arima.setOption('method', 'ml');
        rc = arima.close();

        rc = tsm.initialize(arima);
        rc = tsm.setY(H02);
        rc = tsm.setOption('back',24);
        rc = tsm.setOption('lead',24);
        rc = tsm.run();

        rc = outfor.collect(tsm);
        rc = outest.collect(tsm);
        rc = outspec.collect(tsm);
        
        *compute RMSE;
		array predict[1]/nosymbols;
        
        *change array size based on the size of the variable H02;
		call dynamic_array(predict, dim(H02));
        rc = tsm.getForecast('predict', predict);
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
proc tsmodel data      = mycas.Fpp_H02
             outobj    = (
                          outest  = mycas.outest
                          outfor  = mycas.outfor
                          outstat = mycas.outSummary
                          )
             ;
    id date interval = month;
    var H02 /acc = sum;
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
        rc = dataframe.addY(H02);

        *set diagnose parameter;
        rc = diagspec.open();
        rc = diagspec.setArimax('estmethod','ml'); *set arima models to be considered in diagnose;
        rc = diagspec.setCombine(); *set the combined model also be considered;
        rc = diagspec.close();

        *run diagnose;
        rc = diagnose.initialize(dataframe);
        rc = diagnose.setSpec(diagspec);
		rc = diagnose.SetOption('holdout', 12);
        rc = diagnose.run();

        *run forecast engine;
        rc = forecast.initialize(diagnose);
        rc = forecast.setOption('criterion','rmse');
		rc = forecast.SetOption('holdout', 12);
        rc = forecast.setOption('back',24);
        rc = forecast.setOption('lead',24);
        rc = forecast.run();

        *collect output;
        rc = outest.collect(forecast);
        rc = outfor.collect(forecast);
        rc = outstat.collect(forecast);
    endsubmit;
quit;
