function [T, out] = CompleteTensorKNNCell(T, args)


%%% Compute similarity
C = nan(size(T,3),size(T,3),size(T,1)); 
for d = 1:size(T,1)
    C(:,:,d) = corr(squeeze(T(d,:,:))); 
end
if isfield(args, 'maxSim')
    fprintf('maxSim = %d\n', args.maxSim);
    C(isnan(C)) = -Inf;
    C = sort(C, 3, 'descend');
    C(isinf(C)) = NaN;
    S = mean(C(:,:,1:args.maxSim), 3, 'omitnan');
else
    S = mean(C, 3, 'omitnan');
end

% % This is faster and is also memory efficient, but doesn't work for
% knn_ts
% C = zeros(size(T,3), size(T,3));
% nanCt = zeros(size(T,3), size(T,3));
% for d = 1:size(T,1)
%     newCors = corr(squeeze(T(d,:,:)));
%     tmp = cat(3,C,newCors);
%     C = nansum(tmp,3);
%     nanCt = nanCt + isnan(newCors);
% end
% S = C ./ (size(T, 1) - nanCt);
% clear nanCt tmp newCors C


% set any negative correlations to 0 so that they don't contribute 
if ~isempty(find(S(:) <= 0, 1))
   fprintf('Setting negative correlations to 0.\n');
   S(S < 0) = 0;
end

% set diagonal to 0
S(eye(size(S))~=0) = 0;

% set NaN's to 0
S(isnan(S)) = 0;

%%% Using this correlation matrix as the similarity measure, estimate each
%%% missing profile as a weighted combination of profiles for the same drug
%%% in other cell types, using the K nearest cell types

for drug = 1:size(T,1)
    cellsMissing = find(isnan(T(drug,1,:)));
        
    K = min(args.K, size(T,3) - length(cellsMissing));
    if K < args.K
        fprintf('Warning: only %d profiles available for drug %d\n', K, drug);
    end
    
    for c = 1:length(cellsMissing)
        cell = cellsMissing(c);
        preweights = S(cell,:);
        preweights(cellsMissing) = 0;
        [preweights_sort, idx_sort] = sort(preweights, 'descend');
        weights = preweights_sort(1:K) / sum(preweights_sort(1:K));
        T(drug,:,cell) = weights * squeeze(T(drug,:,idx_sort(1:K)))';
    end
end

%%% If any missing elements still remain, use Mean-1D
if length(find(isnan(T))) > 0
    T = CompleteTensorMean(T, args);
end

out = [];

end