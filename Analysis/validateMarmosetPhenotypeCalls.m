function report = validateMarmosetPhenotypeCalls(calls,genotypes)
% VALIDATEMARMOSETPHENOTYPECALLS Compare blinded phenotype calls with genotype.
%
% report = validateMarmosetPhenotypeCalls(calls,genotypes)
%
% calls:     table with AnimalID and Classification (from
%            analyzeMarmosetConePhenotypeFlow, produced without genotype).
% genotypes: table with AnimalID and Phenotype, using the same labels
%            (D_543, D_556, D_563, T_543_556, T_556_563, T_543_563).
%
% Keep this step separate from fitting so genotype cannot leak into it.

labels = {'D_543','D_556','D_563','T_543_556','T_556_563','T_543_563'};
joined = innerjoin(calls(:,{'AnimalID','Classification'}), ...
    genotypes(:,{'AnimalID','Phenotype'}),'Keys','AnimalID');
called = ~strcmp(joined.Classification,'unclassified');
confusion = zeros(numel(labels),numel(labels)+1);
for ii = 1:height(joined)
    truth = find(strcmp(labels,joined.Phenotype{ii}));
    if isempty(truth)
        error('validateMarmosetPhenotypeCalls:UnknownGenotype', ...
            'Unknown genotype label "%s".',joined.Phenotype{ii});
    end
    prediction = find(strcmp(labels,joined.Classification{ii}));
    if isempty(prediction)
        prediction = numel(labels)+1;
    end
    confusion(truth,prediction) = confusion(truth,prediction)+1;
end

report = struct();
report.Labels = labels;
report.ConfusionMatrix = array2table(confusion,'RowNames',labels, ...
    'VariableNames',[labels {'unclassified'}]);
report.AnimalCount = height(joined);
report.CalledCount = nnz(called);
report.UnclassifiedFraction = mean(~called);
report.AccuracyAmongCalled = mean(strcmp(joined.Classification(called), ...
    joined.Phenotype(called)));
isDichromat = @(label) startsWith(label,'D_');
report.DichromatTrichromatAgreement = mean(isDichromat( ...
    joined.Classification(called)) == isDichromat(joined.Phenotype(called)));
report.Details = joined;
end
