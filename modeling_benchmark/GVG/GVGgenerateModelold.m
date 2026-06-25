function [rManager,regPopulation,nmseid,genval,nmsevalv,rManagerv,yvalmod] = GVGgenerateModel(x,y,xval,yval,GVGconfig)

populationsize = []; % Population size for the genetic algorithm.
looptime = [];       % Time taken for each generation.
nmseid = [];         % NMSE (Normalized Mean Squared Error) for identification.
genval = [];         % Generation index for validation.
nmsevalv = [];       % NMSE for validation.
rManagerv = [];      % Copy of each generation
regPopulation = [];  % Regressor population for every iteration.

rManager = regressorManager(x,y,GVGconfig);
rManager.initialization();
rManager.removerepeated();
rManager.printModel();

for igen = 1:GVGconfig.ngenerations
    tic; fprintf('--------------------- Generation %d ---------------------\n',igen)

    rManager.evaluation();
    rManager.selection();
    rManager.printModel();
    % regPopulation{igen} = rManager.regPopulation;
    % Validation needs to be done after selection, since it is the output
    % of the generation
    populationsize(igen) = length(rManager.regPopulation);
    nmseid(igen) = rManager.nmse;
    rManagerv{igen} = copy(rManager);
    rManagerv{igen}.prepareForSave();
    if(~GVGconfig.storePopulation)
        rManagerv{igen}.regPopulation = [];
    end
    % Validation every validatengen generations
    if(GVGconfig.validate && rem(igen,GVGconfig.validatengen)==0)
        rManager.clearRegressors();
        % These indexes ensure ymod has the same length than yval
        N = length(xval);
        n = [N-GVGconfig.Qpmax+1:N , 1:N , 1:GVGconfig.Qnmax];
        [U,yU] =  rManager.buildUcustomX(xval, yval, n');
        normU = vecnorm(U);
        Un = U*diag(normU.^(-1));
        yvalmod = (U*(diag(normU.^-1)*((pinv(Un)*yU))));
        %nmseval =20*log10(norm(yvalmod-yU,2)/norm(yU,2));
        nmseval = calc_NMSE(yvalmod, yU);
        rManager.clearRegressors();
        genval = [genval igen];
        nmsevalv = [nmsevalv nmseval];

        if GVGconfig.showPlots
            fh = findobj('Type', 'Figure', 'Name', 'GVG performance');
            if length(fh)==0
                figure('Name','GVG performance'); clf;
            else
                figure(fh(1)); clf;
            end
            plot(1:igen,nmseid,'b','LineWidth',2);hold on;plot(genval,nmsevalv,'r*','LineWidth',2); grid on;xlabel('Generation'), ylabel('NMSE (dB)'), legend('Identification','Validation');
        end


        fh = findobj('Type', 'Figure', 'Name', ['AMAM performance ' GVGconfig.inittype]);
        if length(fh)==0
            figure('Name',['AMAM performance ' GVGconfig.inittype]); clf;
        else
            figure(fh(1)); clf;
        end
        dBminst = @(x) 10*log10(abs(x).^2/50)+30;
        plot(dBminst(xval),dBminst(yval),'b.')
        hold on
        plot(dBminst(xval),dBminst(yvalmod),'r.')
        xlabel('Instantaneous Input Power (dBm)');
        ylabel('Instantaneous Output Power (dBm)');
        legend('Validation Signal','Modeled Signal');

        fh = findobj('Type', 'Figure', 'Name', ['GainAM performance ' GVGconfig.inittype]);
        if length(fh)==0
            figure('Name',['GainAM performance ' GVGconfig.inittype]); clf;
        else
            figure(fh(1)); clf;
        end
        dBminst = @(x) 10*log10(abs(x).^2/50)+30;
        plot(dBminst(xval),dBminst(yval)-dBminst(xval),'b.')
        hold on
        plot(dBminst(xval),dBminst(yvalmod)-dBminst(xval),'r.')
        xlabel('Instantaneous Gain (dB)');
        ylabel('Instantaneous Output Power (dBm)');
        legend('Validation Signal','Modeled Signal');

        fh = findobj('Type', 'Figure', 'Name', ['Spectrum ' GVGconfig.inittype]);
        if length(fh)==0
            figspec=figure('Name',['Spectrum ' GVGconfig.inittype]); clf;
        else
            figspec=figure(fh(1)); clf;
        end
        [Pxxy, fvec,~] = spectrumest(yval, 614.4e6, true, 'welch', figspec,false, -75e6, +75e6);
        hold on
        [Pxxy, fvec,~] = spectrumest(yvalmod, 614.4e6, true, 'welch', figspec,false, -75e6, +75e6);
        [Pxxy, fvec,~] = spectrumest(yval-yvalmod, 614.4e6, true, 'welch', figspec,false, -75e6, +75e6);
        legend('Validation Signal','Modeled Signal','Error Signal');
    end

    rManager.crossover();
    rManager.mutation();
    rManager.removerepeated();
    %rManager.printModel();

    looptime(igen) = toc;
end

rManager.prepareForSave();

if GVGconfig.showPlots
    figure(),plot(populationsize,'b','LineWidth',2); grid on;xlabel('Generation'), ylabel('Population size (after selection)');
end

end