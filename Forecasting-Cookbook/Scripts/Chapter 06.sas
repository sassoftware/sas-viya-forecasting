*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;

/**** 6.2 Moving averages ****/
/**** https://otexts.org/fpp2/moving-averages.html ****/

/** Moving average smoothing **/

data mycas.fpp2_elecsales;
	set time.fpp2_elecsales;
run;

/* use the tsmodel TSA (Time Series Analysis) package to perform the 
   Moving Averages.
   MOVING SUMMARY STATISTICS
   Signature
   rc = TSA.MOVINGSUMMARY(y, method, k, lead, w, setmiss, abs, x, p, nmiss);
*/

proc tsmodel data=mycas.fpp2_elecsales
             outarray = mycas.decomp;
    id date interval=year;
	var elecsales;
    outarrays mean3_elecsales mean5_elecsales mean7_elecsales mean9_elecsales;
    require tsa;
    submit;
        declare object tsa(tsa);
        /* for centered moving summary, use lead = floor(k/2) */
        /* method="mean" specifies the moving average */
        rc = tsa.movingsummary(elecsales,"mean", 3, 1, , , ,mean3_elecsales); 
		rc = tsa.movingsummary(elecsales,"mean", 5, 2, , , ,mean5_elecsales); 
		rc = tsa.movingsummary(elecsales,"mean", 7, 3, , , ,mean7_elecsales); 
		rc = tsa.movingsummary(elecsales,"mean", 9, 4, , , ,mean9_elecsales); 
    endsubmit;
quit;

data mycas.fpp2_ausbeer_2;
    set time.fpp2_ausbeer;
	where year(date)>=1992;
run;

/** Moving averages of moving averages **/
proc tsmodel data=mycas.fpp2_ausbeer_2
             outarray = mycas.decomp;
    id date interval=quarter;
	var ausbeer;
    outarrays mean4_ausbeer mean2x4_ausbeer;
    require tsa;
    submit;
        declare object tsa(tsa);
        rc = tsa.movingsummary(ausbeer,"mean", 4, 2, ,"missing", ,mean4_ausbeer);
        rc = tsa.movingsummary(mean4_ausbeer,"mean", 2, 0, ,"missing", ,mean2x4_ausbeer);
    endsubmit;
quit;

/** Example: Electrical equipment manufacturing **/
/** https://otexts.org/fpp2/moving-averages.html **/

data mycas.fpp2_elecequip;
    set time.fpp2_elecequip;
run;

proc tsmodel data=mycas.fpp2_elecequip
             outarray = mycas.decomp;
    id date interval=month;
	var elecequip;
    outarrays mean12_elecequip mean2x12_elecequip;
    require tsa;
    submit;
        declare object tsa(tsa);
        rc = tsa.movingsummary(elecequip,"mean", 12, 6, ,"missing", ,mean12_elecequip);
        rc = tsa.movingsummary(mean12_elecequip,"mean", 2, 0, ,"missing", ,mean2x12_elecequip);
    endsubmit;
quit;

/**** 6.3 Classical decomposition ****/
/**** https://otexts.org/fpp2/classical-decomposition.html ****/

data mycas.fpp2_elecequip;
    set time.fpp2_elecequip;
run;

/* 
	use the tsmodel TSA (Time Series Analysis) package to perform the 
	seasonal decomposition.
	SEASONALDECOMP:	This function computes the seasonal indices of a univariate time series
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

proc tsmodel data=mycas.fpp2_elecequip
             outarray = mycas.decomp;
    id date interval=month;
	var elecequip;
    outarrays vtcc vsc vic vsa;
    require tsa;
    submit;
        declare object tsa(tsa);
        /* mode="mult" | "multiplicative" specifies the multiplicative decomposition */
        rc = tsa.seasonaldecomp(elecequip,_seasonality_,"mult", ,vtcc, ,vsc , , ,vic,vsa);
    endsubmit;
quit;
