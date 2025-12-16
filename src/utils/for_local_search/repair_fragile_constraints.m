% 出现在：local_search_optimization.m
function y_new = repair_fragile_constraints(y_current, z_current, items, data, params)
% 修复易碎品约束违反
    y_new = y_current;
    
    % 安全检查
    if isempty(items) | isempty(y_new)
        return;
    end
    
    % 确保y_new的行数与items的长度匹配
    if size(y_new, 1) ~= length(items)
        fprintf('警告：y_new的行数(%d)与items的长度(%d)不匹配\n', size(y_new, 1), length(items));
        return;
    end
    
    for group_idx = 1:size(y_new, 2)
        % 安全地获取小组商品
        valid_indices = find(y_new(:, group_idx));
        valid_indices = valid_indices(valid_indices <= length(items));
        
        if isempty(valid_indices)
            continue;
        end
        
        group_items = items(valid_indices);
        fragile_ratio = compute_fragile_ratio(group_items, data);
        
        if fragile_ratio > params.subgroup.fragile_volume_ratio_limit + 1e-6
            y_new = repair_violating_fragile_group(y_new, group_idx, items, data, params);
        end
    end
end