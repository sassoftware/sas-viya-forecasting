/* 
   Example 1m 
   Data Set: sashelp.air
   Target variable: air
   Number of models: 243 for each RNN type
   Total number of models: 729 = 243 x 3(RNN, LSTM, GRU) 
*/


data mycas.in_hyperpara_set;
input ninput nlayer nneuron learningRate algorithm $10. rnntype $5.;
cards;
6  3 20  0.1    ADAM     RNN
12 4 30  0.01   VANILLA  LSTM
18 5 40  0.001  MOMENTUM GRU
;
;
run;
title 'Hyperparameters for tuning'; 
proc print data=mycas.in_hyperpara_set;
run;

%MakeHyperParameterDataSet(indata=mycas.in_hyperpara_set,
 					       outdata=mycas.inscalar_data_set);
title 'All the combination sets of hyperparameter values for tuning'; 
proc print data=mycas.inscalar_data_set;
run;
*options mprint;
data mycas.air;
    set sashelp.air;
run;
%MakeTuningDataSets(indata=mycas.air, inparms=mycas.inscalar_data_set, 
                    outparms=mycas.inscalardata, outdata=mycas.traindata);


%let target = air;
proc tsmodel data=mycas.traindata  
             outlog=mycas.outlog 
             errorStop = Yes 
             inscalar=mycas.inscalardata 
             outobj=( of= mycas.outtnf(replace=YES) 
                      ofs= mycas.outtnfstat(replace=YES)
                      ofopt= mycas.outtnfopt(replace=YES)); 
id date interval=month;
by _id_;
var &target;
inscalar ninput nlayer nneuron learningRate algorithm rnntype;
require tnf;
submit;
    	declare object f(TNF);
    	declare object of(OUTTNF);
    	declare object ofs(OUTTNFSTAT);
    	declare object ofopt(OUTTNFOPT);
 	    rc = f.Initialize();
    	rc = f.setTarget(&target);
 	    rc = f.SetOption(  
			'RNNTYPE', rnntype, 
			'NINPUT', ninput, 
			'NLAYER', nlayer,
			'NNEURONH',nneuron,
			'NHOLDOUT', 12,
			'LEAD', 12, 
            'SEED', 12345);
    	rc = f.SetOptimizer(
			'ALGORITHM', algorithm,
			'LEARNINGRATE', learningRate,
			'BETA1', 0.8,
			'BETA2', 0.9,
			'LEARNINGPOLICY', 'STEP',
			'STEPSIZE', 5,
			'GAMMA', 0.5,
			'MINIBATCHSIZE', 8,
			'WARMUPEPOCHS',20,
			'MAXEPOCHS', 100);
    
    rc = f.Run();if rc < 0 then stop;
    rc = of.Collect(f);if rc < 0 then stop;
    rc = ofs.Collect(f);if rc < 0 then stop;
    rc = ofopt.Collect(f);if rc < 0 then stop;  
endsubmit;
quit;

%SelectBestRnnModel(in_outtnfstat = mycas.outtnfstat,
                      in_outtnfopt = mycas.outtnfopt,
                      in_scalardata = mycas.inscalardata,
					  in_outtnf = mycas.outtnf,
                      selection_region = FIT, 
					  selection_stat = ptvlderror,
					  best_model_parameter = best_model_parameter,
                      best_outtnfstat = best_outtnfstat,
                      best_outtnfopt = best_outtnfopt,
					  best_outtnf = best_outtnf);

%RnnForecastPlots(in_outtnf=work.best_outtnf,
                  in_outtnfstat=work.best_outtnfstat,
                  in_outtnfopt=work.best_outtnfopt, 
                  target= &target
                  );

proc print data=best_model_parameter;
run;
proc print data=best_outtnfstat label;
  var OPTEPOCH TRNERROR VLDERROR PTVLDERROR;
run;
