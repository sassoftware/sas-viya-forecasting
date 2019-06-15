*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;

/**** 7.1 Simple exponential smoothing ****/
/**** https://otexts.org/fpp2/ses.html ****/

/** Example: Oil production **/
/** https://otexts.org/fpp2/ses.html **/

data mycas.fpp2_oil;
    set time.fpp2_oil;
    if year(date) >= 1996 then output;
run;

/* simple exponential smoothing model with automatic alpha estimation using TSM package*/
proc tsmodel data=mycas.fpp2_oil
                  outobj = (
                  outfor = mycas.outfor
                  outest = mycas.outest
                  outstat = mycas.outstat);
    id date interval = year;
    var oil;
    require tsm;
    submit;
        declare object simple(esmspec);
        declare object tsm(tsm);
        
        *forecast, parameter estimates and statistics of fit collector objects;
        declare object outfor(tsmfor);
        declare object outest(tsmpest);
        declare object outstat(tsmstat);

        rc = simple.open();
        rc = simple.setoption('method', 'simple');
        rc = simple.close();

        rc = tsm.initialize(simple);
        rc = tsm.sety(oil);
        rc = tsm.setoption('criterion','rmse');
        rc = tsm.setoption('lead', 5);
        rc = tsm.run();

        rc = outfor.collect(tsm);
        rc = outest.collect(tsm);
		rc = outstat.collect(tsm);
    endsubmit;
quit;

/**** 7.2 Trend methods ****/
/**** Example: Air Passengers ****/
/**** https://otexts.com/fpp2/holt.html ****/

data mycas.fpp2_ausair;
    set time.fpp2_ausair;
    if year(date) >= 1990 then output;
run;

proc tsmodel data=mycas.fpp2_ausair
			outobj = (outfor_holtLinear = mycas.outfor_holtLinear);
    id date interval = year;
    var value;
    require tsm;
    submit;
        declare object linear(esmspec);
        declare object tsm(tsm);
        
        *forecast collector object;
        declare object outfor_holtlinear(tsmfor);

        *setup esm model with alpha = 0.8321 and beta = 0.0001;
        rc = linear.open();
        rc = linear.setoption("method", "linear", "noest", 1);
        *set the level (alpha) parameter to 0.8321;
        rc = linear.setparm("level", 0.8321);
        *set the trend (beta) parameter to 0.0001;
        rc = linear.setparm("trend", 0.0001);
        rc = linear.close();

        rc = tsm.initialize(linear);
        rc = tsm.sety(value);
        rc = tsm.setoption('criterion','rmse');
        rc = tsm.setoption('lead', 5);
        rc = tsm.run();
        
        rc = outfor_holtlinear.collect(tsm);
    endsubmit;
quit;

/**** Example: Air Passengers (continued) ****/
/**** https://otexts.com/fpp2/holt.html ****/

proc tsmodel data=mycas.fpp2_ausair
			outobj = (outfor_damped = mycas.outfor_damped
					outest_damped = mycas.outest_damped);
    id date interval = year;
    var value;
    require tsm;
    submit;
        declare object damped(esmspec);
        declare object tsm(tsm);
        
        *forecast and parameter estimate collector objects; 
        declare object outfor_damped(tsmfor);
        declare object outest_damped(tsmpest);

        rc = damped.open();
        rc = damped.setoption('method', 'damptrend');
        rc = damped.close();

        rc = tsm.initialize(damped);
        rc = tsm.sety(value);
        rc = tsm.setoption('criterion','rmse');
        rc = tsm.setoption('lead', 15);
        rc = tsm.run();
        
        rc = outfor_damped.collect(tsm);
        rc = outest_damped.collect(tsm);
    endsubmit;
quit;

/**** 7.2 Trend methods ****/
/**** https://otexts.com/fpp2/holt.html ****/
/**** Example: Sheep in Asia ****/

data mycas.fpp2_livestock;
    set time.fpp2_livestock;
run;

proc tsmodel data=mycas.fpp2_livestock
			outobj = (outfor = mycas.outfor
			outmodelinfo = mycas.outmodelinfo
			outstat = mycas.outstat
			outselect = mycas.outselect
			outest = mycas.outest);
    id date interval = year;
    var livestock;
    require tsm atsm;
    submit;
    
    	*declaring three esmspec objects from tsm package;
		declare object linear(esmspec);
		declare object simple(esmspec);
		declare object damped(esmspec);
        
        *defining the three models;
        rc = simple.open();
        rc = simple.setoption('method', 'simple');
        rc = simple.close();
        
        rc = damped.open();
        rc = damped.setoption('method', 'damptrend');
        rc = damped.close();

        rc = linear.open();
        rc = linear.setoption('method', 'linear');
        rc = linear.close();
        
        *defining selspec object from atsm package that takes three esmspec objects;
        declare object selspec(selspec);
        rc = selspec.open(3);
        rc = selspec.addfrom(simple);
        rc = selspec.addfrom(damped);
        rc = selspec.addfrom(linear);
        rc = selspec.close();
        
        *defining a tsdf object from atsm package;
        declare object dataframe(tsdf);
        rc = dataframe.initialize();
        rc = dataframe.addy(livestock);
        
        *defining a foreng object that takes selspec and tsdf object;
        declare object foreng(foreng);
        rc = foreng.initialize(dataframe);
        rc = foreng.addfrom(selspec);
        rc = foreng.setoption('holdout',1);
        rc = foreng.setoption('criterion','rmse');
        rc = foreng.setoption('lead', 10);
        rc = foreng.run();
        
        /*foreng object uses the defined models in the selspec object and choose the best
        one from them according to holdout and criterion options */
       
        *outputs are collected from the foreng object;
		declare object outfor(outfor);
		declare object outmodelinfo(outmodelinfo);
		declare object outstat(outstat);
		declare object outselect(outselect);
		declare object outest(outest);
		
		rc = outfor.collect(foreng);
		rc = outmodelinfo.collect(foreng);
		rc = outstat.collect(foreng);
		rc = outselect.collect(foreng);
		rc = outest.collect(foreng);
    endsubmit;
quit;

/**** 7.3 Holt-Winters’ seasonal method ****/
/**** https://otexts.com/fpp2/holt-winters.html ****/
/**** Example: International tourist visitor nights in Australia ****/

data mycas.fpp2_austourists;
    set time.fpp2_austourists;
    if year(date) >= 2005 then output;
run;

proc tsmodel data   = mycas.fpp2_austourists
             outobj = (outest_winters    = mycas.outest_winters
                       outfor_winters    = mycas.outfor_winters
                       outest_addwinters = mycas.outest_addwinters
                       outfor_addwinters = mycas.outfor_addwinters);
    id date interval = qtr;
    var austourists;
    require tsm;
    submit;
		declare object winters(esmspec);
		declare object addwinters(esmspec);
		declare object tsm(tsm);
		declare object outest_winters(tsmpest);
		declare object outest_addwinters(tsmpest);
		declare object outfor_winters(tsmfor);
		declare object outfor_addwinters(tsmfor);


        *define the additive and multiplicative winters methods;
        rc = winters.open();
        rc = addwinters.open();
        rc = winters.setoption("method", "winters");
        rc = addwinters.setoption("method", "addwinters");
        rc = winters.close();
        rc = addwinters.close();

        *run forecast for multiplicative winters method;
        rc = tsm.initialize(winters);
        rc = tsm.sety(austourists);
        rc = tsm.setoption('criterion','rmse');
        rc = tsm.setoption('lead',8);
        rc = tsm.run();
        rc = outest_winters.collect(tsm);
        rc = outfor_winters.collect(tsm);

        *run forecast for additive winters method;
        rc = tsm.initialize(addwinters);
        rc = tsm.sety(austourists);
        rc = tsm.setoption('criterion','rmse');
        rc = tsm.setoption('lead',8);
        rc = tsm.run();
        rc = outest_addwinters.collect(tsm);
        rc = outfor_addwinters.collect(tsm);
    endsubmit;
quit;

/*the following code utilizes ATSM package to define 
  models and automatically diagnose models. Then select among 
  all the models to get the best model based on the RMSE criteria
*/
proc tsmodel data = mycas.fpp2_austourists
			outobj = (outfor = mycas.outfor
					outstat = mycas.outstat
					outest = mycas.outest);
	id date interval = qtr;
    var austourists;
    require atsm;
	submit;
		declare object dataframe(tsdf);
		declare object diagnose(diagnose);
		declare object diagspec(diagspec);
		declare object foreng(foreng);
		
		rc = dataframe.initialize();
		rc = dataframe.addy(austourists);
		
		rc = diagspec.open();
		rc = diagspec.setesm('method', 'best');
		rc = diagspec.setoption('criterion','rmse');
		rc = diagspec.close();
		
		rc = diagnose.initialize(dataframe);
		rc = diagnose.setspec(diagspec);
		rc = diagnose.run();
		
		rc = foreng.initialize(diagnose);
		rc = foreng.setoption('criterion','rmse');
		rc = foreng.setoption('lead', 12);
		rc = foreng.run();
		
		declare object outfor(outfor);
		declare object outstat(outstat);
		declare object outest(outest);		
		rc = outfor.collect(foreng);
		rc = outstat.collect(foreng);
		rc = outest.collect(foreng);
	endsubmit;
quit;