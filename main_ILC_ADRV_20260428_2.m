%% Prepare workspace
%addpath('toolbox');
%addpath('toolbox_ADRV');
addpath('toolbox_signalgen');
addpath('confset');

clearvars -except TRx; close all; clc;

inline_functions

% power on:
% fuenteDC(1,[],-15);
% fuente_Doherty('on')
% fuenteK_monitorI1
%
% power off:
% fuente_Doherty('off')
% fuenteDC(1,[],0);

% if ~exist('TRx','var')
%     connectADRV(2600);
%     global TRx
% end
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

waveform_id = 8;                 % Select waveform 1..8
config_signal_master_5waveforms

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

y = u;
fc = 0;

[ACPR, ACPR2, EVM, NMSE] = analiza_medidas_5GNR_v6(usw, u, y, info_signal, fc);


