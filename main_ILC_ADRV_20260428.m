%% Prepare workspace
addpath('toolbox');
addpath('toolbox_ADRV');
addpath('toolbox_signalgen');
addpath('confset');

for waveform_id = 1:8

clearvars -except TRx waveform_id; close all; clc;

inline_functions

% power on:
% fuenteDC(1,[],-15);
% fuente_Doherty('on')
% fuenteK_monitorI1
%
% power off:
% fuente_Doherty('off')
% fuenteDC(1,[],0);

if ~exist('TRx','var')
    connectADRV(2600);
    global TRx
end
% disableRFADRV(TRx); % to disableRF
% TRx.disconnect(); % to release the handler
% TRx = reconnectADRV(2600); % to reconnect without programming FPGA


%% Signal configuration
%config_signal_50MHz_ADRV
% config_signal_100MHz_ADRV
% [usw, ~, info_signal] = genera_5GNR_multicarrier_v5(info_signal);
% mask = [-1 -(info_signal.BWeff/info_signal.fsovs) 0; (info_signal.BWeff/info_signal.fsovs) 1 0]; %1band
% maskerr = [-1 -(info_signal.BWeff/info_signal.fsovs) 1;
%     -(info_signal.BWeff/info_signal.fsovs) +(info_signal.BWeff/info_signal.fsovs) 0;
%     (info_signal.BWeff/info_signal.fsovs) 1 1];

%waveform_id = 8;                 % Select waveform 1..8
config_signal_master_5waveforms
[usw, ~, info_signal] = genera_5GNR_multicarrier_v5(info_signal);
% % 2 carrier 20 Mhz
% config_signal_2bands20MHz_ADRV
% [usw, ~, info_signal] = genera_5GNR_multicarrier_v5(info_signal);
% fmin = (info_signal.Foff - info_signal.BWeff/2)/(info_signal.fsovs(1)/2);
% fmax = (info_signal.Foff + info_signal.BWeff/2)/(info_signal.fsovs(1)/2);
% mask = [-1 fmin(1) 0;
%     fmin(1) fmax(1) 1;
%     fmax(1) fmin(2) 0;
%     fmin(2) fmax(2) 1;
%     fmax(2) 1  0];
% maskerr = [-1 fmin(1) 1;
%     fmin(1) fmax(1) 0;
%     fmax(1) fmin(2) 1;
%     fmin(2) fmax(2) 0;
%     fmax(2) 1  1];

u = clipping_PAPR_ICF(usw, 8, mask, 5);
fs = info_signal.fsovs(1); % Must be: 491.52e6;
info_signal.ffig = [true true];

%% Experiment configuration
fc = 2.6e9;
Lout = 78.60-6-10+6-6; %Doherty
Gin = 60.8-6-6; %Doherty
%Lout = 30;
%Gin = 19;
Ncycles = 16; % Number of signal repetitions to capture
%Ncycles = 2;
captureTime =Ncycles*length(u)/fs*1e3;

Niter = 15;
mu = 1/3*ones(1,Niter);

DLmethod = 'ILC'; % 'DLA' / 'ILC'

meas_out = [];
filenamedate = datestr(clock,30);

%% Initialization
switch DLmethod
    case 'ILC'
        U_w=zeros(length(u),1);
    case 'DLA'
        model_configuration_B
        [U, ~, Rmat] = model_gmp_generate_X(u, u, dpd_model);
        [f,c]=size(U);
        w = zeros(c,1);
        dw = zeros(c,1);
        normU = vecnorm(U);
        Un = U*diag(normU.^-1);
end

%% Power sweep
%RMSinv = -30:1:-19;
%RMSin = -23;
RMSin = -22;

%BandAtt = 0:-20:-80;
%BandAtt = 0:-1:-10;
%BandAtt = 0;
%BandAtt = 0

% for RMSin = RMSinv
%for iBandAtt = 1:length(BandAtt)

%     maskerr = [-1 -(info_signal.BWeff/info_signal.fsovs) 1;
%         -(info_signal.BWeff/info_signal.fsovs) +(info_signal.BWeff/info_signal.fsovs) 10^(BandAtt(iBandAtt)/20);
%         (info_signal.BWeff/info_signal.fsovs) 1 1];

    prev_ACPR = inf;
    u = scale_dBm(u, RMSin);
    x = u;
    U_w=zeros(length(u),1);

    %Load a previous ILC
    %     load('results/XX','meas_out');
    %     U_w = uCFR-meas_out(end-1).x;
    %     meas_out = meas_out(1);
    %     Niter = 3;
    %     mu = [0.1 0.1 0.1];

    for iter=1:Niter
        fprintf("Iteration %d\n",iter);

        switch DLmethod
            case 'ILC'
                x = u-U_w;
            case 'DLA'
                x = u-U*w;
        end

        xCFR = CFR_hard(x,15);

        fprintf("dBm(x) = %4.1f dBm, PAPR(x) = %4.1f dB, PEP(x)=dBm(x)+PAPR(x) = %4.1f dBm\n",dBm(xCFR),PAPR(xCFR),dBm(xCFR)+PAPR(xCFR));

        [y, measdata]= measureADRV(xCFR, captureTime);
        y = full_sync_5G(y, u, fs, info_signal.BW, info_signal.Foff);
        y = y*10^(Lout/20); y = y(:); y = y-mean(y);

        [~, ~, EVM, NMSE] = analiza_medidas_5GNR_v6(usw, u, y, info_signal, fc);
        [ACPR, NMSE] = ACPROFDM(u, y, fs,  info_signal.BW, info_signal.BWeff, info_signal.Foff);

        [G, Gc, Phc] = calculate_Gc(y,xCFR);
        gc = 10^(Gc/20);
        g = 10^(G/20);
        
        if iter==1
            %G0 = G; 
            %G0 = Gc;
            %G0 = 63.8;
            
            %G0 = 65;
            G0 = 63.5;
        end
        g0 = 10^(G0/20);

        e = y/g0-u;
        e = spectrumMask(e, maskerr);
        mu0 = 1;
        mu(iter)=mu0*10^(G0/20)/10^(G/20);
        
        switch DLmethod
        case 'ILC'
            U_w = U_w + mu(iter) * e;
            w = []; % for compatibility

            % ILC instantaneous gain:  
            % mu(iter)=1;
            % U_w = U_w + mu(iter) * (g0./(abs(y).^2+1e-8)) .*xCFR.*conj(y) .* e;
        case 'DLA'
            %dw = (inv(U'*U)*U')*e;
            dw = diag(normU.^-1)*(inv(Un'*Un)*Un')*e;
            w = w + mu(iter) * dw;
    end
 
        meas.descr = [DLmethod ' iter ' num2str(iter) ' RMS ' num2str(RMSin) ];
        meas.mu = mu(iter);             % Learning rate for this iteration
        store_data_and_show_performance
        update_figures

        % Stopping if convergence:
        %         if iter > 1
        %             if abs(prev_ACPR(end/2) - ACPR(end/2)) < 0.01
        %                 fprintf("Stopping early: ACPR improvement < 0.01 dB\n");
        %                 break;
        %             end
        %         end

        prev_ACPR = ACPR;
    end


%% One last measurement without DPD
% x = scale_dBm(u,dBm(x));
% u = x;
% [y, measdata]= measureADRV(x, captureTime);
%
% y = y*10^(Lout/20);y = y(:); y = y-mean(y);
%
% fh = getOrCreateFigure('Measured spectrum', true);
% spectrumest(u, fs, true, 'Welch', fh);
% hold on
% spectrumest(y, fs, true, 'Welch', fh);
% y = full_sync_5G(y, u, fs);
%
% [~, ~, EVM, NMSE] = analiza_medidas_5GNR_v5(y, u, info_signal, fc);
% [ACPR, NMSE] = ACPROFDM(u, y, fs,  info_signal.BW, info_signal.BWeff, info_signal.Foff);
%
%
% meas.descr = ['No DPD'];
% store_data_and_show_performance


%% Clean data and save
clear ans ACPR ACPR2 c data dBm dBminst e EVM f fh fig* imed iter maxdBm meas NMSE PAPR performance scale_dBm u U us w x y filename dw uCFR xCFR  measdata U_w;
exp_config = struct(G=G, G0=G0, Gc=Gc, Lout=Lout, ...
    Ncycles=Ncycles, Niter=Niter, PAPRd=PAPRd, Phc=Phc, ...
    RMSin=RMSin, captureTime=captureTime, fc=fc, fs=fs, ...
    g=g, g0=g0, gc=gc, mu=mu, waveform_id=waveform_id);

% Delete all the intermediate signals
% for i = 2:(length(meas_out)-2)
% meas_out(i).x = [];
% meas_out(i).y = [];
% meas_out(i).u = [];
% meas_out(i).xCFR = [];
% end

save(['results/experiment' filenamedate],'meas_out','exp_config','filenamedate', 'info_signal')

%% Save just u-x ILC for modeling.
x = meas_out(end).u;
y = meas_out(end).x;
description = ['Measurement taken from experiment' filenamedate '. ILC forward modeling.'];
save(['results' filesep 'experiment' filenamedate '_xy'],'x','y','fs','info_signal','description');
end
