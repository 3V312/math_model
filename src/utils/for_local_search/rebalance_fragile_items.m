% 出现在：local_search_optimization.m
function result = rebalance_fragile_items(y_current, z_current, items, data, params, current_vol_diff)
% 重新平衡易碎品分布
    result.improved = false;
    result.y_new = y_current;
    result.new_vol_diff = current_vol_diff;
    
    % 安全检查
    if isempty(items) | isempty(y_current)
        return;
    end
    
    % 确保y_current的行数与items的长度匹配
    if size(y_current, 1) ~= length(items)
        fprintf('警告：y_current的行数(%d)与items的长度(%d)不匹配\n', size(y_current, 1), length(items));
        return;
    end
    
    % 找出易碎品比例过高和过低的小组
    fragile_ratios = zeros(1, size(y_current, 2));
    
    for group_idx = 1:size(y_current, 2)
        % 安全地获取小组商品
        valid_indices = find(y_current(:, group_idx));
        if isempty(valid_indices)
            fragile_ratios(group_idx) = 0;
            continue;
        end
        
        % 确保valid_indices在items的有效范围内
        valid_indices = valid_indices(valid_indices <= length(items));
        if isempty(valid_indices)
            fragile_ratios(group_idx) = 0;
            continue;
        end
        
        group_items = items(valid_indices);
        fragile_ratios(group_idx) = compute_fragile_ratio(group_items, data);
    end
    
    [~, high_fragile_groups] = find(fragile_ratios > params.subgroup.fragile_volume_ratio_limit);
    [~, low_fragile_groups] = find(fragile_ratios < params.subgroup.fragile_volume_ratio_limit * 0.5);
    
    if isempty(high_fragile_groups) | isempty(low_fragile_groups)
        return;
    end
    
    % 尝试从高比例组转移易碎品到低比例组
    for high_group = high_fragile_groups
        % 安全地获取高比例组的商品
        valid_high_indices = find(y_current(:, high_group));
        valid_high_indices = valid_high_indices(valid_high_indices <= length(items));
        if isempty(valid_high_indices)
            continue;
        end
        
        high_group_items = items(valid_high_indices);
        
        % 安全地找出高比例组中的易碎品
        high_fragile_items = [];
        for i = 1:length(high_group_items)
            item_idx = high_group_items(i);
            % 确保所有条件都是标量逻辑值，使用短路逻辑运算符
            if item_idx >= 1 && item_idx <= length(data) && isfield(data(item_idx), 'fragile_level') && data(item_idx).fragile_level == 3
                high_fragile_items = [high_fragile_items, item_idx];
            end
        end
        
        for low_group = low_fragile_groups
            for fragile_idx = 1:length(high_fragile_items)
                % 安全地查找商品在items中的位置
                item_pos = find(items == high_fragile_items(fragile_idx), 1);
                
                % 确保item_pos有效
                if isempty(item_pos) | item_pos > size(y_current, 1)
                    continue;
                end
                
                y_neighbor = y_current;
                y_neighbor(item_pos, :) = false;
                y_neighbor(item_pos, low_group) = true;
                
                valid = false;
                try
                    valid = validate_assignment(y_neighbor, z_current, items, data, params);
                    % 确保valid是标量，然后使用短路逻辑运算符
                    if isscalar(valid) && valid
                        neighbor_vol_diff = compute_volume_difference(y_neighbor, items, data);
                          
                        if isscalar(neighbor_vol_diff) && neighbor_vol_diff <= current_vol_diff
                            result.improved = true;
                            result.y_new = y_neighbor;
                            result.new_vol_diff = neighbor_vol_diff;
                            return;
                        end
                    end
                catch ME
                    fprintf('验证分配时出错: %s\n', ME.message);
                end
            end
        end
    end
end