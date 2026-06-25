function y = filter_residual (x)

Fs = 614400000; %info_signal2.fsovs;
B  = 97200000; %info_signal2.BWeff;

beta = 30.0;        % peso relativo adyacente
N    = 257;      % orden FIR (impar, lineal fase)

f = [ ...
    0, ...
    B/2, ...
    B/2, ...
    3*B/2, ...
    3*B/2, ...
    Fs/2 ] / (Fs/2);

m = [ ...
    1, ...        % en banda
    1, ...
    beta, ...     % adyacentes
    beta, ...
    0, ...        % stopband
    0 ];

h = fir2(N-1, f, m, hamming(N));

y = filtfilt(h, 1, x);

% figure;
% freqz(h,1,4096,Fs)
% grid on