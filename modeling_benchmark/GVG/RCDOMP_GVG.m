function [hopt, s, nopt, h, Tacc,nmse] = RCDOMP_GVG(X, y, Rmat, Ncoef, verbosity, showPlots, evaluationtype)
[~,N] = size(X);

% Normalization of input matrix: from Matlab 2018b on, this loop can be
% replaced by vecnorm.
for in=1:N
    normX(in)=norm(X(:,in));
end
Xn=X*diag(normX.^-1);

% Initialization
Zn = Xn;
h = zeros(N, 1);
ve2 = zeros(1, min(Ncoef,N));
r = y;
yest = zeros(size(y));
s = []; % Support set is empty
Tacc = eye(N);
RZ = Zn'*Zn;
Ry = Zn'*y;
M = length(y);
nopt = min(Ncoef,N); % We assume nopt is the max.

for k = 1:min(Ncoef,N)
    % Regressor selection
    %[caux,saux]=sort(abs(Ry./sqrt(diag(RZ))),'descend');
	
	% Implementation of soft thresholding (https://doi.org/10.1109/PAWR63954.2025.10904039) to avoid numerical issues.
	%lambda = 1e-7;
	lambda = 0;
	[caux,saux]=sort(abs(Ry./sqrt(diag(RZ))).*(sthresh(abs(sqrt(diag(RZ))),lambda)./abs(sqrt(diag(RZ)))),'descend');
	
    aux2 = setxor(saux,s,'stable'); % xor removes the elements of saux in s
    s(k) = aux2(1);


    % Construction of T
    T = eye(N);
    T(s(k), setxor(s,1:N)) = -RZ(s(k),setxor(s,1:N))/(RZ(s(k),s(k)));
    T(s(k), s(k)) = 1/sqrt(RZ(s(k),s(k)));
    
    % Residual correlation update
    Ry(setxor(s,1:N)) = Ry(setxor(s,1:N)) - (RZ(s(k),setxor(s,1:N))/RZ(s(k),s(k)))' * Ry(s(k));
    Ry(s(k)) = Ry(s(k))/sqrt(RZ(s(k),s(k)));
    
    % Autocorrelation update
    RZ = T'*RZ*T;
    
    % Orthogonalization
    Zn = Zn*T;
    r = r - Zn(:,s(k))*Ry(s(k));
    ve2(k) = var(y-yest);
    nmse(k)=20*log10(norm(r,2)/norm(y,2));
    
    % The estimations are updated according to Tacc every X iterations to
    % avoid the accumulation of numerical errors
    %if(rem(k,50)==0)
        RZ = Zn'*Zn;
        Ry = Zn'*y;
    %end
    
    % Regression
    % Here we expect to have h in the Volterra space unnormalized (the
    % paper expects to have it normalized):
    h(s,k) = diag(normX(s).^-1)*Tacc(s,s)*Ry(s);
    
    % Estimation update
    yest = yest + Zn(:,s(k))*Ry(s(k));
    
    % Accumulation of T
    Tacc = Tacc*T;
    
    % Plot the correlation matrices in iterations 1, 5, 20 and 40
%     if(k==1 || k==5 || k==20 || k==40)
%         figure(1); clf;imagesc(abs(RZ));colorbar;axis square;
%         colormap(flipud(hot));set(gca,'YTickLabel',[]);set(gca,'XTickLabel',[]);drawnow; 
%         title(['Correlation matrix at iteration ' num2str(k)])
% %         saveas(gcf, ['../results/corr_mat_' num2str(k) '.png'])
% %         print(['../results/corr_mat_' num2str(k)], '-dpdf')   
%     end
    
    if(k~=1 && strcmp(evaluationtype,'BIC'))
        if ((nmse(k)-nmse(k-1))>-10/M*log10(2*M))
            nopt = k-1;
            nmse(end) = [];
            break;
        end
    end
    % Print the iteration, the index of the selected regressor, the text
    % representation of the regressor and the attained NMSE.
    if verbosity>=3
        if k==1
            fprintf('it. \t index \t Regressor \t NMSE \n',k,s(k),Rmat{s(k)},nmse(k));
        end
        fprintf('%d \t %d \t %s \t %4.1f dB\n',k,s(k),Rmat{s(k)},nmse(k));
    end
end

% Calculation of the Bayesian Information Criterion (BIC)
% M = length(y);
% BIC = 2*M*log(ve2)+2*(1:min(Ncoef,N))*log(2*M); % complex
% [~, nopt] = min(BIC);

% Plots of the NMSE and BIC evolution with the number of iterations
if showPlots
    fh = findobj( 'Type', 'Figure', 'Name', 'DOMP performance');
    if length(fh)==0
        figure('Name','DOMP performance')
    else
        figure(fh(1)); 
    end
    plot(nmse,'b','linewidth',0.5);hold on;plot(nopt,nmse(nopt),'ro');legend('NMSE','Optimum');xlabel('Number of coefficients'); ylabel('NMSE (dB)');  grid on;

end
% saveas(gcf, ['../results/NMSE.png'])
% print('../results/NMSE', '-dpdf')   
%figure;clf;plot(BIC,'g','linewidth',2);hold on;plot(nopt,BIC(nopt),'ro');legend('BIC','Optimum');xlabel('Number of coefficients'); ylabel('BIC')
% saveas(gcf, ['../results/BIC.png'])
% print('../results/BIC', '-dpdf')   
if verbosity>=1
    fprintf('Selection: Number of coefficients of the complete model: %d\n', N);
    fprintf('Selection: Last NMSE: %4.2f dB. Number of coefficients: %d\n', nmse(end), min(Ncoef,N));
    fprintf('Selection: RC-DOMP NMSE: %4.2f dB. Number of coefficients: %d\n', nmse(nopt),nopt);
end
hopt = h(:,nopt);
end


function y = sthresh(x,t)
	argm = (abs(x)-t);
	argm = (argm+abs(argm))/2;
	y = sign(x).*argm;
end