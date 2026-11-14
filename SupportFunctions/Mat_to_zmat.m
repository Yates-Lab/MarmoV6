function Mat_to_zmat(file)
            %cribbing from CondenseAppendedData function in MarmoView
            
            if contains(file,'MarmoV6/Output/')
                %Likely the entered name includes the folder
                A.outputFile=file;
            else
                here=pwd;
                folder_idx=strfind(here,'MarmoV6');
                assert(~isempty(folder_idx),'You should run this from within the MarmoView folder somewhere');
                A.outputFile=[here(1:(folder_idx+6)) '/Output/' file];
            end

            %******* go to outputPath and load current data
            if ~strcmp(A.outputFile,'none')  % could be in state with no open file
        
                %cd(app.outputPath);             % goto output directory
                if exist(A.outputFile,'file')
                    NewOutput = [A.outputFile(1:(end-4)),'z.mat'];
                    fprintf('Condensing data for file %s to %s\n',A.outputFile,NewOutput);
                    zdata = load(A.outputFile);    % load in all data
                    S = zdata.S;                   % get settings struct
                    D = cell(1,1);
                    ND = length(fields(zdata));      % includes all trials, minus one for S
                    for k = 1:(ND-1)
                        Dstring = sprintf('D%d',k);
                        D{k,1} = zdata.(Dstring);
                    end
                    clear zdata;
                    %********
                    save(NewOutput,'-v7.3','S','D');   % append file
                    clear D;
                    fprintf('Data file %s reformatted.\n',NewOutput);
                else
                    print('DATA FILE NOT FOUND, CHECK SPELLING')
                end
                
                %cd(app.taskPath);            % return to task directory
            end
        end