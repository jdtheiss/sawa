function output = pebl_feval(varargin)
% output = pebl_feval(funcs, options1, options2, ..., 'Param1', Value1, ...)
% Run wrapper of multiple scripts/functions/system commands/matlabbatch.
%
% Inputs:
% funcs - cell array, functions to run. matlab functions as function
%   handles, system commands as char, and matlabbatch modules as cell/struct
%   [no default]
% options - separate inputs per function. each function's input arguments
%   should be contained in a cell array with rows corresponding to iterations
%   [default {} per function]
% 'loop' - number, optional number of times to loop through functions
%   [default 1]
% 'seq' - numeric array, optional sequence of functions to be run
%   [default [] which runs all functions in order]
% 'iter' - cell/numeric array, optional sequence of iterations to be run. 
%   numeric array: iterations to run
%   -1: set each iteration to loop number
%   inf: run all iterations based on number of rows in options
%   []: run as is, assumes no iterations
%   cell array: each function's iter in separate cell
%   [default []]
% 'stop_fn' - cell array/function, function to evaluate during while loop.
%   if function evaluates true, the loop ends.alternatively, cell array of
%   stop_fn per function. stop_fn is overrided by 'iter' option inf
%   [default []]
% 'n_out' - numeric array, range of outputs to return from each function
%   [default 1]
% 'verbose' - boolean, true displays function call with options and output
%   [default false]
% 'throw_error' - boolean, true throws error if any occurs
%   [default false]
% 'wait_bar' - boolean, true displays waitbar during loops
%   [default false]
% 
% Outputs:
% output - outputs organized as cells per function with inner cells of rows 
%   per iteration and/or loop and columns based on number of outputs. 
%   outputs can be used as inputs: @()'output{func}{iter, n_out}'.
%
% Example 1: system echo 'this' and compare output with 'that' using
% strcmp, then repeat with system echo 'that'
% output = pebl_feval({'echo',@strcmp}, {'-n',{'this'; 'that'}},...
%          {@()'output{1}{end}', 'that'}, 'loop', 2, 'iter', {-1,[]})
% this
% that
% 
% output{1} = 
% 
%     'this'
%     'that'
% 
% output{2} = 
% 
%     [0]
%     [1]
%     
% Example 2: subtract 1 from each previous output
% output = pebl_feval({@randi, @minus}, 10, {@()'output{end}{end}', 1},...
%          'seq', [1,2,2], 'verbose', true)
% randi 10
% 
% Output:
% 10
% 
% minus 10 1
% 
% Output:
% 9
% 
% minus 9 1
% 
% Output:
% 8
% 
% output{1} = 
% 
%     [10]
%
% output{2} = 
%
%     [ 9]
%     [ 8]
%
% Example 3: get fullfile path of template image, then display image using matlabbatch
% matlabbatch{1}.spm.util.disp.data = '<UNDEFINED>';
% output = pebl_feval({@fullfile, matlabbatch}, ...
%          {fileparts(which('spm')), 'canonical', 'avg152T1.nii'},...
%          {'.*\.data$', @()'output{1}(1)'})
% 
% ------------------------------------------------------------------------
% Running job #1
% ------------------------------------------------------------------------
% Running 'Display Image'
% 
% SPM12: spm_image (v6425)                           16:29:10 - 17/11/2016
% ========================================================================
% Display /Applications/spm12/canonical/avg152T1.nii,1
% Done    'Display Image'
% Done
% 
% output{1} = 
% 
%     '/Applications/spm12/canonical/avg152T1.nii'
% 
% output{2} = 
% 
%     {[]}
%
% 
% Example 4: use @() to evaluate inputs
% output = pebl_feval({'echo',@minus}, {'-n', {@()'randi(10)';'2'}},...
%          {@()'str2double(output{1}{end})', 2}, 'loop', 2, 'iter', {-1,[]})
%
% 5
% 2
% 
% output{1} = 
% 
%     '5'
%     '2'
% 
% output{2} = 
% 
%     [3]
%     [0]
% 
% Example 5: run while loop until last two numbers are same
% output = pebl_feval(@randi, {10;10}, 'iter', 1:2, 'stop_fn',...
%          @()'output{1}{end}==output{1}{end-1}')
% 
% output{1} = 
% 
%     [ 1]
%     [ 8]
%     [10]
%     [ 4]
%     [10]
%     [ 4]
%     [ 9]
%     [ 5]
%     [ 5]
%     [ 3]
%     [ 2]
%     [ 4]
%     [ 8]
%     [ 8]
%     
% Note: in order to avoid function inputs being incorrectly assigned as 
% parameters, put any inputs sharing parameter names in cell brackets 
% (e.g., pebl_feval(@disp, {'verbose'}, 'verbose', true)). 
% in order to evaluate options at runtime, @() can be prepended to a
% character array within options (see examples above).
%
% Created by Justin Theiss

% init output if no nargin
output = cell(1, 1);
if nargin==0, return; end; 

% init varargin parameters
params = {'loop', 'seq', 'iter', 'stop_fn', 'verbose', 'throw_error', 'wait_bar', 'n_out'};
values = {1, [], [], [], [], false, false, 1};
x = 1;
while x < numel(varargin),
    if ischar(varargin{x}) && any(strcmp(params, varargin{x})),
        switch varargin{x}
            case 'loop'
                loop = varargin{x+1};
            case 'seq'
                seq = varargin{x+1};
            case 'iter'
                iter = varargin{x+1}; 
            case 'stop_fn'
                stop_fn = varargin{x+1};
            case 'verbose'
                verbose = varargin{x+1};
            case 'throw_error'
                throw_error = varargin{x+1};
            case 'wait_bar'
                wait_bar = varargin{x+1};
            case 'n_out'
                n_out = varargin{x+1};
            otherwise % advance
                x = x + 1;
                continue;
        end
        % remove from params/values/varargin
        values(strcmp(params, varargin{x})) = [];
        params(strcmp(params, varargin{x})) = [];
        varargin(x:x+1) = [];
    else % advance
        x = x + 1;
    end
end

% set defaults
for x = 1:numel(params),
    eval([params{x} '= values{x};']);
end

% get funcs
funcs = varargin{1};
if ~iscell(funcs), funcs = {funcs}; end;
funcs = funcs(:);

% set options and ensure cell
if numel(varargin) >= numel(funcs)+1,
    options = varargin(2:numel(funcs)+1);
elseif all(cellfun('isclass',funcs,'struct')), % if all batch
    funcs = {funcs};
    options = varargin(2:numel(funcs)+1);
else % set options empty
    options = repmat({{}}, 1, numel(funcs));
end

% if seq is empty, set to 1:numel(funcs)
if isempty(seq), seq = 1:numel(funcs); end;

% if iter is not cell, repmat
if ~iscell(iter), 
    iter = repmat({iter}, 1, numel(funcs));
end

% if stop_fn is not cell, repmat
if ~iscell(stop_fn),
    stop_fn = repmat({stop_fn}, 1, numel(funcs));
end

% init output
output = {{}};
% for loop/sequence order
for l = 1:loop,
for f = seq,
    % default is [] meaning run once with no iterations
    if f > numel(iter), iter{f} = []; end;
    % different iter options
    if isempty(iter{f}),
        iter{f} = 0; 
    elseif all(iter{f} == inf),
        stop_fn{f} = @()'n==inf'; 
        iter{f} = 1;
    end  
    % if while loop
    done = false; 
    while ~done, 
        % wait_bar
        if wait_bar,
            h = settimeleft;
        end
        % for specified loops/iterations
        for n = iter{f}, 
            % if -1, set to l 
            if n == -1, n = l; end;
            % set program
            program = local_setprog(funcs{f}); 
            try % run program with funcs and options
                try o = abs(nargout(funcs{f})); o = max(o, max(n_out)); catch, o = max(n_out); end;
                % set options (for using outputs/dep)
                evaled_opts = local_eval(options{f}, 'output', output, 'func', funcs{f}, 'n', n);
                % feval
                [results{1:o}] = feval(program, funcs{f}, evaled_opts, verbose); 
                % display outputs
                if verbose, 
                    fprintf('\nOutput:\n');
                    disp(cell2strtable(any2str(results{1:o}),' ')); 
                    fprintf('\n'); 
                end
            catch err % display error
                % if throw_error is true, rethrow
                if throw_error,
                    rethrow(err);
                end
                % if not string, set to string
                if isa(funcs{f},'function_handle'),
                    func = func2str(funcs{f});
                elseif ~ischar(funcs{f}),
                    func = 'matlabbatch';
                else % set to funcs{f}
                    func = funcs{f};
                end
                % display error
                if isempty(verbose) || verbose, 
                    fprintf('%s %s %s\n',func,'error:',err.message); 
                end;
                % set output to empty
                results(1:o) = {[]};
            end
            % concatenate results to output
            if f > numel(output), output{f, 1} = {}; end;
            output{f} = pebl_cat(1, output{f}, results); 
            % wait_bar
            if wait_bar,
                settimeleft(f, 1:numel(iter), h);
            end
            % if all iterations, 
            if ~isempty(stop_fn{f}) && strcmp(func2str(stop_fn{f}), '@()''n==inf'''),
                if ~iscell(options{f}), 
                    n = inf; iter{f} = inf; % if not cell, done
                elseif ~any(cellfun('isclass',options{f},'cell')) && n==size(options{f},1),
                    n = inf; iter{f} = inf; % if only one set of cells
                elseif any(cellfun('isclass',options{f},'cell')) && n==max(cellfun('size',options{f},1)),
                    n = inf; iter{f} = inf; % multiple sets of cells
                else % otherwise advance
                    iter{f} = iter{f} + 1;
                end
            end
        end
        % check stop_func
        if isempty(stop_fn{f}),
            done = true;
        else
            done = cell2mat(local_eval(stop_fn{f},'output',output,'n',n));
        end
    end
end
end
% return output{f}(:, n_out)
output = cellfun(@(x){x(:, n_out)}, output);
end

% evaluate @() inputs
function options = local_eval(options, varargin)
    % for each varargin, set as variable
    for x = 1:2:numel(varargin), 
        eval([varargin{x} '= varargin{x+1};']);
    end
    % if no n, set to 0
    if ~exist('n', 'var'), n = 0; end;
    % get row from options
    if ~all(n==0) && ~any(n==inf) && iscell(options), 
        if any(cellfun('isclass', options, 'cell')),
            % for each column, set to row
            for x = find(cellfun('isclass',options,'cell')),
                if size(options{x}, 1) > 1,
                    options{x} = options{x}{min(end,n)};
                end
            end
        elseif ~isempty(options) && size(options, 1) > 1, 
            % if cell, set to row
            options = options{min(end,n)};
        end
    end
    
    % find functions in options
    if ~iscell(options), options = {options}; end;
    [C,S] = pebl_getfield(options,'fun',@(x)isa(x,'function_handle')); 
    
    if ~isempty(C),
        % convert to str to check
        C = cellfun(@(x){func2str(x)},C);
        % get only those beginning with @()
        S = S(strncmp(C,'@()',3));
        C = C(strncmp(C,'@()',3));
    
        % get functions with output
        o_idx = ~cellfun('isempty', regexp(C, 'output'));

        % set options based on output
        for x = find(o_idx),
            C{x} = subsref(options, S{x});
            options = subsasgn(options,S{x},eval(feval(C{x}))); 
        end

        % if program is batch, get depenencies
        if ~exist('func','var'), func = []; end;
        if iscell(func)||isstruct(func),
            [~, dep] = local_setbatch(func, options);
        else % otherwise set dep to []
            dep = [];
        end

        % set options based on dependencies
        for x = find(~o_idx),
            C{x} = subsref(options, S{x});
            options = subsasgn(options,S{x},eval(feval(C{x}))); 
        end
    end
    
    % eval remaining options
    if ischar(func), opt = 'system'; else opt = ''; end;
    options = pebl_eval(options, opt);
end

% set program types
function program = local_setprog(func)
    % get first function if cell
    if iscell(func), func = func{1}; end;
    % switch class
    switch class(func),
        case 'struct' % matlabbatch
            program = 'local_batch'; 
        case 'function_handle' % function/builtin
            program = 'local_feval';
        case 'char' % system
            program = 'local_system'; 
    end
end

% matlab functions
function varargout = local_feval(func, options, verbose)
    % init varargout
    varargout = cell(1, nargout); 
    
    % set func to str if function_handle
    if isa(func,'function_handle'), func = func2str(func); end;

    % if options is not cell or more inputs than nargin, set to cell
    if ~iscell(options) || (nargin(func) > 0 && numel(options) > nargin(func)),
        options = {options}; 
    end
    
    % get number of outputs
    try o = nargout(func); catch, o = 0; end;
    if o < 0, o = nargout; elseif o > 0, o = min(nargout, o); end;
    
    % display function and options
    if verbose, disp(cell2strtable(any2str(func,options{:}),' ')); end;
    
    % if no ouputs, use evalc output
    if o == 0,
        varargout{1} = evalc([func '(options{:});']);
        if isempty(verbose) || verbose, disp(varargout{1}); end;
    else  % multiple outputs
        if isempty(verbose) || verbose,
            [varargout{1:o}] = feval(func, options{:}); 
        else % prevent display
            [~,varargout{1:o}] = evalc([func '(options{:});']);
        end
    end
end

% system commands
function varargout = local_system(func, options, verbose)
    % init varargout
    varargout = cell(1, nargout);

    % ensure all options are strings
    if ~iscell(options), options = {options}; end;
    options = cellfun(@(x){num2str(x)}, options);

    % concatenate func and options with spacing
    stropts = sprintf('%s ', func, options{:});
    
    % display function and options
    if verbose, disp(stropts); end;
    
    % run system call
    [sts, tmpout] = system(stropts);
    
    % if verbose isempty, display tmpout
    if isempty(verbose), disp(tmpout); end;
    
    % set output cell
    output = cell(1, nargout);

    % if sts is 0, no error
    if sts == 0,
        if nargout > 1,
            % attempt to separate output
            tmpout = regexp(tmpout, '\n', 'split');
            tmpout(cellfun('isempty',tmpout)) = [];
            tmpout = regexp(tmpout, '\s+', 'split');
            tmpout = pebl_cat(1, tmpout{:}); 
            tmpout(cellfun('isempty',tmpout)) = {''};
            tmpout = arrayfun(@(x){char(tmpout(:,x))}, 1:size(tmpout,2));
            % set to output
            if ~isempty(tmpout), [output{1:numel(tmpout)}] = tmpout{:}; end;
        else % otherwise set to tmpout
            output{1} = tmpout;
        end
    else % throw error
        error('%d %s',sts,tmpout);
    end

    % set to varargout
    [varargout{1:nargout}] = output{1:nargout};
end

% set batch
function [matlabbatch, dep] = local_setbatch(matlabbatch, options)
    % ensure cells
    if ~iscell(matlabbatch), matlabbatch = {matlabbatch}; end;
    if ~iscell(options), options = {options}; end;
    if numel(options) < 1, options{2} = []; end;
    % for each option, get subsref struct
    for x = 1:2:numel(options)
        % if @() function, skip setting (it should be evaluated with local_eval)
        if isa(options{x+1}, 'function_handle') && strncmp(func2str(options{x+1}), '@()', 3), 
            continue; 
        end
        switch class(options{x})
            case 'struct' % use pebl_setfield with S
                % if cell substruct but not cell in matlabbatch, set to {}
                if strcmp(options{x}(end).type,'{}')&&~iscell(subsref(matlabbatch,options{x}(1:end-1))),
                    matlabbatch = subsasgn(matlabbatch, options{x}(1:end-1), {});
                end
                matlabbatch = pebl_setfield(matlabbatch, 'S', options{x}, 'C', options{x+1});
            case 'cell' % use pebl_setfield with options
                if all(cellfun('isclass', options{x}, 'struct')), % S
                    matlabbatch = pebl_setfield(matlabbatch, 'S', options{x}, 'C', options{x+1});
                elseif iscellstr(options{x}) && ~strcmp(options{x}{1}, 'R'), % R
                    matlabbatch = pebl_setfield(matlabbatch, 'R', options{x}, 'C', options{x+1});
                else % any options
                    matlabbatch = pebl_setfield(matlabbatch, options{x}{:}, 'C', options{x+1});
                end
            case 'char' % use pebl_setfield with expr or R
                if any(regexp(options{x}, '[\\|^$*+?]')),
                    type = 'expr';
                else
                    type = 'R';
                end
                matlabbatch = pebl_setfield(matlabbatch, type, options{x}, 'C', options{x+1});
        end
    end
    % get dependencies
    if nargout == 2,
        [~, cjob] = evalc('cfg_util(''initjob'',matlabbatch);'); 
        [~,~,~,~,dep]=cfg_util('showjob',cjob); 
    end
end

% matlabbatch commands
function varargout = local_batch(matlabbatch, options, verbose)
    % init varargout
    varargout = cell(1, nargout); 
    
    % set batch
    matlabbatch = local_setbatch(matlabbatch, options);
   
    % display functions of structure
    if verbose,
        [C,~,R] = pebl_getfield(matlabbatch);
        cellfun(@(x,y)fprintf('%s: %s\n', x, genstr(y)), R, C);
    end;
    
    % run job
    cjob = cfg_util('initjob',matlabbatch); 
    if isempty(verbose) || verbose, 
        cfg_util('run',cjob);
    else % prevent display
        evalc('cfg_util(''run'',cjob);');
    end
    
    % get outputs
    [~,~,~,~,dep]=cfg_util('showjob',cjob); 
    vals = cfg_util('getalloutputs',cjob);

    % subsref vals
    output = cell(1, nargout);
    for x = 1:numel(vals),
        % if empty, skip
        if isempty(vals{x}) || isempty(dep{x}), continue; end;
        for y = 1:numel(dep{x}), 
            % set output from vals
            output{x}{y} = subsref(vals{x},dep{x}(y).src_output); 
        end
    end

    % set to varargout
    [varargout{1:nargout}] = output{1:nargout};
end