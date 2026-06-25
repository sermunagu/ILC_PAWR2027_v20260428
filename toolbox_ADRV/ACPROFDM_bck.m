function [ACPR, NMSE] = ACPROFDM(x, y, fs, BWch, BWeff)
% ACPR5G_RFSOC - High-resolution PSD and ACPR for 5G-NR
% x: ideal reference, y: measured signal, fs: sampling rate
% BWch: Channel spacing (e.g. 100MHz), BWeff: Integration bandwidth (e.g. 97.2MHz)

% 1. Pre-processing & NMSE
xn = x(:) - mean(x);
yn = y(:) - mean(y);
% Standard NMSE calculation
NMSE = 20*log10(norm(yn/norm(yn) - xn/norm(xn)));

% 2. High-Resolution PSD Estimation (Welch method)
% We use a larger window (2^14) to see the subcarrier structure "finer"
win_len = 2^14; 
[psd_val, f] = pwelch(y, kaiser(win_len, 38), win_len/2, win_len*2, fs, 'centered');
PSD_data = 10 * log10(psd_val);

% 3. Reference Power Calculation (Main Band)
Pmain = 10*log10(bandpower(y, fs, [-BWeff/2 BWeff/2])) + 30; % dBm

% 4. ACPR Calculations
ACPR = NaN(1, 4);
fNyq = fs / 2;
offsets = [-2*BWch, -1*BWch, 1*BWch, 2*BWch];
colors = [0, 0.5, 0; 0, 0.6, 0.6; 0.8, 0.6, 0; 0.6, 0, 0.6]; % Professional palette

for i = 1:4
    cent = offsets(i);
    if abs(cent) + BWeff/2 <= fNyq
        Padj = 10*log10(bandpower(y, fs, cent + [-BWeff/2 BWeff/2])) + 30;
        ACPR(i) = Padj - Pmain;
    end
end

% 5. Plotting
fh = getOrCreateFigure('Spectrum/ACPR Analysis', true);
set(fh, 'Position', [100, 100, 1000, 500]);

% Main Plot
plot(f * 1e-6, PSD_data, 'Color', [0.2 0.2 0.2], 'LineWidth', 0.5); 
hold on; grid on;

% Highlight Main Band with Shading
fill_band(f*1e-6, PSD_data, [-BWeff/2, BWeff/2]*1e-6, [0 0.4 0.6], 'Main');

% Highlight Adjacent Channels
labels = {'2nd Lower', '1st Lower', '1st Upper', '2nd Upper'};
for i = 1:4
    if ~isnan(ACPR(i))
        band_range = (offsets(i) + [-BWeff/2, BWeff/2]) * 1e-6;
        fill_band(f*1e-6, PSD_data, band_range, colors(i,:), labels{i});
        
        % Add Text for ACPR
        text(offsets(i)*1e-6, max(PSD_data) + 2, sprintf('%.1f dB', ACPR(i)), ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', colors(i,:));
    end
end

% Formatting
xlabel('Frequency (MHz)');
ylabel('PSD (dB/Hz)');
title(sprintf('5G-NR Spectrum: NMSE = %.2f dB | P_{avg} = %.1f dBm', NMSE, Pmain));
legend('Raw PSD', 'Main Channel', 'Location', 'northeastoutside');
xlim([-fs/2 fs/2]*1e-6 * 0.9); % Show 90% of Nyquist
ylim([min(PSD_data)-5, max(PSD_data)+15]);

end

% --- Helper Function for Shaded Bands ---
function fill_band(f_mhz, psd, range, col, label)
    idx = (f_mhz >= range(1) & f_mhz <= range(2));
    if any(idx)
        % Create the patch
        patch([f_mhz(idx); flipud(f_mhz(idx))], [psd(idx); min(psd)*ones(sum(idx),1)], ...
              col, 'FaceAlpha', 0.3, 'EdgeColor', col, 'LineWidth', 1.5, 'DisplayName', label);
    end
end