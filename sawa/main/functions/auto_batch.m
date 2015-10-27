function varargout = auto_batch(cmd,varargin)
% varargout = auto_batch(cmd,varargin)
% This function will allow you to set arguments for the command line function
% funname and then run the function.
%
% Inputs:
% cmd - command to use (i.e. 'add_funciton','set_options','auto_run')
% varargin - arguments to be passed to cmd
%
% Outputs: 
% fp - funpass struct containing variables from call cmd(varargin)
%
% Example:
% funcs = matlabbatch;
% options{1,1}(1:4,1) = {'test1','test2','test3','test4'};
% itemidx{1}(1) = 3;
% rep{1}(1) = 0;
% funrun = 1:4;
% fp = struct('funcs',{funcs},'options',{options},'itemidx',{itemidx},'rep',{rep},...
% 'funrun',{funrun});
% fp = auto_batch('run_batch',fp)
%
% requires: choose_fields choose_spm closedlg funpass printres 
% sawa_createvars sawa_evalchar sawa_evalvars sawa_find 
% sawa_savebatchjob sawa_setbatch sawa_setdeps sawa_setfield 
% sawa_setupjob sawa_strjoin settimeleft subidx
%
% Created by Justin Theiss

% init vars
if ~exist('cmd','var')||isempty(cmd), cmd = {'add_function','set_options','auto_run'}; end;
if ~iscell(cmd), cmd = {cmd}; end; 
if isempty(varargin), varargin = {struct}; end;
% run chosen cmds
for x = 1:numel(cmd), varargin{1} = feval(cmd{x},varargin{:}); end;
% output
if ~iscell(varargin{1}), varargin{1} = varargin(1); end;
varargout = varargin{1};

% callback functions
function fp = add_function(fp)
% create vars from fp
funpass(fp,{'funcs','itemidx','str','sawafile','sa','subrun'});
% init vars
if ~exist('funcs','var'), funcs = {}; end;
if ~exist('sa','var'), sa = {}; end; 
if ~exist('subrun','var'), subrun = []; end;
if ~exist('sawafile','var'), sawafile = []; end;

% choose spm ver
spmver = choose_spm;

% run setupjob
disp('Loading matlabbatch job...'); 
% load matlabbatch with sawa_setupjob
if ~isempty(funcs), 
[funcs,itemidx,str]=sawa_setupjob(funcs,itemidx,str);
else % create new job
[funcs,itemidx,str]=sawa_setupjob;
end

try % get job/module ids 
[~,cjob,mod_ids] = evalc('cfg_util(''initjob'',funcs)'); 
catch err
disp(err.message); set(findobj('tag','setup batch job'),'string','Empty'); return; 
end

% get names
for m = 1:numel(funcs)
[~,~,contents{m}]=cfg_util('listmod',cjob,mod_ids{m},[],cfg_findspec({{'hidden',false}}),...
    cfg_tropts({{'hidden',true}},1,inf,1,inf,false),{'name','all_set_item'});
itemnames{m} = contents{m}{1}; names{m} = contents{m}{1}{1};
end

% save folder
jobsavfld = uigetdir(cd, 'Choose a folder to save the job(s) for this function. Click cancel to choose a subject field (e.g., subjFolders)');
try % if no folder chosen, ask to choose fields
if ~any(jobsavfld), jobsavfld = strcat('sa(i).',subidx(choose_fields(sa,subrun,'Choose a field to save jobs folder:'),'{1}')); end; 
if strcmp(jobsavfld,'sa(i).'), jobsavfld = []; disp('Will not save jobs.'); end; % if didn't choose a field
catch err % if no jobsavfld, empty and disp warning
jobsavfld = []; disp(['Will not save jobs: ' err.message]);
end;

% job name
if isempty(sawafile) % enter job name
jobname = cell2mat(inputdlg('Enter a name to save the job (e.g., FirstLevelAnalysis):'));
elseif ~exist('jobname','var')||isempty(jobname) % set jobname to sawafile
[~,jobname] = fileparts(sawafile);
jobname = cell2mat(inputdlg('Enter a name to save the job:','Job Name',1,{jobname}));
if isempty(jobname), [~,jobname] = fileparts(sawafile); end;
else % otherwise allow edit
tmpname = cell2mat(inputdlg('Enter a name to save the job:','Job Name',1,{jobname}));
if ~isempty(tmpname), jobname = tmpname; end; clear tmpname;
end

% check if complete
job_sts = 'Complete';
for m = 1:numel(funcs), 
if ~all(cell2mat(contents{m}{2}(~ismember(1:numel(contents{m}{2}),itemidx{m})))), 
job_sts = 'Incomplete'; break; % if any not set (other than itemidx), incomplete
end
end

% set job status
set(findobj('tag','setup batch job'),'tooltipstring',[jobname ': ' job_sts]);
% set batch_listbox
set(findobj('tag','batch_listbox'),'value',1);
set(findobj('tag','batch_listbox'),'string',names);

% save or run?
if ~isempty(jobsavfld), 
saveorrun = questdlg('Save jobs or run jobs?','Save or Run','Save','Run','Run');
else % can't save
saveorrun = 'Run';    
end

% overwrite previous data? (for spm jobs only)
if any(sawa_find(@isfield,'spm',funcs,'',''))
overwrite = questdlg('Overwrite previous SPM files? (if applicable)','Overwrite','Yes','No','No');
end

% set vars to fp
fp = funpass(fp,{'spmver','funcs','itemidx','str','names','jobsavfld','jobname','saveorrun','overwrite'});
return;

function fp = set_options(fp)
% get vars from fp
funpass(fp,{'funcs','idx','itemidx','options','sa','subrun','funrun','iter'});

% init vars
if ~exist('funcs','var'), return; elseif ~iscell(funcs), funcs = {funcs}; end;
if ~exist('idx','var'), idx = get(findobj('tag','batch_listbox'),'value'); end;
if isempty(idx)||idx==0, idx = 1; end;
if ~exist('itemidx','var'), return; elseif ~iscell(itemidx), itemidx{idx} = itemidx; end;
if ~exist('options','var')||idx>numel(options), options(idx,1:numel(itemidx{idx})) = {{}}; end;
if ~exist('sa','var'), sa = {}; end; if ~exist('subrun','var'), subrun = []; end;
if ~exist('funrun','var'), if isempty(subrun), funrun = []; else funrun = subrun; end; end;
if ~exist('iter','var'), if isempty(subrun), iter = funrun; else iter = 1; end; end;

try % get job/module ids 
[~,cjob,mod_ids] = evalc('cfg_util(''initjob'',funcs)'); 
catch err
disp(err.message); set(findobj('tag','Setup Batch Job'),'string','Empty'); return; 
end

% get id, contents, and names
[id,~,contents]=cfg_util('listmod',cjob,mod_ids{idx},[],cfg_findspec({{'hidden',false}}),...
cfg_tropts({{'hidden',true}},1,inf,1,inf,false),{'name','class','level'});
itemnames{idx} = contents{1}(itemidx{idx});

% if empty itemidx, skip
if ~isempty(itemidx{idx}), 

% set options for chosen itemidx
for v = listdlg('PromptString','Choose items to set:','ListString',itemnames{idx});
    % get index of cfg_repeat or set to itemidx
    rep_idx = subidx(find(strcmp(contents{2}(1:itemidx{idx}(v)),'cfg_repeat')),'(end)');
    if isempty(rep_idx), rep_idx = itemidx{idx}(v); end;
    
    % get repeat contents
    [~,~,repcon]=cfg_util('listmod',cjob,mod_ids{idx},id{rep_idx},cfg_findspec({{'name',itemnames{idx}{v}}}),...
    cfg_tropts({{'hidden',true}},1,inf,1,inf,false),{'name'});
    
    % set default index
    defidx = 1:numel(repcon{1}); if isempty(defidx), defidx = 1; end;
    if numel(defidx) > 1, defidx = defidx(find(strcmp(itemnames{idx},itemnames{idx}{v}))==v); end;

    % find parents of itemidx
    itempar = [];
    try
    p = find(ismember(contents{2}(1:itemidx{idx}(v)),'cfg_repeat'));
    p = p(cell2mat(contents{3}(p))<contents{3}{itemidx{idx}(v)});
    itempar = contents{1}(p);
    end
    
    % choose parents to replicate
    if ~isempty(itempar)
        pchc = listdlg('PromptString',{['Choose components of ' itemnames{idx}{v}...
            ' ' num2str(defidx) ' to replicate (cancel if not replicating)'],'','',''},...
            'ListString',itempar,'selectionmode','single');
    else
        pchc = []; 
    end
    
    % set rep
    if isempty(pchc), rep{idx}(v) = 0; else rep{idx}(v) = p(pchc); end;
    
    % empty options 
    options{idx,v} = repmat({{}},[numel(iter),1]);
    
    % set message
    if numel(iter) > 1||isempty(funrun), msg = '(cancel when finished)'; else msg = ''; end;
    
    % create val
    clear val; val = sawa_createvars([itemnames{idx}{v} ' ' num2str(defidx)],msg,subrun,sa);

    % set funrun if empty 
    if isempty(funrun), funrun = 1:size(val,1); iter = funrun; end;

    % prep val
    if numel(iter)==1||~iscell(val)||numel(iter)~=numel(val), val = {val}; end;

    % set to options
    options{idx,v}(iter,1) = sawa_setfield(options{idx,v},iter,[],[],val{:});
end
end

% set vars to fp
fp = funpass(fp,{'funrun','funcs','options','rep'});
return;

function fp = auto_run(fp)
% get vars from fp
funpass(fp);

% init vars
if ~exist('funcs','var')||isempty(funcs), return; elseif ~iscell(funcs), funcs = {funcs}; end;
if ~exist('itemidx','var'), return; elseif ~iscell(itemidx), itemidx{idx} = itemidx; end;
if ~exist('options','var'), options(1:numel(funcs),1:max(cellfun('size',itemidx,2))) = {repmat({{}},[numel(iter),1])}; end;
if ~exist('sa','var'), sa = {}; end; if ~exist('subrun','var'), subrun = []; end;
if ~exist('funrun','var')||isempty(funrun), if isempty(subrun), funrun = 1; else funrun = subrun; end; end;
if isempty(subrun), iter = funrun; else iter = 1; end;
if isempty(sa), subjs = arrayfun(@(x){num2str(x)},funrun); [sa(funrun).subj] = deal(subjs{:}); end;
if ~exist('saveorrun','var'), saveorrun = 'Run'; end;
if ~exist('overwrite','var'), overwrite = 'No'; end;
if ~exist('hres','var'), hres = []; end;
if ~exist('jobsavfld','var'), jobsavfld = []; end;
if ~exist('sawafile','var')||isempty(sawafile), sawafile = 'Batch Editor'; end;
if ~exist('jobname','var')||isempty(jobname), [~, jobname] = fileparts(sawafile); end;

% ensure correct spmver
if exist('spmver','var'), spmver = choose_spm(spmver); else spmver = spm('ver'); end;

% print spmver
if ~isempty(spmver), printres(['SPM version: ' spmver],hres); end;

% get matlabbatch from funcs and set preidx
matlabbatch = funcs; preidx = itemidx;

% get updated job id and mod ids 
[~,cjob,mod_ids] = evalc('cfg_util(''initjob'',matlabbatch)');

% get names
for m = 1:numel(funcs)
[~,~,contents{m}]=cfg_util('listmod',cjob,mod_ids{m},[],...
cfg_findspec({{'hidden',false}}),cfg_tropts({{'hidden',true}},1,inf,1,inf,false),{'name','val','all_set_item'});
itemnames{m} = contents{m}{1};
end

% set options, names, itemidx, rep, iter, sa, and hres
fp = funpass(fp,{'options','itemnames','itemidx','rep','iter','sa','hres'});

% print current variables
for m = 1:numel(matlabbatch)
prntidx = ~ismember(1:numel(itemnames{m}),itemidx{m});
% print itemnames and string rep of values for non-itemidx
cellfun(@(x,y){printres([x ': ' sawa_strjoin(y,'\n')],hres)},itemnames{m}(prntidx),contents{m}{2}(prntidx));
end; % print variables to input
printres('Variables to input:',hres);
for m = find(~cellfun('isempty',preidx)), 
cellfun(@(x,y){printres([x ': ' sawa_strjoin(y,'\n')],hres)},itemnames{m}(~prntidx),options(m,1:numel(itemidx{m})));
end;
printres(repmat('-',1,75),hres); 

% set warning off
warning('off'); 

% set time left
wb = settimeleft;

% for each subrun
for i = funrun
    try % print subject
    printres(sa(i).subj,hres);

    % for each module
    for m = find(~cellfun('isempty',preidx))
        % set matlabbatch
        matlabbatch = local_setbatch(fp,matlabbatch,m,i);
    end
    
    % set dependencies
    matlabbatch = sawa_setdeps(funcs,matlabbatch); 
    
    % check if able to run
    [~,cjob] = evalc('cfg_util(''initjob'',matlabbatch)');
    clear run; [~,~,run] = cfg_util('showjob',cjob);
    
    % run cfg_util
    if all(run) && strcmp(saveorrun,'Run')
    
    % if overwriting, set str to continue, otherwise stop (if applicable)
    if strcmpi(overwrite,'yes'), str = 'continue'; else str = 'stop'; end;
    % close dlg if opens
    closedlg({'-regexp','tag',spm('ver')},{'string',str});
    
    % run serial
    cfg_util('runserial',matlabbatch); 
    
    elseif ~all(run) % if can't run, print reason
    printres('Could not run. Empty components:',hres);
    for m = find(~run)
        printres([itemnames{m}{1} ': ' sawa_strjoin(itemnames{m}(~cell2mat(contents{m}{3})),', ')], hres);
    end
    end
    
    % set time left
    settimeleft(i, funrun, wb, ['Running ' jobname ' ' sa(i).subj]);
    
    catch err % error, print message
    printres(['Error ' jobname ' ' sa(i).subj ': ' err.message],hres);
    end
    
    % save matlabbatch job
    if ~isempty(jobsavfld)
    clear jobsave; jobsave = sawa_evalchar(jobsavfld); 
    jobsave = sawa_savebatchjob(jobsave,jobname,matlabbatch);
    printres(['Saving job to ' jobsave],hres); 
    end
end
return;

function matlabbatch = local_setbatch(fp,matlabbatch,m,i)
% get vars from fp
funpass(fp,{'options','itemidx','sa','iter','rep'});

% set prebatch in case removing components/subjects
prebatch = matlabbatch;

% for each itemidx
for mx = 1:numel(itemidx{m})
% set subject cell
if numel(iter) > 1, s = i; else s = 1; end;

% evalvars
valf{mx} = sawa_evalvars(options{m,mx}{s});

% if any empty with group, remove subject
if iscell(valf{mx})&&all(cellfun('isclass',valf{mx},'char'))&&any(cellfun('isempty',valf{mx}))
n = cellfun('isempty',valf{mx})'; n = regexprep(options{m,mx}{s}(n),'.*sa\(([\d\w]+\)\..*','$1');
printres(['Missing ' itemnames{m}{mx} ' for subject(s) ' sawa_strjoin(sa(str2double(n)).subj,'\n')],hres);
% remove from others
for r = 1:size(options,2), 
    if isempty(options{m,mx}), continue; end;
    options{m,mx}{s} = regexprep(options{m,mx}{s},strcat('.*sa\(',n,'\)\..*'),'');
    options{m,mx}{s}(cellfun('isempty',options{m,mx}{s})) = [];
end
end
end

% set for each itemidx
for mx = 1:numel(itemidx{m}),
% set items
[matlabbatch,chngidx,sts] = sawa_setbatch(matlabbatch,valf{mx},itemidx{m}(mx),rep{m}(mx),m);

% if itemidx changes due to repeat, change others in module
if abs(chngidx)>0, itemidx{m}(mx:end)=itemidx{m}(mx:end)+chngidx; end;

% if no repeat, skip
if rep{m}(mx) == 0, continue; end;

% if failed to set vals in repeat
for x = find(~sts), printres(['Could not set vals for ' itemnames{m}{mx} ' ' num2str(x)],hres); end;
for x = find(rep{m}==rep{m}(mx)), % print and remove
    printres(['Removing ' itemnames{m}{x} ' ' sawa_strjoin(find(~sts),', ')],hres); 
    val{x}(~sts) = []; % remove repeat
end

% re-run local_setbatch
fp = funpass(fp,{'options'});
if any(~sts), matlabbatch = local_setbatch(fp,prebatch,m,i); return; end;
end
return;
