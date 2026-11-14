function bank = humanConeCheckConditionBank(calibrationSource,options)
% HUMANCONECHECKCONDITIONBANK Human L/M cone-isolating fields for the rivalry flow task.
%
% bank = marmoview.humanConeCheckConditionBank(calibrationSource,options)
%
% Uses a human ConeMath2026 calibration (cones [558 530 420]) and builds
% the same condition schema as the marmoset bank, so the rivalry protocol,
% walks, trial plan, and metrics run unchanged:
%   nullL  L and S silent: only the M cone is modulated (invisible to a deuteranope)
%   nullM  M and S silent: only the L cone is modulated (invisible to a protanope)
%   achromatic_scale_1  same Weber contrast in every cone
%   catch  both polarities equal the background
% nullL and nullM are matched: each modulates its one remaining ML cone at
% MatchedContrast.
%
% Options: AllowDummy (false), ExpectedMonitorIdentifier (''),
% MatchedContrastFraction (0.95), AchromaticContrastScales (1),
% SilentLeakageTolerance (0.005), RelativeLeakageTolerance (0.10).

if nargin < 2 || isempty(options)
    options = struct();
end
options = setDefault(options,'AllowDummy',false);
options = setDefault(options,'ExpectedMonitorIdentifier','');
options = setDefault(options,'MatchedContrastFraction',0.95);
options = setDefault(options,'AchromaticContrastScales',1);
options = setDefault(options,'SilentLeakageTolerance',0.005);
options = setDefault(options,'RelativeLeakageTolerance',0.10);

human = marmoview.loadHumanConeCalibration(calibrationSource, ...
    struct('AllowDummy',options.AllowDummy));
calibration = adaptCalibration(human,calibrationSource);
expectedMonitor = char(options.ExpectedMonitorIdentifier);
if ~isempty(expectedMonitor) && ...
        ~strcmpi(strtrim(expectedMonitor),strtrim(calibration.MonitorIdentifier))
    error('humanConeCheckConditionBank:MonitorMismatch', ...
        'Calibration monitor "%s" does not match active rig "%s".', ...
        calibration.MonitorIdentifier,expectedMonitor);
end

T = calibration.CandidateRGBToCones; % rows [L M S]
b = calibration.BackgroundLinearRGB(:);
e0 = T*b;
nulls = struct('ID',{'nullL','nullM'},'Silent',{[1 3],[2 3]}, ...
    'Remaining',{2,1},'PeakNm',{558,530});
for k = 1:2
    d = null(T(nulls(k).Silent,:));
    unit = (T*d)./e0;
    d = d/unit(nulls(k).Remaining);  % unit Weber contrast, positive sign
    nulls(k).Direction = d;
    nulls(k).SymmetricLimit = min(gamutLimit(b,d),gamutLimit(b,-d));
end
matchedContrast = options.MatchedContrastFraction*min([nulls.SymmetricLimit]);

conditions = struct([]);
for k = 1:2
    item = makeNull(calibration,nulls(k),matchedContrast,options);
    conditions = appendCondition(conditions,item);
end
for scale = double(options.AchromaticContrastScales(:)')
    contrast = scale*matchedContrast;
    if contrast > min(1,min((1-b)./b))
        error('humanConeCheckConditionBank:AchromaticGamut', ...
            'Achromatic contrast %.4g exceeds the gamut limit.',contrast);
    end
    item = makeControl(calibration,sprintf('achromatic_scale_%g',scale), ...
        'achromatic',b*(1-contrast),b*(1+contrast));
    item.AxisScale = scale;
    item.Amplitude = contrast;
    item.MatchedContrast = contrast;
    conditions = appendCondition(conditions,item);
end
item = makeControl(calibration,'catch','catch',b,b);
item.Amplitude = 0;
item.MatchedContrast = 0;
conditions = appendCondition(conditions,item);

bank = struct();
bank.SchemaVersion = 'HumanConeCheckConditionBank-1.0';
bank.CalibrationSource = calibration.CalibrationSource;
bank.CalibrationChecksum = calibration.CalibrationChecksum;
bank.MonitorIdentifier = calibration.MonitorIdentifier;
bank.CalibrationDate = calibration.CalibrationDate;
bank.IsDummyCalibration = calibration.IsDummyCalibration;
bank.ConePeaksNm = calibration.CandidateConePeaksNm;
bank.DiagnosticNullPeaksNm = [558 530];
bank.ConditionDescriptions = struct( ...
    'nullL','L and S silent: M cone only (a deuteranope should not see it)', ...
    'nullM','M and S silent: L cone only (a protanope should not see it)');
bank.BackgroundLinearRGB = b';
bank.BackgroundLuminanceCdM2 = calibration.BackgroundLuminanceCdM2;
bank.MatchedContrast = matchedContrast;
bank.MatchedContrastFraction = options.MatchedContrastFraction;
bank.ContrastLevels = 1;
bank.SilentLeakageTolerance = options.SilentLeakageTolerance;
bank.RelativeLeakageTolerance = options.RelativeLeakageTolerance;
bank.NomogramModel = [];
bank.RodPeakNm = NaN;
bank.Conditions = conditions;
end


function calibration = adaptCalibration(human,source)
% Fields expected by the shared condition template and realizeCalibratedRGB.
calibration = struct();
calibration.CalibrationSource = human.Source;
if isfield(human,'CalibrationChecksumSHA256') && ~isempty(human.CalibrationChecksumSHA256)
    calibration.CalibrationChecksum = char(human.CalibrationChecksumSHA256);
elseif ischar(source) || isstring(source)
    calibration.CalibrationChecksum = fileChecksum(char(source));
else
    calibration.CalibrationChecksum = 'UNSPECIFIED';
end
calibration.MonitorIdentifier = textField(human,'MonitorIdentifier','unknown');
calibration.CalibrationDate = textField(human,'CalibrationDate','unknown');
calibration.CandidateConePeaksNm = human.ConePeaks(:)';
calibration.CandidateRGBToCones = human.RGBToCones;
calibration.BackgroundLinearRGB = human.BackgroundLinearRGB(:)';
calibration.ExportedBackgroundLinearRGB = human.BackgroundLinearRGB(:)';
% CIE Y in cd/m2 only when the spectra are absolute radiance.
calibration.BackgroundLuminanceCdM2 = 683*human.PhotopicLuminanceRGB(:)'* ...
    human.BackgroundLinearRGB(:);
calibration.RodPeakNm = NaN;
calibration.BitDepth = human.BitDepth;
calibration.GammaApplication = human.GammaApplication;
calibration.GammaDeviceInput = human.GammaDeviceInput;
calibration.GammaLinearOutput = human.GammaLinearOutput;
calibration.IsDummyCalibration = human.IsDummyCalibration;
end


function condition = makeNull(calibration,spec,contrast,options)
b = calibration.BackgroundLinearRGB(:);
d = spec.Direction;
condition = makeControl(calibration,[spec.ID '_scale_1'],'pigment-null', ...
    b-contrast*d,b+contrast*d);
silentRealized = condition.RealizedConeContrast(:,spec.Silent);
condition.NullPeakNm = spec.PeakNm;
condition.NominalNullPeakNm = spec.PeakNm;
condition.SilentConeIndices = spec.Silent;
condition.MaximumSilentLeakage = max(abs(silentRealized),[],'all');
condition.SignalContrast = min(abs(condition.RealizedConeContrast(:,spec.Remaining)));
condition.RelativeSilentLeakage = condition.MaximumSilentLeakage/ ...
    max(eps,condition.SignalContrast);
condition.PositiveGamutLimit = gamutLimit(b,d);
condition.NegativeGamutLimit = gamutLimit(b,-d);
condition.MaximumSymmetricAmplitude = spec.SymmetricLimit;
condition.AxisScale = 1;
condition.Amplitude = contrast;
condition.MatchedContrast = contrast;
condition.UnitRGBDirection = d';
if max(abs(condition.RequestedConeContrast(:,spec.Silent)),[],'all') > 1e-10
    error('humanConeCheckConditionBank:Silence','Requested silence failed for %s.',spec.ID);
end
if condition.MaximumSilentLeakage > options.SilentLeakageTolerance || ...
        condition.RelativeSilentLeakage > options.RelativeLeakageTolerance
    error('humanConeCheckConditionBank:SilentLeakage', ...
        '%s realized leakage %.4g (%.3g of signal) exceeds tolerance.', ...
        spec.ID,condition.MaximumSilentLeakage,condition.RelativeSilentLeakage);
end
end


function condition = makeControl(calibration,id,type,negativeRGB,positiveRGB)
T = calibration.CandidateRGBToCones;
b = calibration.BackgroundLinearRGB(:);
if any([negativeRGB; positiveRGB] < -1e-10 | [negativeRGB; positiveRGB] > 1+1e-10)
    error('humanConeCheckConditionBank:Gamut','%s endpoint is outside gamut.',id);
end
negativeRGB = min(max(negativeRGB,0),1);
positiveRGB = min(max(positiveRGB,0),1);
realized = marmoview.realizeCalibratedRGB(calibration,[b';negativeRGB';positiveRGB']);
realizedLinear = realized.RealizedLinearRGB';
condition = marmoview.marmosetPigmentNullTemplate(calibration);
condition.ConditionID = id;
condition.ConditionType = type;
condition.NegativeLinearRGB = negativeRGB';
condition.PositiveLinearRGB = positiveRGB';
condition.BackgroundDeviceCodes = realized.DeviceCodes(1,:);
condition.NegativeDeviceCodes = realized.DeviceCodes(2,:);
condition.PositiveDeviceCodes = realized.DeviceCodes(3,:);
condition.BackgroundFramebufferRGB255 = realized.FramebufferRGB255(1,:);
condition.NegativeFramebufferRGB255 = realized.FramebufferRGB255(2,:);
condition.PositiveFramebufferRGB255 = realized.FramebufferRGB255(3,:);
condition.RealizedBackgroundLinearRGB = realized.RealizedLinearRGB(1,:);
condition.RealizedNegativeLinearRGB = realized.RealizedLinearRGB(2,:);
condition.RealizedPositiveLinearRGB = realized.RealizedLinearRGB(3,:);
condition.RequestedConeContrast = (((T*[negativeRGB positiveRGB])-T*b)./(T*b))';
condition.RealizedConeContrast = (((T*realizedLinear(:,2:3))- ...
    T*realizedLinear(:,1))./(T*realizedLinear(:,1)))';
condition.MaximumSilentLeakage = 0;
condition.ValidationPass = true;
end


function limit = gamutLimit(background,direction)
limits = inf(3,1);
positive = direction > 1e-14;
negative = direction < -1e-14;
limits(positive) = (1-background(positive))./direction(positive);
limits(negative) = background(negative)./(-direction(negative));
limit = min(limits);
end


function value = textField(source,name,fallback)
if isfield(source,name) && ~isempty(source.(name))
    value = char(source.(name));
else
    value = fallback;
end
end


function checksum = fileChecksum(filename)
file = fopen(filename,'rb');
if file < 0
    checksum = 'UNSPECIFIED';
    return
end
bytes = fread(file,inf,'*uint8');
fclose(file);
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(typecast(bytes,'int8'));
checksum = lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
end


function conditions = appendCondition(conditions,item)
if isempty(conditions)
    conditions = item;
else
    conditions(end+1) = item;
end
end


function value = setDefault(value,name,defaultValue)
if ~isfield(value,name) || isempty(value.(name))
    value.(name) = defaultValue;
end
end
