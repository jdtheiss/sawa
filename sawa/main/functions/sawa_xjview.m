function sawa_xjview(varargin)
% sawa_xjview('property1','value1','property2','value2',...)
% This function will allow for saving images and cluster details from
% multiple files using xjview
%
% variables to input can be any of the following:
% files - cellstr of full filepaths of images to use
% outfld - cell/str/cellstr of folders to save resulting images and cluster details 
% into. outfld can be empty cell(s) for same as file folders, str/cellstr subfolder, 
% or str/cellstr fullpath (default is same as file folders)
% pval - pvalue to use (must be less than or equal to 1) [0.001]
% kval - cluster threshold (must be greater than 1) [5]
% defxyz - x,y,z coordinates to snap to (default is global max)
% mask - string of default mask to use or fullfile
% to other mask ['single T1']
% sep - separation (in mm) of slices [4]
% col - number of columns to display in image [8]
% row - number of rows to display in image [8]
% itype - image type for saving images ['.png']
% output - cell/str of outputs to save ['all'] (enter 'none' for no outputs) 
% - 'all' - all outputs
% - 'txt' - text file of cluster details
% - 'xls' - excel file of cluster details
% - 'img' - main xjview screen capture at coordinates
% - 'slcs' - all slices screen capture
% - 'axial' - axial slices screen capture
% - 'coronal' - coronal slices screen capture
% - 'sagittal' - sagittal slices screen capture
%
% Example:
% sawa_xjview('files','spmT_0001.nii','pval',0.01,'kval',124,'defxyz',[12,-8,14],'output',{'img','slcs'})
% This example would save xjview main image and slice view images for
% 'spmT_0001.nii', use a pval of 0.01, kval of 124 voxels, jump to
% coordinates [12, -8, 14], and save the resulting images into the current directory.
%
% requires: sawa_cat, sawa_screencapture, sawa_strjoin, subidx, xjview
%
% Created by Justin Theiss 

% set masks
masks = {'single T1','avg152PD','avg152T1','avg152T2','avg305T1','ch2','ch2bet','aal','brodmann'};

% set vars
arrayfun(@(x)assignin('caller',varargin{x},varargin{x+1}),1:2:nargin);

% init other vars
if isempty(which('xjview')), 
    disp('Choose path to xjview');
    xjpath = uigetdir(pwd,'Choose path to xjview:'); 
    if ~any(xjpath)
    error('Need to download xjview'); 
    end
    addpath(xjpath);
end
if ~exist('files','var'), files = ''; end;
if ~iscell(files), files = {files}; end;
if ~exist('pval','var'), pval = 0.001; end;
if ~exist('kval','var'), kval = 5; end;
if ~exist('defxyz','var'), defxyz = []; end;
if ~exist('mask','var'), mask = 'single T1'; end;
if ~exist('sep','var'), sep = 4; end;
if ~exist('col','var'), col = 8; end;
if ~exist('row','var'), row = 8; end;
if ~exist('outfld','var'), outfld = cell(size(files)); end;
if ~iscell(outfld), outfld = {outfld}; end;
if numel(files)>numel(outfld), outfld = repmat(outfld(1),1,numel(files)); end;
if ~exist('itype','var'), itype = '.png'; end;
if ~exist('output','var')||any(strcmp(output,'all')), 
    opts = true(1,4); slc_chc = 1:3; 
else
    opts = ismember({'txt','xls','img','slcs'},output); 
    slc_chc = find(ismember({'axial','coronal','sagittal'},output));
    if isempty(slc_chc)&&opts(4), slc_chc = 1:3; elseif ~isempty(slc_chc), opts(4) = true; end;
end

% open xjview
xjview; xj_fig = gcf;

% get handles for different objects xj_fig = findobj('-regexp','name','xjView.*'); 
hload = findobj(xj_fig,'string','Load Image'); 
hp = findobj(xj_fig,'string','0.001'); hk = findobj(xj_fig,'string','5');
hrep = findobj(xj_fig,'string','report'); hx = findobj(xj_fig,'string','XHairs Off');
hmsk = findobj(xj_fig,'string',masks); homsk = findobj(xj_fig,'string','other ...'); 
hslc = findobj(xj_fig,'string','slice view'); hint = findobj(xj_fig,'string','All'); 

% set mask first time only
if exist(mask,'file'), % if other mask, set
handles = guidata(homsk); handles.sectionViewTargetFile = mask; guidata(homsk,handles); 
else % set mask to one of defaults
set(hmsk,'value',find(strcmp(masks,mask))); cb = get(hmsk,'Callback'); cb(hmsk,[]);   
end

% load TDdatabase for mask volumes
maskvols = subidx(load('TDdatabase'),'.wholeMaskMNIAll');

% run for each file
for f = 1:numel(files)
try
% load image
cb = get(hload,'Callback'); cb(hload,[],files{f}); 

% get image name
if isempty(files{f}), files{f} = strrep(get(xj_fig,'name'),'xjView: ',''); end;
[ipat,ifil] = fileparts(files{f}); if ~isempty(ipat), cd(ipat); end;

% update pval
set(hp,'string',num2str(pval)); cb = get(hp,'Callback'); cb(hp,[]); 

% update cluster
set(hk,'string',num2str(kval)); 
cb = get(hk,'Callback'); 
cb(hk,[]);

% update coordinates
hMIPax = findobj(xj_fig,'tag','hMIPax'); 
if isempty(defxyz), 
spm_mip_ui('Jump',hMIPax,'glmax'); 
else 
spm_mip_ui('SetCoords',defxyz,hMIPax);
end;

% update display intensity
set(hint,'value',1); cb = get(hint,'Callback'); cb(hint,[]);

% turn off xhairs
set(hx,'value',1); cb = get(hx,'Callback'); cb(hx,[]);

% save picture
if ~isempty(outfld{f})&&~isdir(outfld{f}), 
mkdir(outfld{f}); cd(outfld{f}); % make subfld
elseif ~isempty(outfld{f}) 
cd(outfld{f}); % cd to fullpath, make folder in outfld 
[~,tmpfld] = fileparts(ipat);
if ~isempty(tmpfld), mkdir(tmpfld); cd(tmpfld); end; clear tmpfld;
end
xjimg = ['xjview_p' num2str(pval) 'k' num2str(kval) '_' ifil];
if opts(3), sawa_screencapture(xj_fig,xjimg,itype); end;

% get report
if any(opts(1:2))
cb = get(hrep,'Callback'); report = evalc('cb(hrep,[])');

% calculate percent of mask volumes
clear names vols pct;
nams = regexp(report,'[^\n]*\s+(?<vols>\d+)\s+(?<names>[^\n]+)','names');
n = find(strcmp({nams.names},'--TOTAL # VOXELS--')); n = [n,numel({nams.names})];
for i = 1:numel(n)-1 % for each --TOTAL # VOXELS--, get names, vols
names{i} = {nams(n(i):n(i+1)-1).names}; vols{i} = {nams(n(i):n(i+1)-1).vols};
names{i}(2:end) = regexprep(names{i}(2:end),{'\s','-','\(','\)'},{'_','_','',''}); 
nn = isfield(maskvols,names{i}); % get only names that are fields of maskvols
names{i} = [names{i}(1),names{i}(nn)]; vols{i} = [vols{i}(1),vols{i}(nn)]; % update names, vols
pct{i}{1} = round((str2double(vols{i}{1})/219727)*100); % get pct of brain
for ii = 2:numel(names{i}) % for each, get percent of mask
pct{i}{ii} = round((str2double(vols{i}{ii})/size(maskvols.(names{i}{ii}),1))*100); 
end % set voxels, pct, names
vols{i}=['# voxels',vols{i}]; pct{i}=['% of area',pct{i}]; names{i}=['structure',names{i}];
end

% output report to txt
nams = regexp(report,'(?<rows>[^\n]+)','names'); rows = {nams.rows};
n = find(~cellfun('isempty',regexp(rows,'# voxels')))-1; 
if isempty(n), continue; end;
report = sawa_strjoin(rows(1:n(1)-5),'\n');
for i = 1:numel(n)
report = sawa_strjoin({report,rows(n(i)-4:n(i)),cell2strtable(cat(2,vols{i}',pct{i}',names{i}'),' ')},'\n');
end
outtxt = ['ClusterDetails_p' num2str(pval) 'k' num2str(kval) '_' ifil '.txt'];
if opts(1)
save(outtxt); fid = fopen(outtxt,'w'); fwrite(fid,report); fclose(fid);
end

if opts(2)
% output report to excel
outxls = strrep(outtxt,'.txt','.xlsx');
ncl = regexp(report,'Cluster\s+(?<names>\d+)','names'); ncl = {ncl.names}';
sizecl = regexp(report,'Number of voxels:\s+(?<names>\d+)','names'); sizecl = {sizecl.names}';
coorcl = regexp(report,'Peak MNI coordinate:\s+(?<names>[^\n]+)','names'); coorcl = {coorcl.names}';
intcl = regexp(report,'Peak intensity:\s+(?<names>[^\n]+)','names'); intcl = {intcl.names}';
regcl = regexp(report,'Peak MNI coordinate region:\s+(?<names>[^\n]+)','names'); regcl = {regcl.names}';
dat = sawa_cat(1,files{f},{'p value =',pval},{'cluster size =',kval},...
{'Cluster','Size','Peak MNI coordinate','Peak intensity','Peak Region'},...
sawa_cat(2,ncl,sizecl,coorcl,intcl,regcl));
xlwrite(outxls,dat);
end
end

% get slice views
if opts(4)
cb = get(hslc,'Callback'); cb(hslc,[]); 
% get slice figure and save each view
slc_fig = findobj('name','xjView slice view'); 
% get images of each 
htcs = findobj(slc_fig,'string',{'transverse','coronal','sagittal'}); 
% get separation
hsep = findobj(slc_fig,'style','edit','string','4'); 
% get columns, rows
hcol = subidx(findobj(slc_fig,'style','edit','string','8'),1); 
hrow = subidx(findobj(slc_fig,'style','edit','string','8'),2);
for x = slc_chc % set sep, col, row, and view
set(hsep,'string',num2str(sep)); cb = get(hsep,'Callback'); cb(hsep,[]); 
set(hcol,'string',num2str(col)); cb = get(hcol,'Callback'); cb(hcol,[]);
set(hrow,'string',num2str(row)); cb = get(hrow,'Callback'); cb(hrow,[]);
set(htcs,'value',x); cb = get(htcs,'Callback'); cb(htcs,[]); 

% save slcimg
slcimg = [subidx(get(htcs,'string'),['{' num2str(x) '}']) '_p' num2str(pval) 'k' num2str(kval) '_' ifil];
sawa_screencapture(slc_fig,slcimg,itype);
end % close slice views
close(slc_fig);
end
catch err
disp(['Error: ' files{f} ' ' err.message]);    
end
end

% close any errors, warnings, spm_mip_ui warnings
shh = get(0,'ShowHiddenHandles'); set(0,'ShowHiddenHandles','on');
try close(findobj('name','error')); end;
try close(findobj('name','Warning Dialog')); end;
try close(findobj('-regexp','name','spm_mip_ui')); end;
set(0,'ShowHiddenHandles',shh);

% close xjview
close(xj_fig);

