% 出现在：local_search_optimization.m, repair_fragile_constraints.m
function y_new = repair_violating_fragile_group(y_current, violating_group, items, data, params)
% 修复违反易碎品约束的小组
    
    y_new = y_current;
    
    % 安全检查
    if isempty(items) | isempty(y_new) | violating_group < 1 || violating_group > size(y_new, 2)
        return;
    end
    
    % 确保y_new的行数与items的长度匹配
    if size(y_new, 1) ~= length(items)
        fprintf('警告：y_new的行数(%d)与items的长度(%d)不匹配\n', size(y_new, 1), length(items));
        return;
    end
    
    % 检查y_new的列数（小组数量）
    n_subs = size(y_new, 2);
    if n_subs <= 1
        % 如果只有1个小组，无法进行转移，直接返回
        return;
    end
    
    % 安全地获取小组商品
    valid_group_indices = find(y_new(:, violating_group));
    valid_group_indices = valid_group_indices(valid_group_indices <= length(items));
    if isempty(valid_group_indices)
        return;
    end
    group_items = items(valid_group_indices);
    
    % 安全地找出该小组中的易碎品
    fragile_in_group = [];
    for i = 1:length(group_items)
        item_idx = group_items(i);  % 这是全局商品索引
        % 确保所有条件都是标量逻辑值
        if item_idx >= 1 && item_idx <= length(data) && isfield(data(item_idx), 'fragile_level') && data(item_idx).fragile_level == 3
            fragile_in_group = [fragile_in_group, item_idx];
        end
    end
    
    if isempty(fragile_in_group)
        return;
    end
    
    % 尝试将易碎品转移到其他小组
    for i = 1:length(fragile_in_group)
        fragile_item = fragile_in_group(i);  % 全局商品索引
        
        % 找到这个商品在当前items列表中的位置
        item_pos = find(items == fragile_item, 1);
        
        % 如果找不到（商品已被丢弃）或位置无效，跳过
        if isempty(item_pos) | item_pos < 1 || item_pos > size(y_new, 1)
            continue;
        end
        
        for target_group = 1:size(y_new, 2)
            if target_group == violating_group
                continue;
            end
            
            % 安全地获取目标小组商品
            valid_target_indices = find(y_new(:, target_group));
            valid_target_indices = valid_target_indices(valid_target_indices <= length(items));
            target_items = items(valid_target_indices);
            
            if can_accept_fragile(target_items, data, params)
                % 执行转移
                y_new(item_pos, :) = false;
                y_new(item_pos, target_group) = true;
                
                % 检查转移后是否还违反约束
                new_valid_indices = find(y_new(:, violating_group));
                new_valid_indices = new_valid_indices(new_valid_indices <= length(items));
                if ~isempty(new_valid_indices)
                    current_group_items = items(new_valid_indices);
                    if compute_fragile_ratio(current_group_items, data) <= params.subgroup.fragile_volume_ratio_limit
                        break;
                    end
                end
            end
        end
    end
end