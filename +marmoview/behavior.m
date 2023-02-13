% abstract class for eyetrackers

classdef (Abstract) behavior < matlab.mixin.Copyable & handle
    %******* basically is just a wrapper for a dummy eyetracker
    %

    properties (Abstract)

    end % properties

    methods
        function o = behavior(varargin)

        end

        function init(~)
        end

        function startfile(~)
            % no file is saved if using mouse
        end

        function closefile(~)
        end

        function unpause(~)
        end

        function pause(~)
        end

        function endtrial(~)
        end

        function sendcommand(~)
        end

    end % methods

end % classdef
