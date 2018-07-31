*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;

/**** 7.1 Simple exponential smoothing ****/
/**** https://www.otexts.org/fpp/7/1 ****/

proc sgplot data=time.fpp_oil(where=(1996 <= year <= 2007));
    series x = year y = oil;
	yaxis label = 'oil (millions of tonness)';
	title;
run;

/** Example 7.1 Oil production **/
*load data to CAS;
data mycas.fpp_oil;
    set time.fpp_oil;
    where 1996 <= year <= 2007;
    years = mdy(1,1,year);
run;

/* simple exponential smoothing model with fixed alpha using TSM package*/
proc tsmodel data=mycas.fpp_oil
                  outobj = (
                             outfor_02   = mycas.outfor_02
                             outfor_06   = mycas.outfor_06
                             outfor_auto = mycas.outfor_auto
                            )
                  ;
    id years interval = year;
    var oil /acc = sum ;
    require tsm;
    submit;
        declare object simple(esmspec);
        declare object tsm(tsm);
        
        *forecast collector objects for the diffferent settings;
        declare object outfor_02(tsmfor);
        declare object outfor_06(tsmfor);
        declare object outfor_auto(tsmfor);

        *setup esm model with alpha = 0.2 with no-estimate option;
        rc = simple.open();
        rc = simple.setOption("METHOD", "SIMPLE", "NOEST", 1);
        *set the LEVEL (alpha) parameter to 0.2;
        rc = simple.setParm("LEVEL", 0.2);
        rc = simple.close();

        rc = tsm.initialize(simple);
        rc = tsm.setY(oil);
        rc = tsm.setOption('criterion','rmse');
        rc = tsm.setOption('lead',3);
        rc = tsm.run();

        *collect forecast result for simple exponential model with alpha = 0.2;
        rc = outfor_02.collect(tsm);

        *reuse the simple, gselect, and forecast objects for other models;
        *reopen the spec object will reset the object back to the default;
        rc = simple.open();
        rc = simple.setOption("METHOD", "SIMPLE", "NOEST", 1);
        *set the LEVEL (alpha) parameter to 0.6;
        rc = simple.setParm("LEVEL", 0.6);
        rc = simple.close();

        rc = tsm.initialize(simple);
        rc = tsm.setY(oil);
        rc = tsm.setOption('criterion','rmse');
        rc = tsm.setOption('lead',3);
        rc = tsm.run();

        rc = outfor_06.collect(tsm);

        *reuse the simple, gselect, and forecast objects for other models;
        rc = simple.open();
        rc = simple.setOption("METHOD", "SIMPLE");
        rc = simple.close();

        rc = tsm.initialize(simple);
        rc = tsm.setY(oil);
        rc = tsm.setOption('criterion','rmse');
        rc = tsm.setOption('lead',3);
        rc = tsm.run();

        rc = outfor_auto.collect(tsm);

    endsubmit;
quit;

/* simple exponential smoothing model with fixed alpha
   Instead of using the same esmspec object, the following code
   uses 3 seperate esmspec objects and are set at the begining of
   the code. Furthermore, a model selection process is added to 
   the code so that the forecast object will automatically choose
   the best model among the 3 esmspecs. The following code uses
   both the TSM and ATSM packages
*/
proc tsmodel data=mycas.fpp_oil
                  outobj = (
                             outfor_best = mycas.outfor_best
                            )
                  ;
    id years interval = year;
    var oil /acc = sum ;
    require tsm atsm;
    submit;
        declare object simple_02(esmspec);
        declare object simple_06(esmspec);
        declare object simple_auto(esmspec);
        declare object dataframe(tsdf);
        declare object gselect(selspec);
        declare object forecast(foreng);
        declare object outfor_best(outfor);

        rc = dataframe.initialize();
        rc = dataframe.addy(oil);

        rc = simple_02.open();
        rc = simple_02.setoption("METHOD", "SIMPLE", "NOEST", 1);
        rc = simple_02.setparm("LEVEL", 0.2);
        rc = simple_02.close();

        rc = simple_06.open();
        rc = simple_06.setoption("METHOD", "SIMPLE", "NOEST", 1);
        rc = simple_06.setparm("LEVEL", 0.6);
        rc = simple_06.close();

        rc = simple_auto.open();
        rc = simple_auto.setoption("METHOD", "SIMPLE");
        rc = simple_auto.close();

        *create a model selection list with all 3 models;
        rc = gselect.open(3);
        rc = gselect.addfrom(simple_02);
        rc = gselect.addfrom(simple_06);
        rc = gselect.addfrom(simple_auto);
        rc = gselect.close();

        rc = forecast.initialize(dataframe);
        rc = forecast.addfrom(gselect);

        *use RMSE to select among the 3 models;
        rc = forecast.setoption('criterion','rmse');
        rc = forecast.setoption('lead',3);
        rc = forecast.run();

        *collect forecast result;
        rc = outfor_best.collect(forecast);

    endsubmit;
quit;

/**** 7.2 Holt's linear trend method ****/
/**** https://www.otexts.org/fpp/7/2 ****/

/** Example 7.2 Air Passengers **/
data mycas.fpp_ausair;
    set time.fpp_ausair;
    where (1990 <= year <= 2004);
    years = mdy(1,1,year);
run;

/* linear exponential smoothing model with fixed alpha and beta (Holt Linear Trend model)
   log transformation is applied to the second model to approximate the exponential trend
   model described in the book
*/
proc tsmodel data=mycas.fpp_ausair
                  outobj = (
                             outfor_holtLinear    = mycas.outfor_holtLinear
                             outfor_holtExpLinear = mycas.outfor_holtExpLinear
                            )
                  ;
    id years interval = year;
    var passengers /acc = sum ;
    require tsm;
    submit;
        declare object linear(esmspec);
        declare object tsm(tsm);
        
        *forecast collector objects for the diffferent settings;
        declare object outfor_holtLinear(tsmfor);
        declare object outfor_holtExpLinear(tsmfor);

        *setup esm model with alpha = 0.8 and beta = 0.2;
        rc = linear.open();
        rc = linear.setOption("METHOD", "LINEAR", "NOEST", 1);
        *set the LEVEL (alpha) parameter to 0.8;
        rc = linear.setParm("LEVEL", 0.8);
        *set the TREND (beta) parameter to 0.2;
        rc = linear.setParm("TREND", 0.2);
        rc = linear.close();

        rc = tsm.initialize(linear);
        rc = tsm.setY(passengers);
        rc = tsm.setOption('criterion','rmse');
        rc = tsm.setOption('lead',5);
        rc = tsm.run();

        *collect forecast result for Holt linear trend model with alpha = 0.8 and beta = 0.2;
        rc = outfor_holtLinear.collect(tsm);

        *reuse the linear, gselect, and forecast objects for other models;
        *reopen the spec object will reset the object back to the default;
        rc = linear.open();
        rc = linear.setOption("METHOD", "LINEAR", "NOEST", 1);
        *set the LEVEL (alpha) parameter to 0.8;
        rc = linear.setParm("LEVEL", 0.8);
        *set the TREND (beta) parameter to 0.2;
        rc = linear.setParm("TREND", 0.2);

        *set the transformation to LOG to appromiximate exponential trend models;
        rc = linear.setTransform("LOG");
        rc = linear.close();

        rc = tsm.initialize(linear);
        rc = tsm.setY(passengers);
        rc = tsm.setOption('criterion','rmse');
        rc = tsm.setOption('lead',5);
        rc = tsm.run();

        rc = outfor_holtExpLinear.collect(tsm);

    endsubmit;
quit;


/**** 7.4 Damped trend linear trend method ****/
/**** https://www.otexts.org/fpp/7/4 ****/

/** Example 7.3 Sheep in Asia **/

data mycas.fpp_livestock;
    set time.fpp_livestock;
    where (1970 <= year <= 2000);
    years = mdy(1,1,year);
run;

/* output individual model forecasts using the TSM package */
proc tsmodel data=mycas.fpp_livestock
                  outobj = (
                             outfor_simple        = mycas.outfor_simple
                             outest_simple        = mycas.outest_simple
                             outfor_linear        = mycas.outfor_linear
                             outest_linear        = mycas.outest_linear
                             outfor_loglinear     = mycas.outfor_loglinear
                             outest_loglinear     = mycas.outest_loglinear
                             outfor_damptrend     = mycas.outfor_damptrend
                             outest_damptrend     = mycas.outest_damptrend
                             outfor_logdamptrend  = mycas.outfor_logdamptrend
                             outest_logdamptrend  = mycas.outest_logdamptrend
                            )
                  ;
    id years interval = year;
    var sheep /acc = sum ;
    require tsm;
    submit;
        *declare model spec objects;
        declare object simple(esmspec);
        declare object linear(esmspec);
        declare object loglinear(esmspec);
        declare object damptrend(esmspec);
        declare object logdamptrend(esmspec);

        declare object tsm(tsm);
        
        *declare forecast and parameter estimate collector objects;
        declare object outfor_simple(tsmfor);
        declare object outest_simple(tsmpest);
        declare object outfor_linear(tsmfor);
        declare object outest_linear(tsmpest);
        declare object outfor_loglinear(tsmfor);
        declare object outest_loglinear(tsmpest);
        declare object outfor_damptrend(tsmfor);
        declare object outest_damptrend(tsmpest);
        declare object outfor_logdamptrend(tsmfor);
        declare object outest_logdamptrend(tsmpest);

        rc = simple.open();
        rc = linear.open();
        rc = damptrend.open();
        rc = loglinear.open();
        rc = logdamptrend.open();

        *setting up model spec for the desired models;
        rc = simple.setOption("METHOD", "SIMPLE");
        rc = linear.setOption("METHOD", "LINEAR");
        rc = loglinear.setOption("METHOD", "LINEAR");
        rc = loglinear.setTransform("LOG");
        rc = damptrend.setOption("METHOD", "DAMPTREND");
        rc = logdamptrend.setOption("METHOD", "DAMPTREND");
        rc = logdamptrend.setTransform("LOG");

        rc = simple.close();
        rc = linear.close();
        rc = loglinear.close();
        rc = damptrend.close();
        rc = logdamptrend.close();

        *run SIMPLE model and collect forecast results;
        rc = tsm.initialize(simple);
        rc = tsm.setY(sheep);
        rc = tsm.setOption('criterion','rmse');
        rc = tsm.setOption('lead',10);
        rc = tsm.run();
        rc = outfor_simple.collect(tsm);
        rc = outest_simple.collect(tsm);

        *run LINEAR model and collect forecast results;
        rc = tsm.initialize(linear);
        rc = tsm.setY(sheep);
        rc = tsm.setOption('criterion','rmse');
        rc = tsm.setOption('lead',10);
        rc = tsm.run();
        rc = outfor_linear.collect(tsm);
        rc = outest_linear.collect(tsm);

        *run LOGLINEAR model and collect forecast results;
        rc = tsm.initialize(loglinear);
        rc = tsm.setY(sheep);
        rc = tsm.setOption('criterion','rmse');
        rc = tsm.setOption('lead',10);
        rc = tsm.run();
        rc = outfor_loglinear.collect(tsm);
        rc = outest_loglinear.collect(tsm);

        *run DAMPTREND model and collect forecast results;
        rc = tsm.initialize(damptrend);
        rc = tsm.setY(sheep);
        rc = tsm.setOption('criterion','rmse');
        rc = tsm.setOption('lead',10);
        rc = tsm.run();
        rc = outfor_damptrend.collect(tsm);
        rc = outest_damptrend.collect(tsm);

        *run LOGDAMPTREND model and collect forecast results;
        rc = tsm.initialize(logdamptrend);
        rc = tsm.setY(sheep);
        rc = tsm.setOption('criterion','rmse');
        rc = tsm.setOption('lead',10);
        rc = tsm.run();
        rc = outfor_logdamptrend.collect(tsm);
        rc = outest_logdamptrend.collect(tsm);
    endsubmit;
quit;


/*the following code utilizes the TSM package to
  define the five individual models + a combination model and then
  use the ATSM package to select among the 6 models using RMSE as the
  selection criteria
*/
proc tsmodel data=mycas.fpp_livestock
                  outobj = (
                             outest  = mycas.outest
                             outfor  = mycas.outfor
                             outstat = mycas.outstat
                            )
                  ;
    id years interval = year;
    var sheep /acc = sum ;
    require tsm atsm;
    submit;
        declare object simple(esmspec);
        declare object linear(esmspec);
        declare object loglinear(esmspec);
        declare object damptrend(esmspec);
        declare object logdamptrend(esmspec);

        declare object gcomb(combspec);
        declare object gselect(selspec);
        declare object dataframe(tsdf);
        declare object forecast(foreng);
        declare object outest(outest);
        declare object outfor(outfor);
        declare object outstat(outstat);

        rc = dataframe.initialize();
        rc = dataframe.addY(sheep);

        rc = simple.open();
        rc = linear.open();
        rc = damptrend.open();
        rc = loglinear.open();
        rc = logdamptrend.open();

        *setting up model spec for the desired models;
        rc = simple.setOption("METHOD", "SIMPLE");
        rc = linear.setOption("METHOD", "LINEAR");
        rc = loglinear.setOption("METHOD", "LINEAR");
        rc = loglinear.setTransform("LOG");
        rc = damptrend.setOption("METHOD", "DAMPTREND");
        rc = logdamptrend.setOption("METHOD", "DAMPTREND");
        rc = logdamptrend.setTransform("LOG");

        rc = simple.close();
        rc = linear.close();
        rc = loglinear.close();
        rc = damptrend.close();
        rc = logdamptrend.close();

        *combine the above models;
        rc = gcomb.open(5);
        rc = gcomb.addFrom(simple);
        rc = gcomb.addFrom(linear);
        rc = gcomb.addFrom(loglinear);
        rc = gcomb.addFrom(damptrend);
        rc = gcomb.addFrom(logdamptrend);
        rc = gcomb.close();

        *create a model selection list by adding --;
        rc = gselect.open(6);
        rc = gselect.addFrom(simple);
        rc = gselect.addFrom(linear);
        rc = gselect.addFrom(loglinear);
        rc = gselect.addFrom(damptrend);
        rc = gselect.addFrom(logdamptrend);
        rc = gselect.addFrom(gcomb);
        rc = gselect.close();

        rc = forecast.initialize(dataframe);
        rc = forecast.addFrom(gselect);
        rc = forecast.setOption('criterion','rmse');
        rc = forecast.setOption('lead',10);
        rc = forecast.run();

        rc = outest.collect(forecast);
        rc = outfor.collect(forecast);
        rc = outstat.collect(forecast);
    endsubmit;
quit;

/*the following code utilizes the ATSM package to
  automatically diagnose the time seires and form candidate models, and
  then select among the candidate models using the using RMSE as the
  selection criteria
*/
proc tsmodel data = mycas.fpp_livestock
             outobj = (
                       outest = mycas.outest
                       outfor = mycas.outfor
                       outstat = mycas.outstat
                       )
                  ;
    id years interval = year;
    var sheep /acc = sum ;
    require atsm;
    submit;
        declare object diagnose(diagnose);
        declare object diagspec(diagspec);
        declare object dataframe(tsdf);
        declare object forecast(foreng);
        declare object outest(outest);
        declare object outfor(outfor);
        declare object outstat(outstat);

        rc = dataframe.initialize();
        rc = dataframe.addy(sheep);

        rc = diagspec.open();
        rc = diagspec.setEsm();
        rc = diagspec.setCombine();
        rc = diagspec.close();

        rc = diagnose.initialize(dataframe);
        rc = diagnose.setSpec(diagspec);
        rc = diagnose.run();

        rc = forecast.initialize(diagnose);
        rc = forecast.setOption('criterion','rmse');
        rc = forecast.setOption('lead',10);
        rc = forecast.run();

        rc = outest.collect(forecast);
        rc = outfor.collect(forecast);
        rc = outstat.collect(forecast);
    endsubmit;
quit;


/**** 7.5 Holt-Winters Seasonal Method ****/
/**** https://www.otexts.org/fpp/7/5 ****/

/** Example 7.4 International tourist visitor nights in Australia **/
data mycas.fpp_austourists;
    set time.fpp_austourists;
run;

proc tsmodel data   = mycas.fpp_austourists
             outobj = (
                       outest_winters    = mycas.outest_winters
                       outfor_winters    = mycas.outfor_winters
                       outest_addwinters = mycas.outest_addwinters
                       outfor_addwinters = mycas.outfor_addwinters
                       )
                  ;
    id date interval = quarter start = '01Jan05'd;
    var tourists /acc = sum ;
    require tsm;
    submit;
        declare object winters(esmspec);
        declare object addwinters(esmspec);
        declare object tsm(tsm);
        declare object outest_winters(tsmpest);
        declare object outfor_winters(tsmfor);
        declare object outest_addwinters(tsmpest);
        declare object outfor_addwinters(tsmfor);

        *define the additive and multiplicative Winters methods;
        rc = winters.open();
        rc = addwinters.open();
        rc = winters.setOption("METHOD", "WINTERS");
        rc = addwinters.setOption("METHOD", "ADDWINTERS");
        rc = winters.close();
        rc = addwinters.close();

        *run forecast for multiplicative Winters method;
        rc = tsm.initialize(winters);
        rc = tsm.setY(tourists);
        rc = tsm.setOption('criterion','rmse');
        rc = tsm.setOption('lead',8);
        rc = tsm.run();
        rc = outest_winters.collect(tsm);
        rc = outfor_winters.collect(tsm);

        *run forecast for additive Winters method;
        rc = tsm.initialize(addwinters);
        rc = tsm.setY(tourists);
        rc = tsm.setOption('criterion','rmse');
        rc = tsm.setOption('lead',8);
        rc = tsm.run();
        rc = outest_addwinters.collect(tsm);
        rc = outfor_addwinters.collect(tsm);

    endsubmit;
quit;


/*the following code utilizes both TSM and ATSM to define 
  models and automatically diagnose models. Then select among 
  all the models to get the best model based on the RMSE criteria
*/
proc tsmodel data       = mycas.fpp_austourists
             outobj     = (
                           outest  = mycas.outest
                           outfor  = mycas.outfor
                           outstat = mycas.outstat
                           )
                  ;
    id date interval = quarter start = '01Jan05'd;
    var tourists /acc = sum; 
    require tsm atsm;
    submit;
        declare object winters(esmspec);
        declare object addwinters(esmspec);
        declare object gcomb(combspec);
        declare object gselect(selspec);
        declare object diagnose(diagnose);
        declare object diagspec(diagspec);
        declare object dataframe(tsdf);
        declare object forecast(foreng);
        declare object outest(outest);
        declare object outfor(outfor);
        declare object outstat(outstat);

        rc = dataframe.initialize();
        rc = dataframe.addY(tourists);

        *define the additive and multiplicative Winters methods;
        rc = winters.open();
        rc = addwinters.open();
        rc = winters.setOption("METHOD", "WINTERS");
        rc = addwinters.setOption("METHOD", "ADDWINTERS");
        rc = winters.close();
        rc = addwinters.close();

        *combine the above models;
        rc = gcomb.open(2);
        rc = gcomb.addFrom(winters);
        rc = gcomb.addFrom(addwinters);
        rc = gcomb.close();

        *setup automatic model diagnose specs;
        rc = diagspec.open();
		rc = diagspec.setEsm();
		rc = diagspec.setCombine();
		rc = diagspec.close();

		rc = diagnose.initialize(dataFrame);
		rc = diagnose.setSpec(diagspec);
        rc = diagnose.run();
        
        *compute the total number of models, 3 from TSM and nmodels() from diagnose object;
        num_models = diagnose.nmodels() + 3; 

        *create a model selection list including 3 models from TSM and diagnosed models;
        rc = gselect.open(num_models);
        rc = gselect.addFrom(winters);
        rc = gselect.addFrom(addwinters);
        rc = gselect.addFrom(gcomb);
        rc = gselect.addFrom(diagnose);
        rc = gselect.close();

        *run forecast;
        rc = forecast.initialize(dataframe);
        rc = forecast.addFrom(gselect);
        rc = forecast.setOption('criterion','rmse');
        rc = forecast.setOption('lead',10);
        rc = forecast.run();

        *collect results;
        rc = outest.collect(forecast);
        rc = outfor.collect(forecast);
        rc = outstat.collect(forecast);
    endsubmit;
quit;
