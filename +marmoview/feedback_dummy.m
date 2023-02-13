% a minimal instantiation of the @liquid interface
%
% an @dbgreward object produced sound rather deliver a liquid reward...
% this can be useful when debugging reward delivery or can be used when a
% rig has no mechanism for delivering liquid rewards, e.g., because you're
% developing or debugging your stimulus on your laptop

% 30-05-2016 - Shaun L. Cloherty <s.cloherty@ieee.org>

classdef feedback_dummy < marmoview.feedback_liquid & marmoview.feedback_sound
    properties
        volume double = 0.0
    end
    
    methods
        function o = feedback_dummy(h,varargin)
            o = o@marmoview.feedback_liquid(h);
            o = o@marmoview.feedback_sound(h);
        end
        
        function deliver(o)
            o.deliver@marmoview.feedback_sound();
        end
        
        function r = report(o)
            r = struct([]);
        end
    end
end
