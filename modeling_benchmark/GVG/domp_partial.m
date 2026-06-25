function [h, s, h_full, t_exec,nmse, nopt] = domp_partial(X, y, Rmat, alpha, lambda, maxpopulation)
% DOMP_PARTIAL_ALPHA: DOMP with partial orthogonalization
% alpha = 0 -> OMP, alpha = 1 -> full DOMP, 0<alpha<1 -> partial

[~,N] = size(X);

% --- Normalize columns ---
normX = vecnorm(X);
Xn = X*diag(normX.^-1);

Ncoef = maxpopulation;
Zn = Xn;
h = zeros(N, min(Ncoef,N));
ve2 = zeros(1, min(Ncoef,N));
r = y;
s = []; % support set is empty
nopt = min(Ncoef,N); % We assume nopt is the max.

for n = 1:min(Ncoef,N)
    tic;
    % --- Correlation ---
   Cx = abs(Zn' * r(:,n));
% Cx = abs(Zn' * filter_residual(r(:, n)));


    % Avoid selecting already chosen atoms
    Cx(s) = 0;
    [Cxsort, ind] = sort(Cx, 'descend');
    s(n) = ind(1);

    % --- Least squares on selected support ---
    warning('off','MATLAB:nearlySingularMatrix');
    h(s, n) = diag(normX(s).^-1)*inv(Xn(:,s)'*Xn(:,s) + lambda * eye(length(s))) * Xn(:,s)' * y;

    % To perform Ridge through SVD
    %   [U,S,V] = svd(X(:,s), 'econ'); % SVD de la submatriz
    %S2 = diag(S).^2;
    %h(s,n) = V * diag(1./(S2 + lambda)) * S' * U' * y;
    yLS = X(:,s) * h(s,n);

    % --- Residual update with partial orthogonalization ---
    %r(:, n+1) = y - yLS;


    % Projection of selected regressor onto basis
    C = Zn.' * conj(Zn(:, s(n)));
    % Partial orthogonalization of residual
    r(:, n+1) = r(:, n) - alpha * (Zn(:, s(n)) * (Zn(:, s(n))' * r(:, n)));

    

    % Subtract projection from Zn
    Zn = Zn - alpha * kron(C.', Zn(:, s(n)));
    % Rescale basis
    for in = 1:N
        Zn(:,in) = Zn(:,in) / norm(Zn(:,in));
    end


    ve2(n) = var(r(:, n+1));
    %nmse(n) = 20*log10(norm(yLS - y, 2) / norm(y,2));
    nmse(n) = 20*log10(norm(r(:, n), 2) / norm(y,2));
    var_h(n) = var((diag(normX(s))*h(s, n))/max(abs(y)));
    max_h(n) = max(abs((diag(normX(s))*h(s, n))/max(abs(y))));

    % --- Print iteration info ---
    fprintf('%d | %d | %s | %4.1f\n', n, s(n), Rmat{s(n)}, nmse(n));

    t_exec(n) = toc;
end

% --- NMSE plot (persistent figure) ---
fname = 'Performance';                          % usa SIEMPRE el mismo nombre
fh = findobj('Type','Figure','Name',fname);
if isempty(fh)
    fh = figure('Name',fname);
else
    figure(fh(1));
end

ax = gca; hold(ax,'on');

% Traza con DisplayName para que la leyenda lo recoja automáticamente
plot(ax, nmse, 'LineWidth', 0.8, ...
    'DisplayName', sprintf('NMSE, \\alpha = %.3f, \\lambda = %.0e', alpha, lambda));

% Muestra/actualiza la leyenda sin borrar entradas previas
lgd = legend(ax,'show');               % crea la leyenda si no existe
set(lgd,'AutoUpdate','on', ...         % añade nuevas curvas automáticamente
    'Interpreter','tex', ...       % para mostrar \alpha correctamente
    'Location','best');

xlabel(ax,'Number of coefficients');
ylabel(ax,'NMSE (dB)');
grid(ax,'on');

% --- Var(h) plot (persistent figure) ---
fname = 'Variance';                          % nombre único para esta figura
fh = findobj('Type','Figure','Name',fname);
if isempty(fh)
    fh = figure('Name',fname);
else
    figure(fh(1));
end

ax = gca; hold(ax,'on');

% Graficar la varianza de h
semilogy(ax, var_h, 'LineWidth', 0.8, ...
    'DisplayName', sprintf('NMSE, \\alpha = %.3f, \\lambda = %.0e', alpha, lambda));

% Leyenda persistente y acumulativa
lgd = legend(ax,'show');
set(lgd,'AutoUpdate','on', ...
    'Interpreter','tex', ...
    'Location','best');

xlabel(ax,'Number of coefficients');
ylabel(ax,'Var(h)');
grid(ax,'on');

% --- max(h) plot (persistent figure) ---
fname = 'Max h';                          % nombre único para esta figura
fh = findobj('Type','Figure','Name',fname);
if isempty(fh)
    fh = figure('Name',fname);
else
    figure(fh(1));
end

ax = gca; hold(ax,'on');

% Graficar la max de h
semilogy(ax, max_h, 'LineWidth', 0.8, ...
    'DisplayName', sprintf('NMSE, \\alpha = %.3f, \\lambda = %.0e', alpha, lambda));

% Leyenda persistente y acumulativa
lgd = legend(ax,'show');
set(lgd,'AutoUpdate','on', ...
    'Interpreter','tex', ...
    'Location','best');

xlabel(ax,'Number of coefficients');
ylabel(ax,'max|h|');
grid(ax,'on');


% --- Print summary ---
fprintf('Minimum NMSE: %4.2f. Number of coefficients: %d\n', ...
    nmse(end), length(nmse));

h_full = h;
h = h(:,end);

end
