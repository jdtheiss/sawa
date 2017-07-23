function [matlabbatch, options] = pebl_setbatch(matlabbatch, options, m)
% [matlabbatch, options] = pebl_setbatch(matlabbatch, options, m)
% Set batch parameters for pebl using cfg_ui
%
% Inputs:
% matlabbatch (optional) - cell array of matlabbatch module components (can
%   be saved from cfg_ui)
% options (optional) - cell array of options corresponding to matlabbatch
%   modules
% m (optional) - number corresponding to the module index to load
%
% Outputs:
% matlabbatch - cell array of matlabbatch module components
% options - cell array of substructs of module components for each
%   parameter chosen
%
% Example:
% matlabbatch{1}.spm.util.disp.data = '<UNDEFINED>';
% [matlabbatch, options] = pebl_setbatch(matlabbatch);
% [replicate module]
% [press right arrow on "Image to Display" for both modules]
% [close gui]
%
% matlabbatch = 
% 
%     [1x1 struct]    [1x1 struct]
% 
% 
% options = 
% 
%     [1x5 struct]    []    [1x5 struct]    []
%
% sub2str(options{1})
% 
% ans =
% 
% {1}.spm.util.disp.data
%
% sub2str(options{3})
% 
% ans =
% 
% {2}.spm.util.disp.data
%
% Note: to add a pebl parameter, press the right arrow while selecting the
% item; to remove the item, press the left arrow while selecting the item.
% once all modules/items have been added, close the gui to return outputs.
%
% Created by Justin Theiss

% init vars
if ~exist('cfg_ui','file'), error('Must have cfg_ui.m in matlab path.'); end;
if ~exist('matlabbatch','var'), matlabbatch = {}; end;
if ~iscell(matlabbatch), matlabbatch = {matlabbatch}; end;
if ~exist('options','var')||isempty(options), options = {}; end;
if ~exist('m','var')||isempty(m), m = 1; end;

% please wait message box to be deleted when ready
wait_h = wait_msg;
wait_t = timer('TimerFcn', @(x,y)wait_msg(wait_h),...
    'Period', 0.1, 'ExecutionMode', 'fixedSpacing',...
    'StopFcn', @(x,y)wait_msg(wait_h,'delete'),...
    'ErrorFcn', @(x,y)stop(x));
start(wait_t);

% prevent matlab from giving warnings when a text entered matches a function
warning('off','MATLAB:dispatcher:InexactCaseMatch');
     
% initialize cfg_ui
spm_jobman('initcfg'); cfg_util('initcfg');

% open cfg_ui and get guidata
h = cfg_ui; handles = guidata(h); 

% set closerequestfcn to set to invisible (rather than try to save)
set(h, 'CloseRequestFcn', @(x,y)set(x,'visible','off'));

% set keypress fcn for module
set(findobj(h,'tag','module'), 'KeyPressFcn',...
    @(x,y)guidata(gcf,setfield(guidata(gcf),'kp',y.Key)));

% set tooltipstring
set(findobj(h,'tag','module'), 'ToolTipString',...
    'Press right arrow to set pebl variable, left to remove.');

% remove kp if already exists
if isfield(handles,'kp'), guidata(h,rmfield(handles,'kp')); end;

% load batch 
if ~isempty(matlabbatch)&&~all(cellfun('isempty', matlabbatch)),
    cfg_util('initjob',matlabbatch); 
    set(handles.modlist, 'value', m);
    cfg_ui('local_showjob',h);
end

% convert options to idx
idx = cell(size(options));
idx = idx2options(h, matlabbatch, idx, options, 'idx');

% set userdata for h to current item value
m = get(handles.modlist, 'value');
i = get(handles.module, 'value');
str = get(handles.module, 'string');
str_ids = get_ids_fields(h, m);
% init params.m as 0 to force update on first load
params = struct('m', 0, 'i', i, 'str', {str}, 'str_ids', {str_ids});
set(h, 'userdata', params);

% update with previous options
update_cfg(h, idx);

% close msgbox
stop(wait_t); delete(wait_t);

% set timer
t = timer('TimerFcn', @(x,y)set(x, 'userdata', update_cfg(h, get(x, 'userdata'))),...
    'Period', 0.1, 'UserData', idx, 'ExecutionMode', 'fixedSpacing',...
    'ErrorFcn', @(x,y)stop(x));
start(t);

% wait for h to close
waitfor(h, 'visible', 'off');
stop(t); 

% get idx from t
idx = get(t, 'userdata');
delete(t);

% harvest matlabbatch
userdata = get(handles.modlist, 'userdata');
[~, matlabbatch] = cfg_util('harvest', userdata.cjob); 

% convert idx to options
options = idx2options(h, matlabbatch, idx, options);

% delete figure
delete(h);
end

function wait_h = wait_msg(wait_h, cmd)

% if no cmd, set to ''
if ~exist('cmd','var'), cmd = ''; end;
if nargin==0, % no nargin, create msgbox
    wait_h = msgbox('Please wait...'); 
elseif nargin==1 && ishandle(wait_h), 
    figure(wait_h); % make figure current
elseif strcmp(cmd,'delete') && ishandle(wait_h), 
    delete(wait_h); % delete msgbox
end
end

function idx = update_cfg(h, idx)

% get guidata
handles = guidata(h);
% get item value, string, and userdata
m = get(handles.modlist, 'value');
i = get(handles.module, 'value');
str = get(handles.module, 'string');
params = get(h, 'userdata'); 
% init idx
if m > numel(idx), idx{m} = []; end;
% if key press
if isfield(handles, 'kp'),
    kp = handles.kp;
    % remove kp from handles
    guidata(h, rmfield(handles,'kp'));
    if strcmp(kp,'rightarrow') % add
        idx{m}(end+1) = i;
    elseif strcmp(kp,'leftarrow') % remove
        idx{m}(idx{m}==i) = [];
    else % if up/down, return
        return; 
    end
% if new module, update str_ids
elseif params.m ~= m,
    params.str_ids = get_ids_fields(h, m); params.str = str;
% if updated module, update str_ids and indices
elseif numel(params.str) ~= numel(str) || ~all(strcmp(params.str, str)),
    str_ids = get_ids_fields(h, m);
    idx{m} = cell2mat(cellfun(@(x){find(strcmp(str_ids,x))}, params.str_ids(idx{m})));
    params.str_ids = str_ids; params.str = str;
else % otherwise do not update string
    return;
end
% set params to h 
params.i = i; params.m = m;
set(h, 'userdata', params);
% set idx unique
idx{m} = unique(idx{m});
% update string
update_str(h, idx{m});
end

function [str_ids, output] = get_ids_fields(h, m, fields)

% if fields not cell, set cell
if ~exist('fields', 'var'), fields = ''; end;
if ~iscell(fields), fields = {fields}; end;
% get modlist userdata
handles = guidata(h);
userdata = get(handles.modlist, 'userdata');
% init str_ids and tags
str_ids = {}; output = {};
if isempty(userdata.cmod), return; end;
% get ids from module
[ids, ~, output] = cfg_util('listmod', userdata.cjob, userdata.id{m}, [],...
    cfg_findspec({{'hidden',false}}),...
    cfg_tropts({{'hidden',true}},1,inf,1,inf,false), fields);
% set str_ids
str_ids = cellfun(@(x){sub2str(x)}, ids);
end

function update_str(h, idx)

% msg to display in string
msg = '----pebl parameter----';
handles = guidata(h);
% reload gui
cfg_ui('local_showmod', handles.modlist);
% get string
str = get(handles.module, 'string');
% set msg for item idx
str(idx) = {msg};
% update str
set(handles.module, 'string', str);
end

function output = idx2options(h, matlabbatch, idx, options, output_type)

% init output_type and output
if ~exist('output_type','var'), output_type = 'options'; end;
output = {};
idx(end+1:numel(matlabbatch)) = {[]};

for m = 1:numel(matlabbatch),
    % get tags, class, and num for module
    tags = {}; classes = {};
    [~, contents] = get_ids_fields(h, m, {'tag','class'});
    if ~isempty(contents),
        [tags, classes] = deal(contents{:});
    end
    % if output to idx
    if strcmp(output_type, 'idx'),
        output{m} = [];
        % get substruct options
        S = options(1:2:end);
        for x = 1:numel(S),
            % if char S, get substruct
            if ischar(S{x}),
                [~,tmpS] = pebl_getfield(matlabbatch, 'expr', S{x});
                if ~isempty(tmpS), S{x} = tmpS{1}; end;
            end
            % find position of last char substruct field in tags
            if isstruct(S{x})&&S{x}(1).subs{1} == m,
                fld = {S{x}.subs};
                fld = fld(cellfun('isclass',fld,'char'));
                if iscell(S{x}(end).subs), i = S{x}(end).subs{1}; else i = 1; end;
                fnd = find(strcmp(tags, fld{end}));
                output{m}(x) = fnd(i);
            end
        end
        % remove 0s
        output{m}(output{m}==0) = [];
    % if output to options
    elseif strcmp(output_type, 'options') && ~isempty(idx{m}),
        % get substruct and representations
        for x = idx{m}, 
            [~, S] = pebl_getfield(matlabbatch{m}, 'expr', ['.*\.', tags{x}, '(\{\d+\})$']);
            if isempty(S),
                [~, S] = pebl_getfield(matlabbatch{m}, 'expr', ['.*\.', tags{x}]);
            end
            % set substruct to correct index
            S = S{find(strcmp(tags, tags{x}))==x};
            % if cfg_files class without cell at end, append {1}
            if strcmp(classes{x}, 'cfg_files') && ~iscell(S(end).subs),
                S = [S, sub2str('{1}')];
            end
            output{end+1} = [sub2str(['{',num2str(m),'}']), S];
        end
    end
end
% set output as (1:2:end)
if strcmp(output_type, 'options') && ~isempty(output),
    output = pebl_insert(2, output, 2:numel(output)+1, []);
    % set matching options inputs to output
    if ~isempty(options),
        S1 = cellfun(@(x){sub2str(x)}, output(1:2:end)); 
        for x = 1:2:numel(options)-1,
            if isstruct(options{x}), % if struct, use sub2str
                S0 = sub2str(options{x}); 
                i1 = 2 * find(strcmp(S1, S0), 1) - 1;
            else % otherwise use regexp
                i1 = 2 * find(~cellfun('isempty',regexp(S1, options{x})), 1) - 1;
            end % set output
            if ~isempty(i1), output(i1:i1+1) = options(x:x+1); end;
        end
    end
end
end