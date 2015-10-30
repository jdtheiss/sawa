function vals = sawa_createvars(varnam,msg,subrun,sa,varargin)
% vars = sawa_createvars(varnam,msg,subrun,sa)
% Creates variables for specific use in auto_batch, auto_cmd, auto_wrap.
% 
% Inputs:
% varnam - variable name 
% msg - optional string message to display in listdlg
% subrun - numeric array of subjects to use (optional)
% sa - subject array (optional)
% Note: if subrun/sa are not entered, user will choose
%
% Outputs:
% vars - variable returned
%
% Example:
% varnam = 'Resting State Files';
% msg = '';
% subrun = 1:33;
% sa = ocd;
% vars = sawa_createvars(varnam,msg,subrun,sa)
% [choose "Subject Array"]
% [choose "subjFolders 1"]
% [enter "/RestingState/Resting*.nii"]
% vars = 'sa(i).subjFolders{1}';
%
% requires: choose_fields getargs sawa_subrun
%
% Created by Justin Theiss

% init vars
if ~exist('varnam','var')||isempty(varnam), varnam = 'Variable'; end;
if ~exist('msg','var'), msg = ''; end;
if ~exist('subrun','var'), subrun = []; end;
if ~exist('sa','var'), sa = {}; end;

% set vars to [] 
vals = {};

% set choices
choices = {'String','Number','Evaluate','Structure','Choose File','Choose Directory','Function','Subject Array'};
if isempty(sa), choices = choices(1:end-1); end;
if ~isempty(varargin), choices = horzcat(choices,varargin{:}); end;

% choose method for invars
chc = listdlg('PromptString',{['Choose method to set ' varnam ' ' msg],'',''},'ListString',choices); %,'selectionmode','single');
if isempty(chc), return; end; 

for c = chc
% set based on choice
switch lower(choices{c})
case {'string','number','evaluate'} % input
    vars = cell2mat(inputdlg(['Set ' varnam],varnam,2));
    vars = strtrim(arrayfun(@(x){vars(x,:)},1:size(vars,1)));
    if c > 1 % number or evaluate
        vars = cellfun(@(x){eval(['[' x ']'])},vars);
    end
case 'structure' % struct
    vars = struct; done = 0; 
    while ~done
        % set field
        fld = cell2mat(inputdlg('Enter field name to add to structure (cancel when done):'));
        if isempty(fld), done = 1; break; end; % if no fld, done
        vars.(fld) = sawa_createvars(fld,'',subrun,sa); % run set_invars
    end
case 'choose file' % choose file
    vars = cellstr(spm_select(Inf,'any',['Select file for ' varnam]));
case 'choose directory' % choose dir
    vars = cellstr(spm_select(Inf,'dir',['Select directory for ' varnam]));
case 'function' % function
    fp = auto_wrap; vars = [fp.output{:}]; clear fp; 
case 'subject array' % subject array
    % choose group
    if ~isempty(subrun)
    grp = questdlg(['Choose group or individual for ' varnam '?'],varnam,'Group','Individual','Individual');
    else % set to group if empty
    grp = 'Group';
    end
    % get subrun
    if strcmp(grp,'Group')
    subrun = sawa_subrun(sa,[],subrun);
    end
    % choose fields
    vars = choose_fields(sa,subrun,['Choose field(s) for ' varnam]);
    subvars = cell2mat(inputdlg('Enter subfolder, files, etc.'));
    % strcat
    if strcmp(grp,'Individual')
    vars = strcat('sa(i).',vars{1},subvars);
    else % group 
    vars = strcat('sa(', arrayfun(@(x){num2str(x)},subrun),').',vars{1},subvars)'; 
    end
case lower(varargin) % functions 
    % find choice in varargin
    n = find(strcmp(varargin,choices{x}),1,'first');
    % get outargs
    outargs = getargs(choices{x});
    if isempty(outargs), outargs = {'varargout'}; end;
    % choose outargs
    v = listdlg('PromptString',['Choose output from ' choices{x}],'ListString',outargs);
    if isempty(v), return; end;
    % strcat
    vars = strcat('evalin(''caller'',','''output{i}{', num2str(n),',',arrayfun(@(x){num2str(x)},v),'}'');');
end
if iscell(vars)&&size(vars,2) > size(vars,1), vars = vars'; end; % if horizontal
if iscell(vars)&&numel(vars) == 1, vars = vars{1}; end; % if one cell
% vertcat
vals = cat(1,vals,vars);
end

