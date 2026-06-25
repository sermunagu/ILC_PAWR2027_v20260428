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
measfilename = ['experiment' filenamedate '_xy'];
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
GVGconfig.maxPopulation = 300;   % Maximum population size.
%GVGconfig.evaluationtype = 'BIC'; % 'BIC' or 'maxPopulation'
GVGconfig.evaluationtype = 'maxPopulation'; % 'BIC' or 'maxPopulation'
GVGconfig.mutationrate = 0.7;    % Mutation rate.
GVGconfig.crossoverrate = 0.5;   % Crossover rate.
GVGconfig.verbosity = 3;         % Verbosity level (0: none, 1: basic, 2: detailed).
GVGconfig.showPlots = true;      % Display plots during execution.
GVGconfig.validate = true;       % Validate each generation against `y`.
GVGconfig.validatengen = 300;     % Validate every `validatengen` generations.
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
GVGconfig.inittype = 'GMP';

% Model configurations
% MP
GVGconfig.Pmp=13; GVGconfig.Mmp=5;
% FV
GVGconfig.Pfv=13; GVGconfig.Mfv=5;
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
dpd = struct('modeltype', {}, ...
             'rManager', {}, ...
             'nmseid', {}, ...
             'nmseval', {}, ...
             'yvalmod', {});

% %% Launch GVG
% [rManagerout,~,nmseidout,genval,nmsevalout,rManagerv,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% dpd(end+1).modeltype = sprintf('GVG (alpha=%.5f, lambda=%.1e)', ...
%                                 GVGconfig.alpha, GVGconfig.lambda);
% dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;
% 
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
% savefig(['..' filesep 'results\' measfilename  '_GVG_NMSE_evolution.fig']);
% % Validation NMSE evolution
% figure,
% plot(nmseidout,'b','linewidth',2); hold on
% plot(genval,nmsevalout,'ro-')
% grid on;xlabel('Generation'), ylabel('NMSE (dB)'), legend('Identification','Validation');
% savefig(['..' filesep 'results' filesep measfilename  '_GVG_id_val.fig']);
% 
% GVGconfig.lambda = 1e-5;
% GVGconfig.alpha = 1;
% [rManagerout,~,nmseidout,genval,nmsevalout,rManagerv,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% [rManagerout,~,nmseidout,genval,nmsevalout,rManagerv,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% dpd(end+1).modeltype = sprintf('GVG (alpha=%.5f, lambda=%.1e)', ...
%                                 GVGconfig.alpha, GVGconfig.lambda);
% dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;
% 
% 


%% GVG Benchmark
% Run a single generation using a fixed model structure (e.g., MP, GMP).
% Equivalent to benchmarking that model without structural evolution.
GVGconfig.DOMPtype = 'POMP';
GVGconfig.lambda = 1e-5;
GVGconfig.alpha = 1;
GVGconfig.ngenerations = 1;    % Number of generations to run.
GVGconfig.validatengen = 1;    % Validate every generation.

GVGconfig.inittype = 'MPo';
GVGconfig.Pmp=13; GVGconfig.Mmp=0;
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
dpd(end+1).modeltype = sprintf('P 13th M=0 (alpha=%.5f, lambda=%.1e)', ...
                                GVGconfig.alpha, GVGconfig.lambda);
dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;


GVGconfig.inittype = 'MPo';
GVGconfig.Pmp=13; GVGconfig.Mmp=5;
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
dpd(end+1).modeltype = sprintf('MP 13th M=5 (alpha=%.5f, lambda=%.1e)', ...
                                GVGconfig.alpha, GVGconfig.lambda);
dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;


GVGconfig.inittype = 'GMP';
GVGconfig.lambda = 1e-5;
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
dpd(end+1).modeltype = sprintf('GMP (alpha=%.5f, lambda=%.1e)', ...
                                GVGconfig.alpha, GVGconfig.lambda);
dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;

GVGconfig.inittype = 'GMP';
GVGconfig.lambda = 0;
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
dpd(end+1).modeltype = sprintf('GMP (alpha=%.5f, lambda=%.1e)', ...
                                GVGconfig.alpha, GVGconfig.lambda);
dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;


% GVGconfig.inittype = 'FV';
% [rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% dpd(end+1).modeltype = sprintf('FV (alpha=%.5f, lambda=%.1e)', ...
%                                 GVGconfig.alpha, GVGconfig.lambda);
% dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;
% 
% GVGconfig.inittype = 'CVS';
% [rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% dpd(end+1).modeltype = sprintf('CVS (alpha=%.5f, lambda=%.1e)', ...
%                                 GVGconfig.alpha, GVGconfig.lambda);
% dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;
% 
% GVGconfig.inittype = 'DDR';
% [rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% dpd(end+1).modeltype = sprintf('DDR (alpha=%.5f, lambda=%.1e)', ...
%                                 GVGconfig.alpha, GVGconfig.lambda);
% dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;


GVGconfig.inittype = 'compositeall';
GVGconfig.lambda = 1e-5;
[rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
dpd(end+1).modeltype = sprintf('Composite (alpha=%.5f, lambda=%.1e)', ...
                                GVGconfig.alpha, GVGconfig.lambda);
dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;

% GVGconfig.alpha = 1;
% GVGconfig.lambda = 0;
% GVGconfig.DOMPtype  = 'POMP';
% GVGconfig.inittype = 'compositeall';
% [rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% dpd(end+1).modeltype = sprintf('Composite (alpha=%.5f, lambda=%.1e)', ...
%                                 GVGconfig.alpha, GVGconfig.lambda);
% dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;
% 
% GVGconfig.alpha = 1-1e-5;
% GVGconfig.lambda = 1e-5;
% GVGconfig.DOMPtype  = 'POMP';
% GVGconfig.inittype = 'compositeall';
% [rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% dpd(end+1).modeltype = sprintf('Composite (alpha=%.5f, lambda=%.1e)', ...
%                                 GVGconfig.alpha, GVGconfig.lambda);
% dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;
% 
% 
% GVGconfig.alpha = 1-1e-5;
% GVGconfig.lambda = 1e-4;
% GVGconfig.DOMPtype  = 'POMP';
% GVGconfig.inittype = 'compositeall';
% [rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% dpd(end+1).modeltype = sprintf('Composite (alpha=%.5f, lambda=%.1e)', ...
%                                 GVGconfig.alpha, GVGconfig.lambda);
% dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;
% 
% GVGconfig.alpha = 1-1e-5;
% GVGconfig.lambda = 1e-3;
% GVGconfig.DOMPtype  = 'POMP';
% GVGconfig.inittype = 'compositeall';
% [rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% dpd(end+1).modeltype = sprintf('Composite (alpha=%.5f, lambda=%.1e)', ...
%                                 GVGconfig.alpha, GVGconfig.lambda);
% dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;
% 
% 
% 
% GVGconfig.alpha = 1-1e-4;
% GVGconfig.lambda = 1e-5;
% GVGconfig.DOMPtype  = 'POMP';
% GVGconfig.inittype = 'compositeall';
% [rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% dpd(end+1).modeltype = sprintf('Composite (alpha=%.5f, lambda=%.1e)', ...
%                                 GVGconfig.alpha, GVGconfig.lambda);
% dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;
% 
% 
% 
% GVGconfig.alpha = 1-1e-4;
% GVGconfig.lambda = 1e-4;
% GVGconfig.DOMPtype  = 'POMP';
% GVGconfig.inittype = 'compositeall';
% [rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% dpd(end+1).modeltype = sprintf('Composite (alpha=%.5f, lambda=%.1e)', ...
%                                 GVGconfig.alpha, GVGconfig.lambda);
% dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;
% 
% 
% 
% GVGconfig.alpha = 1-1e-4;
% GVGconfig.lambda = 1e-3;
% GVGconfig.DOMPtype  = 'POMP';
% GVGconfig.inittype = 'compositeall';
% [rManagerout,~,nmseidout,~,nmsevalout,~,yvalmodout] = GVGgenerateModel(x(nid),y(nid),x,y,GVGconfig);
% dpd(end+1).modeltype = sprintf('Composite (alpha=%.5f, lambda=%.1e)', ...
%                                 GVGconfig.alpha, GVGconfig.lambda);
% dpd(end).rManager = rManagerout;dpd(end).nmseid   = nmseidout;dpd(end).nmseval  = nmsevalout;dpd(end).yvalmod  = yvalmodout;
% 



%% Figures
%% Figures
% NMSE representation
baseColors = {'r','g','y','m','c','k','b'};
lineStyles = {'-','--',':','-.'};

figure; hold on

for i = 1:numel(dpd)

    y = dpd(i).rManager.nmsev;
    numcoeff(i)      = dpd(i).rManager.nopt;
    nmseidbench(i)   = dpd(i).rManager.nmse;
    nmsevalbench(i)  = dpd(i).nmseval;

    color = baseColors{mod(i-1, numel(baseColors)) + 1};
    style = lineStyles{mod(i-1, numel(lineStyles)) + 1};

    plot(1:numel(y), y, [color style], 'LineWidth', 2);

end

legend({dpd.modeltype}, 'Location','best')

xlabel('Number of coefficients');
ylabel('NMSE (dB)');
grid on;

savefig(['..' filesep 'results' filesep measfilename ...
    '_comparative_NMSE_evolution.fig']);

% Performance table
%% Build performance table from dpd

nModels = numel(dpd);

Model   = strings(nModels,1);
Ncoeff  = zeros(nModels,1);
NMSEid  = zeros(nModels,1);
NMSEval = zeros(nModels,1);

for i = 1:nModels

    Model(i) = string(dpd(i).modeltype);

    % Last number of coefficients (can be scalar or vector)
    nopt_i = dpd(i).rManager.nopt;
    Ncoeff(i) = nopt_i(end);

    % Identification NMSE (can be scalar or vector)
    nmse_id_i = dpd(i).rManager.nmse;
    NMSEid(i) = nmse_id_i(end);

    % Validation NMSE (can be scalar or vector)
    nmse_val_i = dpd(i).nmseval;
    NMSEVal(i) = nmse_val_i(end);

end

T = table(Model, Ncoeff, NMSEid, NMSEVal', ...
          'VariableNames', {'Model','Ncoeff','NMSEid','NMSEval'});
Tcell = table2cell(T);  % Convert all data to cell array

fig = uifigure;

uitable(fig, ...
    'Data', T, ...
    'ColumnName', T.Properties.VariableNames, ...
    'RowName', T.Properties.RowNames, ...
    'Units','normalized', ...
    'Position',[0 0 1 1]);

% Save figure
savefig(fig, ['..' filesep 'results' filesep measfilename ...
    '_comparative_table.fig']);



%% Save results
clear x y nid T ans igen;
save(['..' filesep 'results' filesep measfilename '_execution.mat'],'dpd');
