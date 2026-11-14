function timings = setPhotodiodeTTL(S,outputs,value)
%SETPHOTODIODETTL Route photodiode TTL through the rig-configured output.

timings = [];
if isempty(outputs) || ~isfield(S,'photodiode')
    return
end

pd = S.photodiode;
if ~isfield(S,'outputs') || isempty(S.outputs)
    return
end

if ~isfield(pd,'output') || isempty(pd.output)
    [outputIndex, outputMethod] = legacyPhotodiodeOutput(S);
else
    outputIndex = find(strcmp(S.outputs,pd.output),1);
    outputMethod = '';
    if isfield(pd,'outputMethod') && ~isempty(pd.outputMethod)
        outputMethod = pd.outputMethod;
    end
end

if isempty(outputIndex) || outputIndex > numel(outputs) || isempty(outputs{outputIndex})
    return
end

bit = 4;
if isfield(pd,'outputBit') && ~isempty(pd.outputBit)
    bit = pd.outputBit;
end

outputObj = outputs{outputIndex};
switch outputMethod
    case 'flipBit'
        if ismethod(outputObj,'flipBit')
            timings = outputObj.flipBit(bit,value);
        end
    case 'flipBitNoSync'
        if ismethod(outputObj,'flipBitNoSync')
            timings = outputObj.flipBitNoSync(bit,value);
        end
    case 'datapixxDoutVideoSync'
        mask = 2^(bit-1);
        Datapixx('SetDoutValues',value*mask,mask);
        Datapixx('RegWrRdVideoSync');
    case 'flipBitVideoSync'
        if ismethod(outputObj,'flipBitVideoSync')
            try
                outputObj.flipBitVideoSync(bit,value);
            catch
                if value
                    outputObj.flipBitVideoSync(bit);
                end
            end
        end
end

end

function [outputIndex, outputMethod] = legacyPhotodiodeOutput(S)
outputIndex = find(strcmp(S.outputs,'output_datapixx2'),1);
if ~isempty(outputIndex)
    outputMethod = 'flipBitNoSync';
    return
end

outputIndex = find(strcmp(S.outputs,'output_arduino'),1);
if ~isempty(outputIndex)
    outputMethod = 'flipBit';
    return
end

outputIndex = find(strcmp(S.outputs,'output_labjackU12'),1);
if ~isempty(outputIndex)
    outputMethod = 'flipBit';
    return
end

outputIndex = find(strcmp(S.outputs,'output_datapixx'),1);
if ~isempty(outputIndex)
    outputMethod = 'datapixxDoutVideoSync';
    return
end

outputMethod = '';
end
