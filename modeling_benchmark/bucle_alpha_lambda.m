% Definir combinaciones de alpha y lambda
alpha_vals = [ ...
    1-1e-3, 1-1e-4, 1-1e-5, 1-1e-6, ... % alpha = 1 - eps
    1e-3,   1e-4,   1e-5,   1e-6, ...   % alpha = eps
    1];                                % caso especial

lambda_vals = [1e-3, 1e-4, 1e-5, 0];    % incluye lambda = 0

% Configuración fija
GVGconfig.DOMPtype  = 'POMP';
GVGconfig.inittype = 'compositeall';

% Inicialización
results = {};
k = 1;

for a = alpha_vals
    for l = lambda_vals

        % Forzar solo el caso (alpha=1, lambda=0)
        if a == 1 && l ~= 0
            continue
        end

        % Evitar lambda = 0 con alpha distintos de 1 si no lo deseas
        if a ~= 1 && l == 0
            continue
        end

        GVGconfig.alpha  = a;
        GVGconfig.lambda = l;

        [~,~,nmseid,~,nmseval,rManagerv,~] = ...
            GVGgenerateModel(x(nid), y(nid), x, y, GVGconfig);

        results{k,1} = a;
        results{k,2} = l;
        results{k,3} = nmseid;
        results{k,4} = nmseval;
        results{k,5} = max(abs(rManagerv{end}.h(rManagerv{end}.s,rManagerv{end}.nopt)));

        k = k + 1;
    end
end

% Convertir a tabla
T = cell2table(results, ...
    'VariableNames', {'alpha','lambda','NMSE_id','NMSE_val','max_h'});

disp(T)
