function patches = marmosetVerificationPatches(bank)
% MARMOSETVERIFICATIONPATCHES Device codes to measure with a spectroradiometer.
%
% patches = marmoview.marmosetVerificationPatches(bank)
%
% Returns one row per unique framebuffer colour used by the condition bank
% (background plus every endpoint). Display each patch full-field (or as a
% large central patch on the calibrated background), measure its spectral
% radiance, and pass the results to marmoview.verifyMarmosetConditionSpectra.

codes = zeros(0,3);
labels = {};
for condition = bank.Conditions(:)'
    entries = {condition.BackgroundDeviceCodes,'background'; ...
        condition.NegativeDeviceCodes,[condition.ConditionID ' negative']; ...
        condition.PositiveDeviceCodes,[condition.ConditionID ' positive']};
    for ii = 1:size(entries,1)
        code = double(entries{ii,1}(:))';
        match = find(all(codes == code,2),1);
        if isempty(match)
            codes(end+1,:) = code; %#ok<AGROW>
            labels{end+1,1} = entries{ii,2}; %#ok<AGROW>
        else
            labels{match} = [labels{match} '; ' entries{ii,2}]; %#ok<AGROW>
        end
    end
end
patches = table((1:size(codes,1))',codes(:,1),codes(:,2),codes(:,3),labels, ...
    'VariableNames',{'PatchIndex','DeviceR','DeviceG','DeviceB','UsedBy'});
end
