

function fragile_ok = check_fragile_constraint(y, items, data, params)
% 易碎品约束专用检查函数
% 输入：
%   y - 商品到小组的分配矩阵
%   items - 商品索引列表
%   data - 商品数据结构体
%   params - 算法参数
% 输出：
%   fragile_ok - 易碎品约束是否满足

    % 默认参数设置
    if ~exist('params', 'var') || isempty(params)
        params = struct();
    end
    
    if ~isfield(params, 'fragile_volume_ratio_limit')
        params.fragile_volume_ratio_limit = 0.4; % 40% 限制
    end
    
    if ~isfield(params, 'verbose')
        params.verbose = false;
    end
    
    % 初始化
    fragile_ok = true;
    
    % 参数验证
    if isempty(y) || isempty(items)
        if params.verbose
            fprintf('警告：空的分配矩阵或商品列表\n');
        end
        return;
    end
    
    % 检查必要字段
    required_fields = {'fragile_level', 'volumes'};
    for field_idx = 1:length(required_fields)
        field_name = required_fields{field_idx};
        if ~isfield(data, field_name) || isempty(data.(field_name))
            error('数据结构体缺少必要字段: %s', field_name);
        end
    end
    
    n_subs = size(y, 2);
    
    for k = 1:n_subs
        % 获取该小组商品索引
        sub_items_logical = y(:, k);
        if sum(sub_items_logical) == 0
            continue; % 跳过空组
        end
        
        sub_items = items(sub_items_logical);
        
        % 计算3级易碎品体积占比
        fragile_ratio = compute_fragile_ratio(sub_items, data, params);
        
        if fragile_ratio > params.fragile_volume_ratio_limit + 1e-6 % 添加微小容差避免浮点误差
            fragile_ok = false;
            if params.verbose
                fprintf('小组 %d 违反易碎品约束：体积占比 %.2f%% (限制 %.2f%%)\n', ...
                    k, fragile_ratio*100, params.fragile_volume_ratio_limit*100);
            end
            return; % 一旦发现违反约束就立即返回
        end
    end
end

function ratio = compute_fragile_ratio(items, data, params)
% 计算3级易碎品体积占比
    
    % 默认参数
    if ~exist('params', 'var') || isempty(params)
        params = struct();
    end
    
    if ~isfield(params, 'verbose')
        params.verbose = false;
    end
    
    ratio = 0;
    
    if isempty(items)
        return;
    end
    
    % 初始化体积统计
    fragile_volume = 0;
    total_volume = 0;
    
    for i = 1:length(items)
        item_idx = items(i);
        
        % 索引验证
        if item_idx < 1 || item_idx > length(data.fragile_level)
            if params.verbose
                fprintf('警告：无效商品索引 %d，跳过\n', item_idx);
            end
            continue;
        end
        
        % 获取易碎等级
        fragile_level = data.fragile_level(item_idx);
        
        % 易碎等级类型转换和验证
        if ischar(fragile_level) || isstring(fragile_level)
            fragile_level = str2double(fragile_level);
        end
        
        % 易碎等级取值范围验证
        if ~isnumeric(fragile_level) || isinf(fragile_level) || isnan(fragile_level) || ...
           fragile_level < 1 || fragile_level > 3
            if params.verbose
                fprintf('警告：商品 %d 易碎等级 %s 无效，跳过\n', ...
                    item_idx, num2str(fragile_level));
            end
            continue;
        end
        
        % 获取体积
        volume = data.volumes(item_idx);
        
        % 体积验证
        if ~isnumeric(volume) || isinf(volume) || isnan(volume) || volume < 0
            if params.verbose
                fprintf('警告：商品 %d 体积 %s 无效，跳过\n', item_idx, num2str(volume));
            end
            continue;
        end
        
        % 累加体积
        total_volume = total_volume + volume;
        
        % 如果是3级易碎品，累加易碎品体积
        if fragile_level == 3
            fragile_volume = fragile_volume + volume;
        end
    end
    
    % 计算比例（避免除零错误）
    if total_volume > 0
        ratio = fragile_volume / total_volume;
    else
        if params.verbose && fragile_volume > 0
            fprintf('警告：小组总体积为零，但存在易碎品\n');
        end
        ratio = 0;
    end
end
