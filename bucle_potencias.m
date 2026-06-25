Pin_dBm_vec = -30:2:-20;

ACPR_vs_Pin = cell(size(Pin_dBm_vec));
NMSE_vs_Pin = cell(size(Pin_dBm_vec));
EVM_vs_Pin  = cell(size(Pin_dBm_vec));
measdata_vs_Pin = cell(size(Pin_dBm_vec));

for ip = 1:numel(Pin_dBm_vec)

    Pin_dBm = Pin_dBm_vec(ip);

    xCFR_scaled = scale_dBm(xCFR, Pin_dBm);

    [y, measdata] = measureADRV(xCFR_scaled, captureTime);

    y = full_sync_5G(y, u, fs, info_signal.BW, info_signal.Foff);
    y = y * 10^(Lout/20);
    y = y(:);
    y = y - mean(y);

    [~, ~, EVM, NMSE_5GNR] = analiza_medidas_5GNR_v6(usw, u, y, info_signal, fc);
    [ACPR, NMSE_ACPR] = ACPROFDM(u, y, fs, info_signal.BW, info_signal.BWeff, info_signal.Foff);

    ACPR_vs_Pin{ip} = ACPR;
    NMSE_vs_Pin{ip} = NMSE_ACPR;
    EVM_vs_Pin{ip}  = EVM;
    measdata_vs_Pin{ip} = measdata;

    fprintf('Pin = %.1f dBm | EVM = %s | NMSE = %s | ACPR = %s\n', ...
        Pin_dBm, ...
        mat2str(EVM, 4), ...
        mat2str(NMSE_ACPR, 4), ...
        mat2str(ACPR, 4));
end

ACPR_mat = cell2mat(ACPR_vs_Pin(:));   % 6 x 4
NMSE_mat = cell2mat(NMSE_vs_Pin(:));   % normalmente 6 x N

ACPR_left  = ACPR_mat(:,2);
ACPR_right = ACPR_mat(:,3);

figure;
tiledlayout(2,1);

nexttile;
plot(Pin_dBm_vec, NMSE_mat, '-o', 'LineWidth', 1.5);
grid on;
xlabel('Input power (dBm)');
ylabel('NMSE (dB)');
title('NMSE vs Input Power');

nexttile;
plot(Pin_dBm_vec, ACPR_left, '-o', 'LineWidth', 1.5); hold on;
plot(Pin_dBm_vec, ACPR_right, '-s', 'LineWidth', 1.5);
grid on;
xlabel('Input power (dBm)');
ylabel('ACPR (dBc)');
title('ACPR vs Input Power');
legend('Lower adjacent', 'Upper adjacent', 'Location', 'best');
