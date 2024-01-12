/*
	%let sysparm=box:no;
	%cas_connect;
	%cas_disconnect;
*/

%macro MakeHyperParameterDataSet(indata=indata, outdata=outdata);
   	proc sql;
	  create table _tmpds as
	    select *
   	%let dsid = %sysfunc(open(&indata));
   	%let nv = %sysfunc(attrn(&dsid, nvars));
   	%do i=1 %to &nv; 
      	%let varname= %sysfunc(varname(&dsid, &i));	  
      	%if &i = 1 %then %do;
          	%let varlist= &varname; 
          	from &indata(keep=&varname)
      	%end;
	  	%else %do;
	      	%let varlist= &varlist , &varname; 
          	cross join &indata(keep=&varname)
      	%end;
	%end;
	order by &varlist;
	quit;

	data _tmpds;
    	set _tmpds;
   		%do i=1 %to &nv;
      		%let varname= %sysfunc(varname(&dsid, &i));
	  		%let vartype= %sysfunc(vartype(&dsid, &i));
	  		%if &vartype = N %then %do;
        		if &varname = . then delete;  
	  		%end;
	  		%else %do;
          		if strip(&varname) = '' then delete;  
	  		%end;
   		%end;
   	run;
   	%let dsid = %sysfunc(close(&dsid));

   	data &outdata;
      	format _id_ best12.;
       	set _tmpds;
	   	_id_ = _N_;
		label _id_ = "Hyperparamter Set ID";
   	run;
	proc delete data=_tmpds(gennum=all);
    run;
%mend MakeHyperParameterDataSet;

%macro MakeTuningDataSets(indata=, byvars=, inparms=, outparms=, outdata=);
    %let j =1;
	%let stringbyvars =;
    %do %while(%scan(&byvars, &j) ne );
	    %let _byvar=%scan(&byvars, &j);
	    %if &j = 1 %then %do;
            %let stringbyvars = %scan(&byvars, 1);
		%end;
		%else %do;
            %let stringbyvars = &stringbyvars , &_byvar;
		%end;     
        %let j=%eval(&j+1);
    %end;

	%if &stringbyvars ne %then %do;
		proc sql;
		     create table _byvarsdata as
		     select distinct &stringbyvars
		     from &indata;
		quit;

		proc sql;
		   create table _tmpoutparms as
		   select *
		   from  _byvarsdata cross join &inparms;
		run;
	%end;
	%else %do;
		data _tmpoutparms;
	    	set &inparms;
		run;
	%end;

	title 'Hyperparameter Sets for Tuning';
    title2 'Upto the first 100 sets';   
    proc print data=_tmpoutparms(obs=100);
	run;
    title ''; 
    title2 '';
	data &outparms;
	    set _tmpoutparms;
	run;

	data _null_;
        set &inparms nobs = n;
	 call symputx('nid',n); 
    run;
    
    data &outdata;
        set &indata;
  	    do _id_ = 1 to &nid;  
    		output;
  		end;
	run;
	proc delete data=_tmpoutparms(gennum=all);
    run;
%mend MakeTuningDataSets;

%macro SelectBestRnnModel(in_outtnfstat = mycas.outtnfstat,
                       in_outtnfopt = mycas.outtnfopt,
                       in_scalardata = mycas.autotunetable,
					   in_outtnf = mycas.outtnf,
                       selection_region = FIT, 
					   selection_stat = ptvlderror,
					   byvars = , 
					   best_model_parameter = best_model_parameter,
                       best_outtnfstat = best_outtnfstat,
                       best_outtnfopt = best_outtnfopt,
					   best_outtnf = best_outtnf);

	%let j =1;
	%let stringbyvars =;
	%let comparebyvars =;
    %do %while(%scan(&byvars, &j) ne );
	    %let _byvar=%scan(&byvars, &j);
	    %if &j = 1 %then %do;
            %let stringbyvars = &_byvar ;
			%let comparebyvars = a.&_byvar = b.&_byvar ; 
		%end;
		%else %do;
            %let stringbyvars = &stringbyvars , &_byvar ;
			%let comparebyvars = &comparebyvars and a.&_byvar = b.&_byvar ;
		%end;     
        %let j=%eval(&j+1);
    %end;

    data _outstat;
         set &in_outtnfstat;
	 	if _region_ = "&selection_region" then output;
	 	keep &selection_stat &byvars _id_;
    run;

	proc sql;
	    create table work._temp as 
	    select *, 
	    min(&selection_stat) as _selectedstat
	    from _outstat
		%if &byvars ne %then %do;
	    	group by &stringbyvars
        %end;
		;
	quit;

	proc sql;
	    create table _selected_id(drop=_selectedstat &selection_stat) as 
	    select *
	    from _temp
		where  _selectedstat = &selection_stat; 
	quit;
    /* In order to put both data sets in the same library 
	   It speeds up the calculation in sql */ 
	data _scalardata;
	    set &in_scalardata;
	run;
    proc sql;
	    create table &best_model_parameter as 
	    select distinct b.*
	    from  _selected_id as a, _scalardata as b 
		
		%if &byvars ne %then %do;
			where  a._id_ = b._id_ and &comparebyvars 
	    	order by &stringbyvars;
        %end;
		%else %do;
            where  a._id_ = b._id_; 
		%end;
    quit;

    title 'Hyperparameter values for the BEST RNN Forecasting Model';
    proc print data=&best_model_parameter;
    run;
	title '';

    /* Best outtnfopt */
	data _outtnfopt;
	    set &in_outtnfopt;
	run;
	proc sql;
	    create table &best_outtnfopt as 
	    select distinct b.*
	    from  _selected_id as a, _outtnfopt as b 
		%if &byvars ne %then %do;
			where a._id_ = b._id_ and &comparebyvars
	    	order by &stringbyvars, epoch;
        %end;
        %else %do;
			where a._id_ = b._id_
	    	order by epoch;
        %end; 
    quit;

	/* Best outtnfstat */
	data _outtnfstat;
         set &in_outtnfstat;
	run;
	proc sql;
	    create table &best_outtnfstat as 
	    select distinct b.*
	    from _selected_id as a, _outtnfstat as b 
		%if &byvars ne %then %do;
			where  a._id_ = b._id_ and &comparebyvars 
	    	order by &stringbyvars;
		%end;
        %else %do;
			where a._id_ = b._id_;
        %end;  

    quit;

	/* Best outtnf */
	data _outtnf;
         set &in_outtnf;
	proc sql;
	    create table &best_outtnf as 
	    select distinct b.*
	    from _selected_id as a, _outtnf as b
        %if &byvars ne %then %do; 
			where  a._id_ = b._id_ and &comparebyvars 
	    	order by &stringbyvars;
		%end;
        %else %do;
			where a._id_ = b._id_;
        %end;   
    quit;

	proc delete data=_outstat _temp  _outtnf _outtnfstat _outtnfopt _selected_id(gennum=all);
    run;

%mend SelectBestRnnModel;
	

%macro RnnForecastPlots(in_outtnf=, in_outtnfstat=, in_outtnfopt=, target=, byvars=);
    title 'Optimization History Plot';
    %if &byvars = %then %do;
		data null;
	      	set &in_outtnfstat;
	      	call symputx('optepoch', OPTEPOCH);
	   	run;
	%end;

	proc sgplot data=&in_outtnfopt;
	    %if &byvars ne %then %do;
	    	by &byvars; 
		%end;
     	series x=epoch y=trnerror/ LegendLabel="Train Error"  
           	lineattrs=(color=green) markers markerattrs=(color=green symbol=diamond size=7);
     	series x=epoch y=vlderror/ LegendLabel="Validation Error"  
           lineattrs=(color=red) markers markerattrs=(color=red size=7);
		%if &byvars = %then %do;
	    	refline  &optepoch  / axis=x;
	    %end;
     	yaxis label="Error"; 
	run;
    title 'Forecast Plot'; 
	proc sgplot data=&in_outtnf;
	  %if &byvars ne %then %do;
	    	by &byvars; 
	  %end; 
	  series x=date y=TargetSeries/ legendlabel="Actual Value" name="actual" 
	         lineattrs=(color=green) markers markerattrs=(color=green size=6);
	  series x=date y=forecast/ LegendLabel="Forecast Value"   name="forecast"
	         lineattrs=(color=red) markers markerattrs=(color=red size=6 symbol=diamond);
	  *xaxis values=('01jan49'd to '01dec61'd by month);
	  *refline  '01dec59'd   '01dec60'd/ axis=x;
	  keylegend "actual" "forecast";
	  yaxis label="&target"; 
	run; 
	title '';
%mend RnnForecastPlots;

