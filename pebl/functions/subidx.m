function output = subidx(obj, idx)
% output = subidx(obj, idx)
% Index item as subsref(obj, sub2str(idx))
%
% Inputs: 
% obj - object to be indexed
% idx - string or numeric index to use
%
% Outputs:
% output - returned object that is subsref(obj, sub2str(idx))
%
% Example: 
% obj = struct('test', {1,2,3});
% output = subidx(obj, '(2:3).test')
%
% output = 
% 
%     [2]    [3]
%
% Created by Justin Theiss

% init vars
if ~exist('idx','var'), idx = '(:)'; end;
% sub2str idx
S = sub2str(idx);
if iscell(S), % if multiple substructs
    output = cell(size(S));
    for n = 1:numel(S),
        output{n} = subsref(obj, S{n});
    end
else % subsref single substruct
    output = subsref(obj, S);
end
end
