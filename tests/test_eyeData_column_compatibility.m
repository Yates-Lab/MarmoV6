function test_eyeData_column_compatibility
% Exercise the real online eye importer with old, new, and mixed trial widths.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'SupportFunctions','CalibrationTesting'));
Exp.S.pixPerDeg = 50;
for k = 1:2
    t = (k + (0:999)'/1000);
    eye = [t, 480+sin(t), 270+cos(t), ones(size(t)), ...
        2*ones(size(t)),t,t,t,zeros(size(t))];
    Exp.D{k} = struct('eyeData',eye,'c',[480 270],'dx',1,'dy',-1, ...
        'STARTCLOCKTIME',t(1));
end
old = import_online_eye_position(Exp);
for k = 1:2
    Exp.D{k}.eyeData(:,10) = 3;
end
new = import_online_eye_position(Exp);
assert(isequaln(old.vpx.raw,new.vpx.raw));
assert(isequaln(old.vpx.smo,new.vpx.smo));
Exp.D{1}.eyeData = Exp.D{1}.eyeData(:,1:9);
mixed = import_online_eye_position(Exp);
assert(isequaln(old.vpx.smo,mixed.vpx.smo));
fprintf('Eye importer: 9-column, 10-column, and mixed trials give identical results.\n');
end
