classdef regressorManager < matlab.mixin.Copyable
%classdef regressorManager < handle
    properties
        % Genetic algorithm properties
        maxPopulation  % Maximum allowed population size.
        crossoverrate  % Crossover rate.
        mutationrate   % Mutation rate for genetic diversity.
        initgen        %%% Indicates it is the first generation.
        % Generation estructure:
        regPopulation  % Regressors vector
        x              % Input data.
        y              % Target output values.
        n              % Time index.
        Qpmax          % Maximum noncausal memory.
        Qnmax          % Maximum causal memory.
        Pmax           % Maximum nonlinear order.
        X              % Regressors matrix.
        yX             % Output in sync with U.
        s              % Support set.
        Rmat           % Regressors matrix in text format.
        nmse           % Normalized Mean Squared Error metric of BIC.
        nopt           % Optimum number of regressors (BIC).
        h           % Model coefficients
        nmsev          % NMSEv
        % Output config:
        verbosity      % Level of output detail.
        showPlots      % Toggle for plotting results.
        inittype       % itilization type
        evaluationtype
        DOMPtype
        lambda
        alpha
        %%% Changes for generalizing the model initialization
        Ka             % GMP model setting
        La
        Kb
        Lb
        Mb
        Kc
        Lc
        Mc
        Pfv            % FV model setting
        Mfv
        Pcvs           % CVS model setting
        Mcvs
        Pmp            % MP model setting
        Mmp
        Pddr           % DDR model setting
        Mddr
    end
    %%
    methods
        %% regressorManager: builder
        function self = regressorManager(x,y,GVGconfig)
            self.maxPopulation = GVGconfig.maxPopulation;
            self.x = x;
            self.y = y;
            self.Qpmax = GVGconfig.Qpmax;
            self.Qnmax = GVGconfig.Qnmax;
            self.Pmax = GVGconfig.Pmax;
            self.n = (1:length(x))';
            self.regPopulation = GVGconfig.regPopulation;
            self.verbosity = GVGconfig.verbosity;
            self.showPlots = GVGconfig.showPlots;
            self.crossoverrate = GVGconfig.crossoverrate;
            self.mutationrate = GVGconfig.mutationrate;
            self.inittype = GVGconfig.inittype;
            self.evaluationtype = GVGconfig.evaluationtype;
            self.DOMPtype = GVGconfig.DOMPtype;
            self.lambda = GVGconfig.lambda;
            self.alpha = GVGconfig.alpha;
            %%% Changes to generalize the model initialization
            % Models configuration for initialization
            % Full Volterra
            self.Pfv=GVGconfig.Pfv;
            self.Mfv=GVGconfig.Mfv;
            % CVS
            self.Pcvs=GVGconfig.Pcvs;
            self.Mcvs=GVGconfig.Mcvs;
            % MP
            self.Pmp = GVGconfig.Pmp;                
            self.Mmp = GVGconfig.Mmp;
            % DDR
            self.Pddr = GVGconfig.Pddr;                
            self.Mddr = GVGconfig.Mddr;
            %GMP
            self.Ka = GVGconfig.Ka;  
            self.La = GVGconfig.La;  
            self.Kb = GVGconfig.Kb;  
            self.Lb = GVGconfig.Lb;  
            self.Mb = GVGconfig.Mb;  
            self.Kc = GVGconfig.Kc;  
            self.Lc = GVGconfig.Lc;  
            self.Mc = GVGconfig.Mc;  
            %%% Change to be able to distinguish between the GVG
            %%% initialization and the rest of the generations
            self.initgen = 1;
        end
        %% initialization: creates initial population
        %       Create the population with a defined initial set:
        function self = initialization(self)
            %%% Change: Instead of using an external config file,
            %%% initialization model configurations use fields Pmax,
            %%% Qpmax, and Qnmax from the GVG generation structure

            % Default: 3 regressors: R([0],[],[]),R([],[0],[]),R([],[],[0])
            % if strcmp(self.inittype,'default') || strcmp(self.inittype, 'compositeall')
            if strcmp(self.inittype,'default') %%% Change so that the GVG main 
                %%% constituents are not forcely included in the composite models
                self.regPopulation = [self.regPopulation Regressor([0],[],[])];
                self.regPopulation = [self.regPopulation Regressor([],[0],[])];
                self.regPopulation = [self.regPopulation Regressor([],[],[0])];
            end
            % FV model (up to the maximum between Pmax and 13th order).
            % if strcmp(self.inittype,'FV') || strcmp(self.inittype, 'compositeall')
            %%% Change to make more flexible the initialization
            if ~isempty(strfind(self.inittype,'FV')) || strcmp(self.inittype, 'compositeall')
                reg = fv(self.Pfv,self.Mfv);
                for ireg = 1:length(reg.q)
                    X = [];
                    Xconj = [];
                    for iconst = 1:length(reg.q{ireg})
                        if(reg.c{ireg}(iconst))
                            Xconj = [Xconj reg.q{ireg}(iconst)];
                        else
                            X = [X reg.q{ireg}(iconst)];
                        end
                    end
                    self.regPopulation = [self.regPopulation Regressor(X,Xconj,[])];
                    self.regPopulation(ireg).deriveEnvelopeTerms();
                    self.regPopulation(ireg).sortindexes();
                end
            end
            % Complex valued (up to the maximum between Pmax and 5th order).
            % if strcmp(self.inittype,'CVS') || strcmp(self.inittype, 'compositeall')
            %%% Change to make more flexible the initialization
            if ~isempty(strfind(self.inittype,'CVS')) || strcmp(self.inittype, 'compositeall')
                reg = cvs(self.Pcvs,self.Mcvs);
                for ireg = 1:length(reg.q)
                    X = [];
                    Xconj = [];
                    for iconst = 1:length(reg.q{ireg})
                        if(reg.c{ireg}(iconst))
                            Xconj = [Xconj reg.q{ireg}(iconst)];
                        else
                            X = [X reg.q{ireg}(iconst)];
                        end
                    end
                    self.regPopulation = [self.regPopulation Regressor(X,Xconj,[])];
                    self.regPopulation(ireg).deriveEnvelopeTerms();
                    self.regPopulation(ireg).sortindexes();
                end
            end
            % Memory polynomial.
            % if strcmp(self.inittype,'MPo') || strcmp(self.inittype, 'compositeall')
            %%% Change to make more flexible the initialization
            if ~isempty(strfind(self.inittype,'MPo')) || strcmp(self.inittype, 'compositeall')
                P = self.Pmp;                
                M = self.Mmp;
                for k = 0:((P-1)/2)
                    for l = 0:M
                        X = l;
                        Xenv = repmat(l,1,2*k);

                        self.regPopulation = [self.regPopulation Regressor(X,[],Xenv)];
                        self.regPopulation(end).deriveEnvelopeTerms();
                        self.regPopulation(end).sortindexes();
                    end
                end
            end
            % DDR (2nd order dynamics).
            % if strcmp(self.inittype,'DDR') || strcmp(self.inittype, 'compositeall')
            %%% Change to make more flexible the initialization
            if ~isempty(strfind(self.inittype,'DDR')) || strcmp(self.inittype, 'compositeall')
                % 1st
                P = self.Pddr;                
                M = self.Mddr;

                for k = 0:((P-1)/2)
                    for l = 0:M
                        X = l;
                        Xenv = repmat(0,1,2*k);

                        self.regPopulation = [self.regPopulation Regressor(X,[],Xenv)];
                        self.regPopulation(end).deriveEnvelopeTerms();
                        self.regPopulation(end).sortindexes();
                    end
                end
                % 2nd
                for k = 1:((P-1)/2)
                    for l = 1:M
                        X = [0 0];
                        Xconj = l;
                        Xenv = repmat(0,1,2*(k-1));
                        self.regPopulation = [self.regPopulation Regressor(X,Xconj,Xenv)];
                        self.regPopulation(end).deriveEnvelopeTerms();
                        self.regPopulation(end).sortindexes();
                    end
                end
                % 3rd
                for k = 1:((P-1)/2)
                    for l1 = 1:M
                        for l2 = l1:M
                            X = [l1 l2];
                            Xconj = 0;
                            Xenv = repmat(0,1,2*(k-1));
                            self.regPopulation = [self.regPopulation Regressor(X,Xconj,Xenv)];
                            self.regPopulation(end).deriveEnvelopeTerms();
                            self.regPopulation(end).sortindexes();
                        end
                    end
                end
                for k = 1:((P-1)/2)
                    for l1 = 1:M
                        for l2 = 1:M
                            X = [0 l2];
                            Xconj = [l1];
                            Xenv = repmat(0,1,2*(k-1));
                            self.regPopulation = [self.regPopulation Regressor(X,Xconj,Xenv)];
                            self.regPopulation(end).deriveEnvelopeTerms();
                            self.regPopulation(end).sortindexes();
                        end
                    end
                end
                for k = 2:((P-1)/2)
                    for l1 = 1:M
                        for l2 = l1:M
                            X = [0 0 0];
                            Xconj = [l1 l2];
                            Xenv = repmat(0,1,2*(k-2));
                            self.regPopulation = [self.regPopulation Regressor(X,Xconj,Xenv)];
                            self.regPopulation(end).deriveEnvelopeTerms();
                            self.regPopulation(end).sortindexes();
                        end
                    end
                end
            end
            % GMP
            % if strcmp(self.inittype,'GMP') || strcmp(self.inittype, 'compositeall')
            %%% Change to make more flexible the initialization
            if ~isempty(strfind(self.inittype,'GMP')) || strcmp(self.inittype, 'compositeall')
                indk = 0;
                for k = 1:length(self.Ka)
                    for l = 0:self.La(k)
                        X = l;
                        Xenv = repmat(l,1,self.Ka(k));

                        self.regPopulation = [self.regPopulation Regressor(X,[],Xenv)];
                        self.regPopulation(end).deriveEnvelopeTerms();
                        self.regPopulation(end).sortindexes();
                    end
                end

                for k = 1:length(self.Kb)
                    for l = 0:self.Lb(k)
                        for m = 1:self.Mb(k)

                            X = l;
                            Xenv = repmat(l+m,1,self.Kb(k));

                            self.regPopulation = [self.regPopulation Regressor(X,[],Xenv)];
                            self.regPopulation(end).deriveEnvelopeTerms();
                            self.regPopulation(end).sortindexes();
                        end
                    end
                end

                for k = 1:length(self.Kc)
                    for l = 0:self.Lc(k)
                        for m = 1:self.Mc(k)
                            X = l;
                            Xenv = repmat(l-m,1,self.Kc(k));

                            self.regPopulation = [self.regPopulation Regressor(X,[],Xenv)];
                            self.regPopulation(end).deriveEnvelopeTerms();
                            self.regPopulation(end).sortindexes();
                        end
                    end
                end
            end
            if strcmp(self.inittype, 'noinit')
                % Do nothing. In this case, it retains the regressors
                % already set up
            end
        end
        %% buildU
        %   Builds the regressor matrix
        function self = buildX(self)
            self.X = [];
            for i = 1:length(self.regPopulation)
                self.regPopulation(i).buildRegressor(self.x, self.n, self.Qpmax, self.Qnmax);
                self.X =  [self.X, self.regPopulation(i).reg];
                self.Rmat{i} = self.regPopulation(i).print();
            end
            self.yX = self.y(self.n(1+self.Qpmax:end-self.Qnmax));
        end
        %% printModel
        %   Generates Rmat in human-readable form
        function self = printModel(self)
            for i = 1:length(self.regPopulation)
                self.Rmat{i} = self.regPopulation(i).print();
                fprintf('%d %s\n',i,self.Rmat{i});
            end
        end

        %% evaluation
        %   Executes domp over the population
        function self = evaluation(self)
            self.buildX();
            if strcmp(self.DOMPtype,'DOMP')
                [~, s, nopt, h, ~, nmse] = RCDOMP_GVG(self.X, self.yX, self.Rmat, self.maxPopulation, self.verbosity, self.showPlots, self.evaluationtype);
            %[~, s, nopt, ~, ~, nmse] = RCDOMP_GVG_Ridge(self.X, self.yX, self.Rmat, self.maxPopulation, self.lambda, self.verbosity, self.showPlots, self.evaluationtype);
            elseif strcmp(self.DOMPtype,'POMP')
           % [~, s, nopt, h, ~, nmse] = domp_partial(self.X, self.yX, self.Rmat, self.maxPopulation, self.lambda, 0.5, self.verbosity, self.showPlots, self.evaluationtype);
            [~, s, h, ~, nmse, nopt] = domp_partial(self.X, self.yX, self.Rmat, self.alpha, self.lambda, self.maxPopulation);
            end
            self.nmsev = nmse;
            self.nopt = nopt;
            self.h = h;

            if strcmp(self.evaluationtype,'BIC')
            self.nmse = nmse(nopt);
            self.s = s(1:nopt);
            self.regPopulation = self.regPopulation(s(1:nopt));
            elseif strcmp(self.evaluationtype,'maxPopulation')
                self.nmse = nmse(end);
                self.s = s;
                self.regPopulation = self.regPopulation(s);
            end
            scores = [0 diff(nmse)];

            for i = 1:length(self.regPopulation)
                self.regPopulation(i).score = scores(i);
            end
        end
        %% selection:
        function self = selection(self)
            self.regPopulation = self.regPopulation(1:min(self.maxPopulation,length(self.regPopulation)));
        end
        %% crossover: creates the next generation
        %       Mixes the best regressors between them to create
        %       the next generation of regressors.
        function self = crossover(self)
            rp = randperm(length(self.regPopulation));
            for i = 1:(length(self.regPopulation)*self.crossoverrate)
                newr = self.regPopulation(i).crossover(self.regPopulation(rp(i)));
                if(self.verbosity>=2)
                    fprintf("Crossover: %s and %s produced %s\n", self.regPopulation(i).print(), self.regPopulation(rp(i)).print(), newr.print());
                end
                self.regPopulation = [self.regPopulation newr];
            end
        end
        %% mutation: Mutates part of the populaton,
        %       Mutates part of the populaton,
        %       determinated by the input mutationrate.
        function self = mutation(self)
            Xmutate = self.regPopulation(1:floor(length(self.regPopulation)*self.mutationrate));
            for i = 1:length(Xmutate)
                r = randi([1 3],1,1);
                muttype = ["functional", "memory", "order"];
                if(self.verbosity>=2) fprintf("Mutation (type %s): %s mutated to", muttype(r), Xmutate(i).print()); end
                if r == 1
                    % Functional mutation
                    self.regPopulation = [self.regPopulation Xmutate(i).mutateordershuffle()];
                elseif r == 2
                    % Memory mutation
                    self.regPopulation = [self.regPopulation Xmutate(i).mutatememory(self.Qnmax,self.Qpmax)];
                elseif r == 3
                    % Order mutation
                    self.regPopulation = [self.regPopulation Xmutate(i).mutateorderincrement()];
                end
                if(self.verbosity>=2) fprintf("%s\n", self.regPopulation(end).print()); end
            end
        end

        %% removerepeated: deletes repeated regs
        function self = removerepeated(self)
            % if strcmp(self.inittype,'default')
            %%% Change to avoid to forcely include the GVG constituents in
            %%% all cases. They are included just if it is not the initialization 
            %%% of GVG. That means that there is more than just one GVG generation
            if strcmp(self.inittype,'default') || ~(self.initgen)  
            % We add the first three regressors so we ensure they are not
            % lost
                self.regPopulation = [self.regPopulation Regressor([0],[],[])];
                self.regPopulation = [self.regPopulation Regressor([],[0],[])];
                self.regPopulation = [self.regPopulation Regressor([],[],[0])];
            end

            % Canonical form
            for i = 1:length(self.regPopulation)
                self.regPopulation(i).deriveEnvelopeTerms();
                self.regPopulation(i).sortindexes();
            end

            % Removing regressors with order > Pmax
            purgedOrder = 0;
            regdelete = [];
            for i = 1:length(self.regPopulation)
                regOrder = length(self.regPopulation(i).X) + length(self.regPopulation(i).Xconj) + length(self.regPopulation(i).Xenv);
                if regOrder>self.Pmax
                    regdelete = [regdelete i];
                    purgedOrder = purgedOrder + 1;
                end
            end
            self.regPopulation(regdelete) = [];
            if(self.verbosity>=2)
                fprintf('Number of regressors removed (Pmax): %d\n', purgedOrder);
            end

            % Removing regressors with memory > Qmax
            purgedMemory = 0;
            regdelete = [];
            for i = 1:length(self.regPopulation)
                regMemory = max([self.regPopulation(i).X self.regPopulation(i).Xconj self.regPopulation(i).Xenv]);
                % if regMemory>self.Qnmax
                %%% Change: this was an error
                if regMemory>self.Qpmax 
                    regdelete = [regdelete i];
                    purgedMemory = purgedMemory + 1;
                end
            end
            self.regPopulation(regdelete) = [];
            if(self.verbosity>=2)
                fprintf('Number of regressors removed (Qmax): %d\n', purgedMemory);
            end

            % Removing repeated regressors
            purgedRep = 0;
            for i = 1:length(self.regPopulation)
                j = i+1;
                while j <= length(self.regPopulation)
                    if self.regPopulation(i).equals(self.regPopulation(j))
                        if(self.verbosity>=2)
                            fprintf('Regressor removed: %s\n', self.regPopulation(i).print());
                        end
                        self.regPopulation(j) = [];
                        j = j-1;
                        purgedRep = purgedRep +1;
                    end
                    j = j+1;
                end
            end
            if(self.verbosity>=2)
                fprintf('Number of repeated regressors removed: %d\n', purgedRep);
            end
        end

        %% buildUcustomX
        %   Builds the regressor matrix for a different pair x-y
        function [X,yX] =  buildUcustomX(self, x, y, n)
            X = [];
            for i = 1:length(self.regPopulation)
                self.regPopulation(i).buildRegressor(x, n, self.Qpmax, self.Qnmax);
                X =  [X, self.regPopulation(i).reg];
            end
            yX = y(n(1+self.Qpmax:end-self.Qnmax));
        end

        function [self] =  clearRegressors(self)
            for i = 1:length(self.regPopulation)
                self.regPopulation(i).reg=[];
            end
        end
        %% regress
        %   Regresses the model
        function self = regress(self)
            self.buildX();
            normX = vecnorm(self.X);
            Xn = self.X*diag(normX.^(-1));
            ymod = (self.X*(diag(normX.^-1)*((pinv(Un)*self.yX))));
            self.nmse =20*log10(norm(ymod-self.yX,2)/norm(self.yX,2));
        end
        %% prepareForSave: Clears unnecessary data to reduce object size before saving
        % This function retains only the essential data in the object,
        % removing the rest to minimize the object's size for efficient storage.
        % It clears the `reg` field in each regressor, as well as the fields
        % `x`, `y`, `n`, and `U`.
        function self = prepareForSave(self)
            % Clear the 'reg' field for each regressor in the population
            for i = 1:length(self.regPopulation)
                self.regPopulation(i).reg = [];
            end

            % Clear unnecessary fields to save space
            self.x = [];
            self.y = [];
            self.n = [];
            self.X = [];
            self.yX = [];
        end
    end
end