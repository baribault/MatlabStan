% TODO, end of csv has commented lines with timing info, should scan
% inc_warmup = true works for optimizing files as well
function [hdr,varNames,samples,pos] = read_stan_csv(fname,inc_warmup,pos,ignoreParams) %BB:added ignoreParams
   if nargin < 2
      inc_warmup = false;
   end

   fid = fopen(fname);
   if nargin >= 3 %BB: changed from ==
      if ~isempty(pos) %% BB: added
          status = fseek(fid,pos,'bof');
          if status == -1
             error('Could not advance to requested position.');
          end
      end %% BB: added
   end
   
   count = 1;
   while 1
      l = fgetl(fid);

      if strcmp(l(1),'#')
         line{count} = l;
      else
         varNames = regexp(l, '\,', 'split');
         if ~inc_warmup
            % As of Stan 2.0.1, these lines exist when warmup is not saved
            for i = 1:4 % FIXME: assumes 4 lines, should generalize?
               line{count} = fgetl(fid);
               count = count + 1;
            end
         end
         break
      end
      count = count + 1;
   end
   hdr = sprintf('%s\n',line{:});
   
   %BB: commented this out
%    nCols = numel(varNames);
%    cols = repmat('%f',1,nCols);
   
   %BB: begin addition %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   %samples is a nIterations x nParameterInstances matrix of posterior samples.
   %varNames is a 1 x nParameterInstances cell of variable names of the form:
   %            variableName.#          if single index
   %    	    variableName.#.#        if two indices
   %    	    variableName.#.#.#      if three indices
   %and so on.  
   %
   %cols tells textscan what columns to read.
   %right now, it says read all columns: 
   %        cols = %f repeated for each parameterInstance
   %what I want is to read only selected columns
   %    cols = %f   where I want read that column, i.e., parameter instance
   %           %*f  where I want to skip that column, i.e., parameter instance
   %
   %so first I filter:
   if nargin == 4
        ignoreCols = false(size(varNames));
        for p = 1:length(ignoreParams)
            param = ignoreParams{p};
            n = length(param) + 1;
            ignoreCols = ignoreCols | ...
                cellfun(@(x) strncmp(x,[param '.'],n),varNames);
        end
        %tell textscan to skip columns
        cols = cell([length(ignoreCols) 1]);
        for n = 1:length(ignoreCols)
            if ignoreCols(n)
                cols{n} = '%*f';
            else
                cols{n} = '%f';
            end
        end
        cols = strjoin(cols,'');
        %delete from variable name list
        varNames(ignoreCols) = [];
   else
       %read all columns
       nCols = numel(varNames);
       cols = repmat('%f',1,nCols);
   end
   %BB: end addition %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   
   % textscan slow, replace with sscanf?
   % http://boffinblogger.blogspot.fr/2012/12/faster-text-file-reading-with-matlab.html
   [samples,pos] = textscan(fid,cols,'CollectOutput',true,...
      'CommentStyle','#','Delimiter',',');
   samples = samples{1};
   
   if nargout == 4
      pos = ftell(fid);
      if pos == -1
         warning('Could not determine position in file.');
      end
   end
   
   fclose(fid);
end
