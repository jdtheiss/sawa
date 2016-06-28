function fp = sawa_editor(cmd,varargin)
% sawa_editor(sawafile, sv, savedvars)
% Loads/runs sawafile functions (e.g., auto_batch, auto_cmd, auto_function) with
% make_gui.
%
% Inputs: 
% cmd - function to be called (i.e. 'load_sawafile','set_environments',
% 'choose_subjects','add_function','set_options','save_presets', or 'loadsaverun')
% varargin - arguments to be sent to call of cmd (in most cases, the
% funpass struct of variables to use with fieldnames as variable names)
%
% Outputs:
% fp - funpass struct containing various output variables
%
% Note: default cmd is 'load_sawafile', and the sawa file to be loaded should
% be a .mat file with the following varaibles (created during call to save_presets): 
% - structure - the make_gui structure that will be used
% - fp - funpass structure with "sawafile", "funcs", and "options"
% sawafile is the fullpath to this .mat file, funcs is a cellstr of
% functions to run, and options is a cell array of options to use with
% funcs (must be equal in size to funcs).
% - program - string name of the program to run (e.g., 'auto_batch')
% See Batch_Editor.mat, Command_Line.mat, Wrap_Functions.mat for examples.
% Note2: if an output exists in fp, output will be assigned in the base
% workspace.
%
% requires: make_gui funpass printres sawa_subrun
%
% Created by Justin Theiss

% init vars
if ~exist('cmd','var'), cmd = 'load_sawafile'; end;
if ~iscell(cmd), cmd = {cmd}; end;
if isempty(varargin),
varargin = {'wrapper_automation.mat'}; 
if ~exist(varargin{1},'file')==2,
disp('Choose sawa file to load');
[fl,pt] = uigetfile('*.mat','Choose sawa file to load:');
if ~any(fl), return; end;
varargin{1} = fullfile(pt,fl); 
end
end

% for each cmd, run
for x = 1:numel(cmd), fp = feval(cmd{x},varargin{:}); end;

% load sawafile and run make_gui
function fp = load_sawafile(varargin)
% fp = load_sawafile(fp)
% fp = load_sawafile(sawafile,sv,savedvars)

% init fp/sawafile
if isstruct(varargin{1}), fp = varargin{1}; funpass(fp); else sawafile = varargin{1}; end;

% set sv, savedvars
vars = {'sv','savedvars'};
arrayfun(@(x)assignin('caller',vars{x-1},varargin{x}),2:nargin);
    
% load sawafile
load(sawafile,'structure');  

% init other vars if not already
if ~exist('funcs','var'), funcs = {}; end;
if ~exist('options','var'), options = {}; end;
if ~exist('sv','var')||isempty(sv), sv = 0; end;
if ~exist('savedvars','var'), savedvars = ''; end;
if ~exist('fp','var'), fp = struct; end;

% load savedvars
if ~isempty(savedvars)&&sv, load(savedvars,'fp'); funpass(fp,{'~sv','~savedvars'}); end;

% set sawafile, sv, and savedvars to fp
fp = funpass(fp,{'funcs','options','sawafile','sv','savedvars'});

% get vars from fp
funpass(fp);

% set path/environment
fp = set_new_environments(fp);

% set structure.listbox.string to funcs
if exist('structure','var'),
    if ~exist('names','var'), names = funcs; end;
    structure.listbox.string = names; 
end

% run make_gui if all inputs (otherwise output fp structure)
if ~sv
fp = make_gui(structure,struct('data',fp));  
elseif sv % using savedvars
fp = loadsaverun(fp,'run');    
end

% reset path/environment
fp = set_init_environments(fp);

% if savedvars and not sv, save savedvars
if ~isempty(savedvars)&&~sv, fp = loadsaverun(fp,'save'); end;
return;

% set environment if needed
function fp = set_environments(fp)
% get vars from fp
funpass(fp);

% init vars
if ~exist('setfun','var')||~exist('newpath','var')||~exist('getfun','var'), 
    setfun = {}; newpath = {}; getfun = {};
end;
if ~exist('initpath','var'), initpath = {}; end;
ck = 1; % cell to check

% choose envchcs
choices = {'setenv','path','javaclasspath'};
clear chc; chc = listdlg('PromptString',{'Select method to set environment/add path:',''},'ListString',choices,'selectionmode','single');
if isempty(chc), return; end;

% set to choice
setfun{end+1,1} = choices{chc};
getfun{end+1,1} = choices{chc};
newpath{end+1,1} = [];

% if setenv, enter env
if strcmp(setfun{end,1},'setenv'),
    setfun{end,2} = cell2mat(inputdlg('Enter environment to set (e.g., PATH)'));
    if isempty(setfun{end,2}), return; end;
    getfun(end,1:2) = {'getenv',setfun{end,2}}; 
    if ispc, sep = ';'; else sep = ':'; end;
    ck = 2; % set cell to check to 2
end

% clear path or append?
clrvar = questdlg('Clear or append?','Clear or Append','clear','append','append');

% set new path
newpath{end,1} = 'char'; % set to char initially
newpath{end,2} = sawa_createvars(setfun{end,1});
if isempty(newpath{end,2}), return; end;

% if not clearing
if ~strcmp(clrvar,'clear'), % if not clearing, set to getenv sep newpath 2
switch setfun{end,1}
    case 'setenv'
    newpath{end,1} = 'eval'; % set newpath 1 to eval
    newpath{end,2} = ['[getenv(''' setfun{end,2} ''') ''' sep newpath{end,2} ''']'];
    case 'path'
    setfun{end,1} = 'addpath';
    case 'javaclasspath'
    setfun{end,1} = 'javaaddpath';
end
end

% get initial paths
if numel(find(strcmp(setfun(:,ck),setfun{end,ck})))==1, % new, get init
    initpath{end+1} = feval(getfun{end,~cellfun('isempty',getfun(end,:))});
else % already done, use previous
    initpath{end+1} = initpath{find(strcmp(setfun(:,1),setfun{end,1}),1)};
end

% set new paths
try feval(setfun{end,~cellfun('isempty',setfun(end,:))},feval(newpath{end,:})); catch, return; end; 

% set setfun and newpath to fp 
fp = funpass(fp,{'setfun','newpath','getfun','initpath'});
return;

% set new environment
function fp = set_new_environments(fp)
% get vars from fp
funpass(fp,{'setfun','newpath','getfun'});

% if no setfun or newpath, return
if ~exist('setfun','var')||~exist('newpath','var')||~exist('getfun','var'), return; end;

% get initial paths
initpath = cell(1,numel(getfun));
for x = 1:size(getfun,1), initpath{x} = feval(getfun{x,~cellfun('isempty',getfun(x,:))}); end;

% set new paths 
for x = 1:size(setfun,1), feval(setfun{x,~cellfun('isempty',setfun(x,:))},feval(newpath{x,:})); end; 

% add initpath to fp
fp = funpass(fp,'initpath');
return;

% set init environment
function fp = set_init_environments(fp)
% get vars from fp
funpass(fp,{'setfun','initpath'});

% if no setfun or initpath, return
if ~exist('setfun','var')||~exist('initpath','var'), return; end;

% for each setfun, return to initial path
for x = 1:size(setfun,1), feval(setfun{x,~cellfun('isempty',setfun(x,:))},initpath{x}); end;

% remove initpath from fp
fp = rmfield(fp,'initpath');
return;

% choose subjects 
function fp = choose_subjects(fp)
% create vars from fp
funpass(fp); 

% get subrun, sa, task, fileName
[subrun,sa,task,fileName] = sawa_subrun;

% run per subject or iterations
if ~isempty(subrun)
runiter = questdlg('Run per subject or iterations?',...
    'Per Subject/Iterations','per subject','iterations','per subject');
end

% set funrun based on runiter
if exist('runiter','var')&&strcmp(runiter,'per subject')
% if per subject set to subrun
funrun = subrun; % set to subrun
toolstr = [task ': ' num2str(numel(subrun)) ' subjects']; 
else % set to iterations
funrun = 1:str2double(cell2mat(inputdlg('Enter number of iterations to run')));
subrun = [];
toolstr = [num2str(numel(funrun)) ' iterations'];
end 

% set tooltipstring
set(findobj('tag','choose subjects'),'tooltipstring',toolstr);

% set vars to fp
fp = funpass(fp,{'subrun','sa','task','fileName','funrun'});
return;

% add function to list
function fp = add_function(fp)
% create vars from fp
funpass(fp);

% get auto_ programs in main
d = dir(fullfile(fileparts(mfilename('fullpath')),'auto_*.m'));

% set idx
if ~exist('funcs','var'), funcs = {}; end;
fp.idx = numel(funcs)+1; 

% choose program to use
chc = listdlg('PromptString','Choose program to use:','ListString',{d.name},'SelectionMode','single');
if isempty(chc), return; end;

% get program name
[~,prog] = fileparts(d(chc).name);

% run program's add_function
fp = feval(prog,'add_function',fp);

% set names
try set(findobj('-regexp','tag','_listbox'),'string',fp.names); catch; return; end;
return;

% set options for function
function fp = set_options(fp)
% create vars from fp
funpass(fp);

% if no funcs, return
if ~exist('funcs','var')||isempty(funcs), return; end;

% get idx from listbox
idx = get(findobj('-regexp','tag','_listbox'),'value'); fp.idx = idx;

% if no program, get program
if ~exist('program','var')||idx > numel(program)
    % get auto_ programs in main
    d = dir(fullfile(fileparts(mfilename('fullpath')),'auto_*.m'));

    % choose program to use
    chc = listdlg('PromptString','Choose program to use:','ListString',{d.name},'SelectionMode','single');
    if isempty(chc), return; end;
    
    % set program name
    [~,program{idx}] = fileparts(d(chc).name);
end
    
% set names
set(findobj('-regexp','tag','_listbox'),'string',fp.names);

% run program's set_options
fp = feval(program{idx},'set_options',fp);
return;

% save the preset values
function fp = save_presets(fp)
% get vars from fp
funpass(fp);

% set name
[savefile,savepath] = uiputfile('*.mat','Save file as:');
if ~any(savefile), return; end;

% set fp
fp = funpass(fp,{'names','funcs','options'});

% set structure
load(sawafile,'structure');

% set sawafile
sawafile = fullfile(savepath,savefile);

% set sawafile to fp
fp = funpass(fp,'sawafile');

% set name to structure
[~,structure.name] = fileparts(savefile);

% set funcs to listbox
if ~exist('names','var'), names = funcs; end;
structure.listbox.string = names;

% enter helpmsg
helpmsg = char(textwrap(inputdlg(['Enter "help message" for ' savefile],'help message',[2,75]),75));

% save
save(sawafile,'structure','fp','program','helpmsg');
return;

% listbox callback for copy/delete/insert
function fp = listbox_callback(fp,fx,x)

% if not right click
if ~strcmp(get(fx,'selectiontype'),'alt'), return; end;

% get vars from fp
chngvars = {'funcs','names','options','program','itemidx','str','rep','itemnames','vars','output','outchc'};
funpass(fp,chngvars);

% if no funcs, fx, or x, return
if ~exist('funcs','var')||nargin < 3, return; end;

% get names
names = get(x,'string'); if isempty(names), return; end;
if size(names,1) > 1, names = names'; end;

% get idx
idx = get(x,'value'); if idx > numel(names), return; end;
fp.idx = idx;

% if no options, set idx options
if ~exist('options','var')||idx > numel(options), options{idx,1} = {[]}; end;

% question
edtype = listdlg('PromptString',names{idx},'ListString',{'copy','delete','edit','insert'},'selectionmode','single');
if isempty(edtype), return; end; 

% edit 
if edtype==3, fp=feval(fp.program{idx},'add_function',fp); set(x,'string',fp.names); return; end;

% insert
ifp = []; if edtype==4, ifp=add_function(struct); if isempty(ifp.funcs), return; end; end;

% update each var
cellfun(@(x)assignin('caller',x,local_update(x,edtype,idx,ifp)),chngvars);

% set listbox
set(x,'string',names); set(x,'value',1);

% set vars to fp
fp = funpass(fp,chngvars);
return;

% locally update var
function output = local_update(varnam,edtype,idx,ifp)

% get input
if ~evalin('caller',['exist(''' varnam ''',''var'')'])
    output = {}; return;
else
    output = evalin('caller',varnam);
    if isempty(output), return; end;
end

% set nidx 
if any(strcmp(varnam,{'options','vars','output'})), nidx = {idx,':'}; else nidx = {':',idx}; end;

% if empty output, return
if idx > max(size(output))||isempty({output{nidx{:}}}), return; end; 

% set based on type
switch edtype
    case 1 % copy
        idx = nidx; nidx{~cellfun('isclass',nidx,'char')} = numel(output)+1;
        output(nidx{:}) = output(idx{:});
    case 2 % delete
        output(nidx{:}) = [];
    case 4 % insert
        if ~isfield(ifp,varnam), return; end;
        nidx{~cellfun('isclass',nidx,'char')} = -idx;
        output = sawa_insert(output,nidx,ifp.(varnam));
end
return;

% load/save/run
function fp = loadsaverun(fp,lsr)
% get vars from fp
funpass(fp);

% load save run
if ~exist('lsr','var')
lsr = questdlg('Load/Save/Run','Load/Save/Run','Load','Save','Run','Load');
end

% get savename
if ~exist('sawafile','var')||isempty(sawafile), savename = 'wrapper_automation'; 
else [~,savename]=fileparts(sawafile); end;

% switch based on lsr
switch lower(lsr)

case {'load','save'} % load or save
curdir = pwd; % get current dir

% cd to jobs folder
cd(fileparts(fileparts(mfilename('fullpath'))));
if ~isdir('jobs'), mkdir('jobs'); end;
cd('jobs');

if strcmpi(lsr,'load') % load
disp('Load savedvars file to use');
[savedvars, spath] = uigetfile('*savedvars*.mat','Load savedvars file to use:');
if ~any(savedvars), return; end; % return if none chosen
savedvars = fullfile(spath, savedvars); load(savedvars,'fp'); % load savedvars

% set path/environment
fp = set_new_environments(fp);
% set structure names to fp.names
funpass(fp,{'names','funcs'}); if ~exist('names','var'), names = funcs; end;
set(findobj('-regexp','tag','_listbox'),'string',names); % set names
guidata(gcf,fp); return; % set new data to guidata

else % save
savedvars = cell2mat(inputdlg('Enter savedvars filename to save:','savedvars',1,{[savename '_savedvars.mat']}));
if isempty(savedvars), return; end; save(savedvars,'fp'); % save savedvars
end % return to curdir, and clear
cd(curdir); clear curdir; 

case 'run' % run
% init vars
if ~exist('program','var')||isempty(program), load(sawafile,'program'); end;
if ~iscell(program), program = {program}; end;
if ~exist('funrun','var'), funrun = 1; fp.funrun = funrun; end;
if ~exist('subrun','var'), subrun = []; end;
output = {}; vars = {};

% print results
hres = printres(savename); fp = funpass(fp,'hres'); 

% remove output field
if isfield(fp,'output'), fp = rmfield(fp,'output'); end;

% run for each iteration/subject
wb = settimeleft;
for i = funrun
% print subject/iteration
if ~isempty(subrun)&&all(funrun==subrun), printres(sa(i).subj,hres); end; 

% set output to pass to auto program
fp.output = cell(numel(funcs),1); fp.vars = {};

% for each unique program
for f = 1:numel(program),
% auto_run program
fp.i = i; fp.fiter = f; 
fp = feval(program{f},'auto_run',fp);
end

% set output
output{end+1} = fp.output;
vars = fp.vars;
fp = rmfield(fp,{'output','vars'});

% print separator
printres(repmat('-',1,75),hres); 

% display time left
settimeleft(i,funrun,wb);
end

% print notes
printres('Notes:',hres);
end

% set tooltipstring
if ~exist('savedvars','var')||~ischar(savedvars), savedvars = ''; end;
set(findobj('string','load/save/run'),'tooltipstring',savedvars);

% set vars to fp
clear lsr wb hres; fp = funpass(fp,who);
return;
