*define a standard SAS libname pointing to the data source;
libname time '.\SAS and CSV Datasets';

*create a CAS session;
cas mycas;

*define a CAS SAS libname using the CAS session created above;
libname mycas sasioca sessref = mycas;

/**** 11.3 Neural network models ****/
/**** Example: sunspots ****/
/**** https://otexts.com/fpp2/nnetar.html ***/

data mycas.fpp2_sunspotarea;
	set time.fpp2_sunspotarea;
run;

/* creating lag variables and extending the time horizon */
proc tsmodel data = mycas.fpp2_sunspotarea outarray= mycas.test;
	id year interval = year start='01jan1875'd end='30dec2025'd setmiss=missing;
	outarrays var1-var10;
	var value;
	submit;
		do i = 1 to dim(value);
			if i>1 then var1[i]=value[i-1];
			if i>2 then var2[i]=value[i-2];
			if i>3 then var3[i]=value[i-3];
			if i>4 then var4[i]=value[i-4];
			if i>5 then var5[i]=value[i-5];
			if i>6 then var6[i]=value[i-6];
			if i>7 then var7[i]=value[i-7];
			if i>8 then var8[i]=value[i-8];
			if i>9 then var9[i]=value[i-9];
			if i>10 then var10[i]=value[i-10];
		end;
	endsubmit;
run;

/* creating training portion */
data mycas.train;
	set mycas.test;
	if year(year)<=2015 then output;
run;

/* running the neural net procedure with 6 nodes in the hidden layer */
/* the score code is generated in a sas file. The code will be used to score new data afterwards */
proc nnet data=mycas.train;
	input var1-var10;
	target value /level=int;
	hidden 6;
	train outmodel=mycas.nnetmodel seed=12345;
	code file='.\sas code';
run;

/* The score code is used to predict the future. Lagged variables are computed using the retain statement */
data mycas.fit;
	set mycas.test;
	retain p_value copyvar1-copyvar10;
	if var10=. then var10 = copyvar9;
	if var9=. then var9 = copyvar8;
	if var8=. then var8 = copyvar7;
	if var7=. then var7 = copyvar6;
	if var6=. then var6 = copyvar5;
	if var5=. then var5 = copyvar4;		
	if var4=. then var4 = copyvar3;
	if var3=. then var3 = copyvar2;
	if var2=. then var2 = copyvar1;
	if var1=. then var1 = p_value;
	
	/* score code is put as below */
	%include '.\sas code';
	
	/* a copy of the current observation is saved to create lagged variables in the next iteration */
	copyvar1 = var1;
	copyvar2 = var2;
	copyvar3 = var3;
	copyvar4 = var4;
	copyvar5 = var5;
	copyvar6 = var6;
	copyvar7 = var7;
	copyvar8 = var8;
	copyvar9 = var9;
	copyvar10 = var10;
run;