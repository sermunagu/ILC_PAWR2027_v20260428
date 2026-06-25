%% main_GVG.m
%--------------------------------------------------------------------------
% Script Name : main_GVG
% Version     : 3.0
% Author      : Juan A. Becerra
% Date        : 2026-01-07
%
% Description:
% This script launches a benchmark of the Genetic-based Volterra subspace 
% Generator (GVG). 
%

%clear all; close all; clc;
addpath('GVG');

% Seed configuration for reproducibility
seed = 1004;
rng(seed);

%% Load measurement
% x and y are the input/output of the system to model with GVG. perc is the
% percentage of samples used for modeling
%measfilename = 'experiment20251114T132951_RFSoC_Doherty_100MHz'; 
%measfilename = 'experiment20251202T090149_RFSoC_Doherty_100MHz'; 
measfilename = ['experiment' filenamedate '_RFSoC_Doherty_100MHz']; 
load(['..' filesep 'results' filesep measfilename '.mat']); x = x(:); y = y(:);
x = x - mean(x); y = y - mean(y); perc = 0.04;

nid = sel_indices(x, y, perc);
fprintf('Number of samples for modeling %d sa. For validation: %d sa.\n', floor(length(x)*perc), length(x));
fprintf('If BIC is chosen, the stopping criterion is decrement of NMSE of %4.6f\n', -10/length(nid)*log10(2*length(nid)));

% GVG configuration
GVGconfig.Qpmax = 50;            % Maximum causal memory.
GVGconfig.Qnmax = 50;            % Maximum non-causal memory.
GVGconfig.Pmax = 13;             % Maximum nonlinear order.
GVGconfig.ngenerations = 300;    % Number of generations to run.
GVGconfig.maxPopulation = 100;   % Maximum population size.
%GVGconfig.evaluationtype = 'BIC'; % 'BIC' or 'maxPopulation'
GVGconfig.evaluationtype = 'maxPopulation'; % 'BIC' or 'maxPopulation'
GVGconfig.mutationrate = 0.7;    % Mutation rate.
GVGconfig.crossoverrate = 0.5;   % Crossover rate.
GVGconfig.verbosity = 3;         % Verbosity level (0: none, 1: basic, 2: detailed).
GVGconfig.showPlots = true;      % Display plots during execution.
GVGconfig.validate = true;       % Validate each generation against `y`.
GVGconfig.validatengen = 10;     % Validate every `validatengen` generations.
GVGconfig.storePopulation = false;  % Stores the population in every generation (to avoid the generation of heavy output files)
GVGconfig.regPopulation = [];


%GVGconfig.DOMPtype = 'DOMP';
%GVGconfig.lambda = 0;
%GVGconfig.alpha = 1;
GVGconfig.DOMPtype = 'POMP';
GVGconfig.alpha = 1-1e-4; 
GVGconfig.lambda = 1e-5;  

% GVG initialization strategy: 
% 'default' lets GVG find regressors from scratch (default behavior).
% 'MP', 'GMP', 'FV', or 'CVS' use prior models to speed up convergence.
%GVGconfig.inittype = 'default';
%GVGconfig.inittype = 'MP';
%GVGconfig.inittype = 'GMP';
%GVGconfig.inittype = 'FV';
%GVGconfig.inittype = 'CVS';
GVGconfig.inittype = 'compositeall';

% Model configurations
% MP
GVGconfig.Pmp=13; GVGconfig.Mmp=5; 
% FV
GVGconfig.Pfv=13; GVGconfig.Mfv=3; 
% CVS
GVGconfig.Pcvs=13; GVGconfig.Mcvs=3; 
% DDR
GVGconfig.Pddr=13; GVGconfig.Mddr=10; 
% GMP
Pgmp = 13;                
Lgmp = 10;
Mgmp = 2;
GVGconfig.Ka = [0:(Pgmp-1)];
GVGconfig.La = Lgmp*ones(size(GVGconfig.Ka));
GVGconfig.Kb = [1:(Pgmp-1)];
GVGconfig.Lb = Lgmp*ones(size(GVGconfig.Kb));
GVGconfig.Mb = Mgmp*ones(size(GVGconfig.Kb));
GVGconfig.Kc = [1:(Pgmp-1)];
GVGconfig.Lc = Lgmp*ones(size(GVGconfig.Kc));
GVGconfig.Mc = Mgmp*ones(size(GVGconfig.Kc));

%% Variables for storing the benchmark
rManager = {};
nmseid = {};
nmseval = {};
yvalmod = {};
modeltype = {};

% %% Launch GVG
% [rManagerout,~,nmseidout,genval,nmsevalout,rManagerv,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% modeltype = [modeltype, {'GVG'}]; rManager = [rManager, rManagerout]; nmseid = [nmseid, nmseidout]; nmseval = [nmseval, nmsevalout]; yvalmod = [yvalmod, yvalmodout];
% % 
% % %% Figures
% % NMSE evolution with generations
% figure,
% for igen=1:length(rManagerv)-1
%     plot(1:length(rManagerv{igen}.nmsev),rManagerv{igen}.nmsev,'Color', [0.5 0.5 0.5]); hold on
%     plot(rManagerv{igen}.nopt,rManagerv{igen}.nmsev(rManagerv{igen}.nopt),'o','Color', [0.5 0.5 0.5]);
% end
% plot(1:length(rManagerv{end}.nmsev),rManagerv{end}.nmsev,'b','linewidth',2); hold on
% plot(rManagerv{end}.nopt,rManagerv{end}.nmsev(rManagerv{end}.nopt),'b','Color', [0.5 0.5 0.5],'linewidth',2);
% xlabel('Number of coefficients'); ylabel('NMSE (dB)');  grid on;
% savefig(['..' filesep 'results\' measfilename '_' GVGconfig.evaluationtype '_GVG_NMSE_evolution.fig']);
% % Validation NMSE evolution
% figure,
% plot(nmseidout,'b','linewidth',2); hold on
% plot(genval,nmsevalout,'ro-')
% grid on;xlabel('Generation'), ylabel('NMSE (dB)'), legend('Identification','Validation');
% savefig(['..' filesep 'results' filesep measfilename '_' GVGconfig.evaluationtype '_GVG_id_val.fig']);

%% GVG Benchmark
% Run a single generation using a fixed model structure (e.g., MP, GMP).
% Equivalent to benchmarking that model without structural evolution.
GVGconfig.DOMPtype = 'DOMP';
GVGconfig.lambda = 0;
GVGconfig.alpha = 1;
GVGconfig.ngenerations = 1;    % Number of generations to run.
GVGconfig.validatengen = 1;    % Validate every generation.
GVGconfig.inittype = 'MPo';
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
modeltype = [modeltype, {'MP'}]; rManager = [rManager, rManagerout]; nmseid = [nmseid, nmseidout]; nmseval = [nmseval, nmsevalout]; yvalmod = [yvalmod, yvalmodout];


GVGconfig.inittype = 'GMP'; 
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
modeltype = [modeltype, {'GMP'}]; rManager = [rManager, rManagerout]; nmseid = [nmseid, nmseidout]; nmseval = [nmseval, nmsevalout]; yvalmod = [yvalmod, yvalmodout];

%GVGconfig.inittype = 'FV'; 
%[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
%GVGconfig.inittype = 'CVS'; 
%[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);

GVGconfig.inittype = 'DDR'; 
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
modeltype = [modeltype, {'DDR'}]; rManager = [rManager, rManagerout]; nmseid = [nmseid, nmseidout]; nmseval = [nmseval, nmsevalout]; yvalmod = [yvalmod, yvalmodout];

GVGconfig.inittype = 'compositeall'; 
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
modeltype = [modeltype, {'Composite DOMP'}]; rManager = [rManager, rManagerout]; nmseid = [nmseid, nmseidout]; nmseval = [nmseval, nmsevalout]; yvalmod = [yvalmod, yvalmodout];

% pomp
GVGconfig.alpha = 1; 
GVGconfig.lambda = 0;  
GVGconfig.DOMPtype  = 'POMP';
GVGconfig.inittype = 'compositeall'; 
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
modeltype = [modeltype, {sprintf('POMP (alpha=%.5f, lambda=%.1e)', GVGconfig.alpha, GVGconfig.lambda)}]; rManager = [rManager, rManagerout]; nmseid = [nmseid, nmseidout]; nmseval = [nmseval, nmsevalout]; yvalmod = [yvalmod, yvalmodout];

GVGconfig.alpha = 1-1e-5; 
GVGconfig.lambda = 1e-5;  
GVGconfig.DOMPtype  = 'POMP';
GVGconfig.inittype = 'compositeall'; 
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
modeltype = [modeltype, {sprintf('POMP (alpha=%.5f, lambda=%.1e)', GVGconfig.alpha, GVGconfig.lambda)}]; rManager = [rManager, rManagerout]; nmseid = [nmseid, nmseidout]; nmseval = [nmseval, nmsevalout]; yvalmod = [yvalmod, yvalmodout];

GVGconfig.alpha = 1-1e-5; 
GVGconfig.lambda = 1e-4;  
GVGconfig.DOMPtype  = 'POMP';
GVGconfig.inittype = 'compositeall'; 
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
modeltype = [modeltype, {sprintf('POMP (alpha=%.5f, lambda=%.1e)', GVGconfig.alpha, GVGconfig.lambda)}]; rManager = [rManager, rManagerout]; nmseid = [nmseid, nmseidout]; nmseval = [nmseval, nmsevalout]; yvalmod = [yvalmod, yvalmodout];

GVGconfig.alpha = 1-1e-5; 
GVGconfig.lambda = 1e-3;  
GVGconfig.DOMPtype  = 'POMP';
GVGconfig.inittype = 'compositeall'; 
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
modeltype = [modeltype, {sprintf('POMP (alpha=%.5f, lambda=%.1e)', GVGconfig.alpha, GVGconfig.lambda)}]; rManager = [rManager, rManagerout]; nmseid = [nmseid, nmseidout]; nmseval = [nmseval, nmsevalout]; yvalmod = [yvalmod, yvalmodout];


GVGconfig.alpha = 1-1e-4; 
GVGconfig.lambda = 1e-5;  
GVGconfig.DOMPtype  = 'POMP';
GVGconfig.inittype = 'compositeall'; 
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
modeltype = [modeltype, {sprintf('POMP (alpha=%.5f, lambda=%.1e)', GVGconfig.alpha, GVGconfig.lambda)}]; rManager = [rManager, rManagerout]; nmseid = [nmseid, nmseidout]; nmseval = [nmseval, nmsevalout]; yvalmod = [yvalmod, yvalmodout];

GVGconfig.alpha = 1-1e-4; 
GVGconfig.lambda = 1e-4;  
GVGconfig.DOMPtype  = 'POMP';
GVGconfig.inittype = 'compositeall'; 
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
modeltype = [modeltype, {sprintf('POMP (alpha=%.5f, lambda=%.1e)', GVGconfig.alpha, GVGconfig.lambda)}]; rManager = [rManager, rManagerout]; nmseid = [nmseid, nmseidout]; nmseval = [nmseval, nmsevalout]; yvalmod = [yvalmod, yvalmodout];

GVGconfig.alpha = 1-1e-4; 
GVGconfig.lambda = 1e-3;  
GVGconfig.DOMPtype  = 'POMP';
GVGconfig.inittype = 'compositeall'; 
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
modeltype = [modeltype, {sprintf('POMP (alpha=%.5f, lambda=%.1e)', GVGconfig.alpha, GVGconfig.lambda)}]; rManager = [rManager, rManagerout]; nmseid = [nmseid, nmseidout]; nmseval = [nmseval, nmsevalout]; yvalmod = [yvalmod, yvalmodout];


%% Figures
%% Figures
% NMSE representation
baseColors = {'r','g','y','m','c','k','b'};
lineStyles = {'-','--',':','-.'};

figure; hold on
for i = 1:numel(rManager)
    y = rManager(i).nmsev;
    numcoeff(i) = rManager(i).nopt;
    nmseidbench(i) = rManager(i).nmse;
    nmsevalbench(i) = nmseval(i);
    
    color = baseColors{mod(i-1, numel(baseColors)) + 1};
    style = lineStyles{mod(i-1, numel(lineStyles)) + 1};

    plot(1:numel(y), y, [color style], 'LineWidth', 2);
end

legend(modeltype, 'Location','best')

% figure,
% plot(1:length(rManagerMP.nmsev), rManagerMP.nmsev,'r','linewidth',2); hold on
% plot(1:length(rManagerGMP.nmsev), rManagerGMP.nmsev,'g','linewidth',2); hold on
% plot(1:length(rManagerFV.nmsev),  rManagerFV.nmsev, 'y','linewidth',2); hold on
% plot(1:length(rManagerCVS.nmsev), rManagerCVS.nmsev,'m','linewidth',2); hold on
% plot(1:length(rManagerDDR.nmsev), rManagerDDR.nmsev,'c','linewidth',2); hold on
% plot(1:length(rManagercompositeall.nmsev), rManagercompositeall.nmsev,'k','linewidth',2); hold on
% 
% plot(1:length(rManagerPOMP1.nmsev), rManagerPOMP1.nmsev,'b--','linewidth',2); hold on
% plot(1:length(rManagerPOMP2.nmsev), rManagerPOMP2.nmsev,'r--','linewidth',2); hold on
% plot(1:length(rManagerPOMP3.nmsev), rManagerPOMP3.nmsev,'g--','linewidth',2); hold on
% plot(1:length(rManagerPOMP4.nmsev), rManagerPOMP4.nmsev,'k--','linewidth',2); hold on
% 
% legend( ...
%     'MP','GMP','FV','CVS','DDR','composite', ...
%     'POMP1','POMP2','POMP3','POMP4', ...
%     'Location','best' ...
% );

xlabel('Number of coefficients');
ylabel('NMSE (dB)');
grid on;

savefig(['..' filesep 'results' filesep measfilename '_' ...
         GVGconfig.evaluationtype '_comparative_NMSE_evolution.fig']);

% Identification and validation NMSEs table
% modeltype = { ...
%     'MP','GMP','FV','CVS','DDR','composite', ...
%     'POMP1','POMP2','POMP3','POMP4' ...
% };
% 
% numcoeff = { ...
%     rManagerMP.nopt, ...
%     rManagerGMP.nopt, ...
%     rManagerFV.nopt, ...
%     rManagerCVS.nopt, ...
%     rManagerDDR.nopt, ...
%     rManagercompositeall.nopt, ...
%     rManagerPOMP1.nopt, ...
%     rManagerPOMP2.nopt, ...
%     rManagerPOMP3.nopt, ...
%     rManagerPOMP4.nopt ...
% };
% 
% nmseidbench = { ...
%     rManagerMP.nmse, ...
%     rManagerGMP.nmse, ...
%     rManagerFV.nmse, ...
%     rManagerCVS.nmse, ...
%     rManagerDDR.nmse, ...
%     rManagercompositeall.nmse, ...
%     rManagerPOMP1.nmse, ...
%     rManagerPOMP2.nmse, ...
%     rManagerPOMP3.nmse, ...
%     rManagerPOMP4.nmse ...
% };
% 
% nmsevalbench = { ...
%     nmsevalvMP, ...
%     nmsevalvGMP, ...
%     nmsevalvFV, ...
%     nmsevalvCVS, ...
%     nmsevalvDDR, ...
%     nmsevalvcompositeall, ...
%     nmsevalvPOMP1, ...
%     nmsevalvPOMP2, ...
%     nmsevalvPOMP3, ...
%     nmsevalvPOMP4 ...
% };
%modeltype = {'GVG','MP','GMP','DDR','composite','POMP1','POMP2','POMP3','POMP4','POMP5','POMP6','POMP7'}

nmsevaGVG = nmsevalbench(1);
nmsevalbench(1) = [];
nmsevalbench = [{nmsevaGVG{end}(end)} nmsevalbench];

T = table( ...
    string(modeltype)', numcoeff', nmseidbench', nmsevalbench', ...
    'VariableNames', {'Model','Ncoeff','NMSEid','NMSEval'} ...
);

Tcell = table2cell(T);  % convierte todos los datos a cell

figure,
uitable('Data', Tcell, ...
        'ColumnName', T.Properties.VariableNames, ...
        'RowName', T.Properties.RowNames, ...
        'Units','Normalized', ...
        'Position',[0 0 1 1]);

save(['..' filesep 'results' filesep measfilename '_' ...
         GVGconfig.evaluationtype '_comparative_table'],'Tcell');

%% Save results
clear x y nid T ans igen;
save(['..' filesep 'results' filesep measfilename '_' GVGconfig.evaluationtype '_execution'])