classdef (Abstract) output < matlab.mixin.Copyable & handle
    % Abstract class for a marmoview output (e.g., datapixx)

    properties (Abstract)

    end % properties

    methods
        function o = output(varargin)

        end

        function init(~)
        end

        function strobe(~)
        end

    end
end