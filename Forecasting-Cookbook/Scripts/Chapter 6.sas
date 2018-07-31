*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;

/**** 6.1 Time series components ****/
/**** https://www.otexts.org/fpp/6/1 ****/

/** time series patterns **/

data mycas.fpp_dj;
    set time.fpp_dj; 
run;

*use PROC TSMODEL to compute the lag of the dow jones index variable;
proc tsmodel data=mycas.fpp_dj
             outarray = mycas.fpp_dj_lag;
    id day interval=day;
	var dow_jones;
    outarrays diff_dj;
    submit;
        do i = 1 to dim(dow_jones);
		    if i = 1 then diff_dj[i] = .;
			else diff_dj[i] = dow_jones[i] - dow_jones[i-1];
        end;
    endsubmit;
quit;

/** Example 6.1 Electrical equipment manufacturing **/

data mycas.fpp_elecequip;
    set time.fpp_elecequip;
run;

/* use the tsmodel TSA (Time Series Analysis) package to perform the 
   seasonal decomposition.
   SEASONALDECOMP: This function computes the seasonal indices of a univariate time series
                   using Classical Decomposition.
   Signature:
   rc = TSA.SEASONALDECOMP(y,s,mode,lambda,tcc,sic,sc,scstd,tcs,ic,sa,pcsa,tc,cc);
   
   followings are the vectors this function creates:
   tcc= Trend-cycle component
   sic= Seasonal-irregular component
   sc= Seasonal component
   scstd= Seasonal component standard errors
   tcs=	Trend-cycle-seasonal component
   ic= Irregular component
   sa= Seasonally adjusted series
   pcsa= Percent change seasonally adjusted series
   tc= Trend component
   cc= Cycle component
*/

proc tsmodel data=mycas.fpp_elecequip
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


/**** 6.2 Moving averages ****/
/**** https://www.otexts.org/fpp/6/2 ****/

/** Moving average smoothing **/
data mycas.fpp_elecsales;
    set time.fpp_elecsales;
	years = mdy(1,1,year); *changing the format of date;
run;

/* use the tsmodel TSA (Time Series Analysis) package to perform the 
   Moving Averages.
   MOVING SUMMARY STATISTICS
   Signature
   rc = TSA.MOVINGSUMMARY(y, method, k, lead, w, setmiss, abs, x, p, nmiss);
*/
proc tsmodel data=mycas.fpp_elecsales
             outarray = mycas.elecsales_ma;
    id years interval=year;
	var gwh;
    outarrays mean3_gwh mean5_gwh mean7_gwh mean9_gwh;
    require tsa;
    submit;
        declare object tsa(tsa);

        *for centered moving summary, use lead = floor(k/2);
        *method="mean" specifies the moving average;
        rc = tsa.movingsummary(gwh,"mean", 3, 1, , , ,mean3_gwh); 
		rc = tsa.movingsummary(gwh,"mean", 5, 2, , , ,mean5_gwh);
		rc = tsa.movingsummary(gwh,"mean", 7, 3, , , ,mean7_gwh);
		rc = tsa.movingsummary(gwh,"mean", 9, 4, , , ,mean9_gwh);
    endsubmit;
quit;


data mycas.FPP_AUSBEER;
    set TIME.FPP_AUSBEER;
	where (1992 <= Year <= 1996);
run;

/** Moving averages of moving averages **/
proc tsmodel data=mycas.fpp_ausbeer
             outarray = mycas.ausbeer_ma;
    id date interval=quarter;
	var aus_beer/acc=mean;
    outarrays mean4_aus_beer mean2x4_aus_beer;
    require tsa;
    submit;
        declare object tsa(tsa);
        rc = tsa.movingsummary(aus_beer,"mean", 4, 2, ,"missing", ,mean4_aus_beer);
        rc = tsa.movingsummary(mean4_aus_beer,"mean", 2, 0, ,"missing", ,mean2x4_aus_beer);
    endsubmit;
quit;

/** Example 6.2 Electrical equipment manufacturing **/

data mycas.fpp_elecequip;
    set time.fpp_elecequip;
run;

proc tsmodel data=mycas.fpp_elecequip
             outarray = mycas.elecequip_ma;
    id date interval=month;
	var noi/acc=sum;
    outarrays mean12_noi mean2x12_noi;
    require tsa;
    submit;
        declare object tsa(tsa);
        rc = tsa.movingsummary(noi,"mean", 12, 6, ,"missing", ,mean12_noi);
        rc = tsa.movingsummary(mean12_noi,"mean", 2, 0, ,"missing", ,mean2x12_noi);
    endsubmit;
quit;
