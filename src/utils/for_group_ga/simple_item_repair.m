function repaired = simple_item_repair(assign, packages, G, target_items_per_group)
% 出现在：group_ga.m
% 简单的商品数量修复策略
    repaired = assign;
    actual_counts = calculate_group_item_counts(repaired, packages, G);
    
    % 重新随机分配直到满足约束或达到最大尝试次数
    max_attempts = 500;
    for attempt = 1:max_attempts
        if all(actual_counts == target_items_per_group)
            return;
        end
        
        % 重新随机分配
        temp_assign = randi(G, size(assign));
        actual_counts = calculate_group_item_counts(temp_assign, packages, G);
        
        if all(actual_counts == target_items_per_group)
            repaired = temp_assign;
            return;
        end
    end
end