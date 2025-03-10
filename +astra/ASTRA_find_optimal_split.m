% ASTRA_FIND_OPTIMAL_SPLIT Find optimal split of data and make the blocks sufficiently small for
% limited GPU memory
%
% split = ASTRA_find_optimal_split(cfg, num_gpu, angle_blocks, propagator)
%
% Inputs:
%     **cfg - config structure generated by ASTRA_initialize
%     **num_gpu - number of gpu to split the data 
%     **angle_blocks - number of angular blocks (ie in SART method or FSC)
%     **propagator - which propagator should be assumed : FWD, BACK, both (default)
% Outputs:
%     ++split - volume / angle split - [split_x,split_y,split_z,split_angles]   

function split = ASTRA_find_optimal_split(cfg, num_gpu, angle_blocks, propagator)
  
    if gpuDeviceCount == 0
        split = 1; 
        return
    end
    
    gpu = gpuDevice;
    if nargin < 2 || num_gpu == 0
        num_gpu = 1; 
    end
    if nargin < 3
        angle_blocks = 1; 
    end
    if nargin < 4
        propagator = 'both';
    end
    
    Nangles = cfg.iProjAngles / angle_blocks;
    if isfield(cfg, 'Grouping')
        Nangles = min(Nangles, cfg.Grouping);
    end
    
    split = [1,1,1]; 
    if ismember(lower(propagator), {'fwd','both'})
        split = max(split, ceil([cfg.iVolX, cfg.iVolY, cfg.iVolZ] /  4096 )); % texture memory limit
        split = max(split, [1,1,ceil( (cfg.iVolX*cfg.iVolY*cfg.iVolZ*4) /  1.024e9 / prod(split)/num_gpu)]); % texture memory limit
    end
    split = max(split, [1,1,split(3)*ceil( ((cfg.iVolX*cfg.iVolY*cfg.iVolZ*4)/ prod(split)/num_gpu) / (gpu.AvailableMemory/2 - min(1.1e9, cfg.iVolX*cfg.iVolY*cfg.iVolZ*4)) )]); % gpu memory limit 
    split = max(split, [1,1,split(3)*ceil( ((cfg.iVolX*cfg.iVolY*cfg.iVolZ  )/ prod(split)/num_gpu) / double(intmax('int32')) )]); % maximal array on GPU limit 

    if ismember(lower(propagator), {'back','both'})
        % if projection would be larger than 8192x8192 -> split the reconstruction volume 
        split = max(split, [cfg.iProjU, cfg.iProjU,  cfg.iProjV]/8192 ); % texture memory limit 
    end

    % projection size limitation  +   astra allows only < 1024 angles
    split(4)  = max(ceil(Nangles/1024), ceil( (cfg.iProjU*cfg.iProjV*min(1024,Nangles)*4) / gpu.TotalMemory/num_gpu)); % gpu memory limit 

    % RAM limits 
    if cfg.iVolX*cfg.iVolY*cfg.iVolZ > 2e6
        freemem = 0.8 * utils.check_available_memory; 
        split(4)  = max(split(4), num_gpu*(4*(cfg.iProjU*cfg.iProjV*cfg.iProjAngles...
                                            + cfg.iVolX*cfg.iVolY*cfg.iVolZ*(1+1/prod(split(1:3)))))...
                                            / (freemem * 1e6) ); % RAM memory limit 
    end
    split(4) = ceil(split(4)); 
    split(1:3) = 2.^nextpow2(split(1:3));
%     if any(split ~= 1)
%         fprintf('Automatically splitting to %ix%ix%ix(%i) cubes \n', split);
%     end

end
