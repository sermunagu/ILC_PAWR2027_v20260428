%filenamedate = '20260203T090813';
inline_functions
load(['results' filesep 'experiment' filenamedate],'meas_out','exp_config')
u = meas_out(1).u;
load(['results' filesep 'experiment' filenamedate '_xy_execution'],'dpd')

dBm = @(x) 10*log10(rms(x).^2/100)+30;

% Inicialización (las dos líneas que pediste)

meas_out = [  meas_out(1) meas_out(end)];

Nsignals = numel(dpd);

for k = 1:Nsignals

    x = dpd(k).yvalmod;

    % --- CFR ---
    xCFR = CFR_hard( x , 15 );

    [y, measdata]= measureADRV(xCFR, exp_config.captureTime);
%     Lout = 78.60-6-10+6;
%         Gin = 60.8-6;
%     y = y*10^(Lout/20);
% 
%     y = y(:); y = y-mean(y);
%     fh = getOrCreateFigure('Measured spectrum', true);
%     [Pxx, fvec] = spectrumest(u, fs, true, 'Welch', fh);
%     hold on
%     [Pxx, fvec] = spectrumest(y, fs, true, 'Welch', fh);
%     y = full_sync_5G(y, u, fs);
% 
%     [~, ~, EVM, NMSE] = analiza_medidas_5GNR_v5(y, u, info_signal, exp_config.fc)
%     [ACPR, NMSE] = ACPROFDM(u, y, fs,  info_signal.BW, info_signal.BWeff, info_signal.Foff)
% 
%     performance.ACPR = ACPR; performance.EVM = EVM; performance.NMSE = NMSE;
%     performance.nmse_40 = NMSE; %Pendiente arreglar
%     performance.evm_rms_med = EVM; %Pendiente arreglar
%     medida.y = y; medida.x = xDPD; medida.u = u; medida.performance = performance;
%   
%     medida.xCFR = xDPDCFR;
% medida.data = measdata; medida.w = []; medida.Gin = 0;
% % --- Construcción de la estructura de la medida ---
% medida.descr = dpd(k).modeltype;
% % Guardamos la medida al final de meas_out_DPD
% meas_out_DPD = [meas_out_DPD, medida];
% % Mostrar figuras / resumen
% medida2figure(meas_out_DPD);


y = full_sync_5G(y, xCFR, fs, info_signal.BW, info_signal.Foff);
        y = y*10^(Lout/20); y = y(:); y = y-mean(y);
        
        [~, ~, EVM, NMSE] = analiza_medidas_5GNR_v5(usw, y, info_signal, fc);
        [ACPR, NMSE] = ACPROFDM(u, y, fs,  info_signal.BW, info_signal.BWeff, info_signal.Foff);

        [G, Gc, Phc] = calculate_Gc(y,xCFR);
        gc = 10^(Gc/20);
        g = 10^(G/20);
        G0 = 65;
        g0 = 10^(G0/20);


        meas.descr = dpd(k).modeltype;
        meas.mu = [];             % Learning rate for this iteration
        store_data_and_show_performance
        update_figures
end

save(['results' filesep 'experiment' filenamedate '_DPD'],'meas_out');