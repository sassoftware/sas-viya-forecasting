libname mycas cas;

*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

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
data MYCAS.FPP_USCONSUMPTION;
	set time.FPP_USCONSUMPTION;
run;

*test for seasonality and stationarity for different differencing;
proc tsmodel data=mycas.Fpp_usconsumption
             outscalar=mycas.outscalar
             outarray=mycas.outarray;
    id date interval = qtr;
    var consumption /acc = sum;
    outscalars diff pvalue;
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
proc carima data=MYCAS.FPP_USCONSUMPTION outstat=MYCAS.outStatTemp 
		outest=MYCAS.outest outfor=MYCAS.outFcastTemp;
	id Date interval=qtr;
	identify consumption;
	estimate p=(1 2 3) diff=(1) method=ML;
	forecast lead=10 alpha=0.05;
run;

proc print data=MYCAS.outest;
run;

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
proc carima data=MYCAS.DECOMP outstat=MYCAS.outStatTemp 
		outfor=MYCAS.outFcastTemp outest=MYCAS.outest;
	id Date interval=month;
	identify vsa;
	estimate p=(1 2 3) q=(1) diff=(1) noint method=ML;
	forecast lead=10 alpha=0.05;
run;

proc print data=MYCAS.outest;
run;

data mycas.Fpp_euretail;
    set time.Fpp_euretail;
run;

proc carima data=MYCAS.FPP_EURETAIL outstat=MYCAS.outStatTemp 
		outest=MYCAS.OUTEST outfor=MYCAS.outFcastTemp;
	id Date interval=qtr;
	identify Retail_Index;
	*The ARIMA(0,1,1)(0,1,1)[4] configuration was taken from the book example;
	estimate q=(1) (4) diff=(1 4) noint method=ML;
	forecast lead=12 alpha=0.05;
run;

proc carima data=MYCAS.FPP_EURETAIL outstat=MYCAS.outStatTemp 
		outest=MYCAS.OUTEST outfor=MYCAS.outFcastTemp;
	id Date interval=qtr;
	identify Retail_Index;
	*The ARIMA(0,1,3)(0,1,1)[4] configuration was taken from the book example;
	estimate q=(1 2 3) (4) diff=(1 4) noint method=ML;
	forecast lead=12 alpha=0.05;
run;

proc carima data=MYCAS.FPP_EURETAIL outstat=MYCAS.outStatTemp 
		outest=MYCAS.OUTEST outfor=MYCAS.outFcastTemp;
	id Date interval=qtr;
	identify Retail_Index;
	*The ARIMA(1,1,1)(0,1,1)[4] configuration was taken from the book example;
	estimate p=(1) q=(1) (4) diff=(1 4) noint method=ML;
	forecast lead=12 alpha=0.05;
run;

data mycas.fpp_h02;
	set time.fpp_h02;
run;

proc tsmodel data=mycas.fpp_h02 outarray=mycas.BOXCOX_fpp_h02;
	id Date interval=month;
	var H02;
	require tsa;
	outarrays t_H02;
	submit;
		declare object TSA(tsa);
		rc = TSA.TRANSFORM(H02, 'BOXCOX',0,0,t_H02);
	endsubmit;
	run;
quit;

proc carima data=MYCAS.BOXCOX_fpp_h02 outstat=MYCAS.outStatTemp 
		outest=MYCAS.OUTEST outfor=MYCAS.outFcastTemp;
	id Date interval=month;
	identify t_H02;
	*The ARIMA(3,0,1)(0,1,2)[12] configuration was taken from the book example;
	estimate p=(1 2 3) q=(1) (12 24) diff=(12) noint method=ML;
	forecast lead=12 alpha=0.05;
run;

data mycas.fpp_h02_train;
	set time.fpp_h02;
	if (Date<='01JUN2006'd) then output;
run;

*The ARIMA(3,0,0)(2,1,0)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict1;
	id Date interval=month;
	identify h02;
	estimate p=(1 2 3) (12 24) diff=(12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

* This section shows how to compute the RMSE based on the above model forecast and observations in testing set;
data work.fpp_h02_testing;
	set time.fpp_h02;
    if (Date>'01JUN2006'd) then output;
	keep Date h02;
run;

data mycas.fpp_h02_testing;
	set work.fpp_h02_testing;
run;

data MYCAS.forecast;
	set MYCAS.predict1;
	if (Date>'01JUN2006'd) then output;
	keep Date PREDICT;
run;

data MYCAS.forecast;
	merge MYCAS.forecast MYCAS.fpp_h02_testing;
	by Date;
run;

data work.forecast;
	set MYCAS.forecast;
	label H02='Actual Values';
run;

proc sort data = work.forecast;
	by Date;
run;

* RMSE is computed as follows;
data work.RMSE;
	retain so_far;
	set work.forecast end=last;
	error=PREDICT-h02;
	square_error=error*error;
	if _n_ eq 1 then so_far = square_error;
		else so_far=so_far+ square_error;
	if last then so_far = sqrt(so_far/_n_);
	keep so_far;
	label so_far='RMSE';
	if last then output;
run;

*Other models:;
*The ARIMA(3,0,1)(2,1,0)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict2;
	id Date interval=month;
	identify h02;
	estimate p=(1 2 3) (12 24) q=(1) diff=(12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

*The ARIMA(3,0,2)(2,1,0)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict3;
	id Date interval=month;
	identify h02;
	estimate p=(1 2 3) (12 24) q=(1 2) diff=(12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

*The ARIMA(3,0,2)(1,1,0)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict4;
	id Date interval=month;
	identify h02;
	estimate p=(1 2 3) (12) q=(1) diff=(12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

*The ARIMA(3,0,2)(0,1,1)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict5;
	id Date interval=month;
	identify h02;
	estimate p=(1 2 3) q=(1) (12) diff=(12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

*The ARIMA(3,0,2)(0,1,2)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict6;
	id Date interval=month;
	identify h02;
	estimate p=(1 2 3) q=(1) (12 24) diff=(12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

*The ARIMA(3,0,2)(1,1,1)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict7;
	id Date interval=month;
	identify h02;
	estimate p=(1 2 3) (12) q=(1) (12) diff=(12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

*The ARIMA(4,0,3)(0,1,1)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict8;
	id Date interval=month;
	identify h02;
	estimate p=(1 2 3 4) q=(1 2 3) (12) diff=(12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

*The ARIMA(3,0,3)(0,1,1)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict9;
	id Date interval=month;
	identify h02;
	estimate p=(1 2 3) q=(1 2 3) (12) diff=(12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

*The ARIMA(4,0,2)(0,1,1)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict10;
	id Date interval=month;
	identify h02;
	estimate p=(1 2 3 4) q=(1 2) (12) diff=(12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

*The ARIMA(3,0,2)(0,1,1)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict11;
	id Date interval=month;
	identify h02;
	estimate p=(1 2 3) q=(1 2) (12) diff=(12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

*The ARIMA(2,1,3)(0,1,1)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict12;
	id Date interval=month;
	identify h02;
	estimate p=(1 2) q=(1 2 3) (12) diff=(1 12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

*The ARIMA(2,1,4)(0,1,1)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict13;
	id Date interval=month;
	identify h02;
	estimate p=(1 2) q=(1 2 3 4) (12) diff=(1 12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;

*The ARIMA(2,1,5)(0,1,1)[12] configuration was taken from the book example;
proc carima data=MYCAS.FPP_H02_TRAIN outstat=MYCAS.outStatTemp 
		outfor=MYCAS.predict14;
	id Date interval=month;
	identify h02;
	estimate p=(1 2) q=(1 2 3 4 5) (12) diff=(1 12) noint transform=log method=ML;
	forecast lead=24 alpha=0.05;
run;
