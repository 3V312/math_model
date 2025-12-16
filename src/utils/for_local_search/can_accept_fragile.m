function can_accept = can_accept_fragile(group_items, data, params)
% 检查小组是否能接受更多易碎品
% 出现在：local_search_optimization.m, repair_violating_fragile_group.m
    can_accept = false;
    
    % 安全检查
    if isempty(group_items) | ~isfield(params.subgroup, 'fragile_volume_ratio_limit')
        can_accept = true;
        return;
    end
    
    current_ratio = 0;
    try
        current_ratio = compute_fragile_ratio(group_items, data);
    catch ME
        fprintf('计算易碎品比例时出错: %s\n', ME.message);
        can_accept = true;  % 出错时保守处理，允许添加
        return;
    end
    
    can_accept = current_ratio < params.subgroup.fragile_volume_ratio_limit * 0.8;
end