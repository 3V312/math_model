function repaired = repair_item_count(assign, packages, G, target_items_per_group)
% 出现在：group_ga.m
% 修复分配使其满足每组商品数量约束
    repaired = assign;
    
    % 计算每个组的实际商品数量
    actual_counts = calculate_group_item_counts(assign, packages, G);
    
    % 如果已经满足约束，直接返回
    if all(actual_counts == target_items_per_group)
        return;
    end
    
    % 简单修复策略：调整包的分配以满足商品数量约束
    max_attempts = 100;
    for attempt = 1:max_attempts
        temp_assign = repaired;
        actual_counts = calculate_group_item_counts(temp_assign, packages, G);
        
        % 如果满足约束，返回结果
        if all(actual_counts == target_items_per_group)
            repaired = temp_assign;
            return;
        end
        
        % 调整商品数量过多的组
        over_groups = find(actual_counts > target_items_per_group);
        under_groups = find(actual_counts < target_items_per_group);
        
        if ~isempty(over_groups) && ~isempty(under_groups)
            from_group = over_groups(1);
            to_group = under_groups(1);
            
            % 从商品数量过多的组中移动一个包到商品数量过少的组
            packages_in_from = find(temp_assign == from_group);
            if ~isempty(packages_in_from)
                % 选择商品数量最少的包进行移动
                package_sizes = zeros(length(packages_in_from), 1);
                for i = 1:length(packages_in_from)
                    pkg_id = packages_in_from(i);
                    package_sizes(i) = length(packages.list{pkg_id});
                end
                
                % 选择合适的包进行移动
                [~, sorted_idx] = sort(package_sizes);
                for i = 1:length(sorted_idx)
                    pkg_to_move = packages_in_from(sorted_idx(i));
                    pkg_size = length(packages.list{pkg_to_move});
                    
                    % 检查移动后是否更接近目标
                    new_from_count = actual_counts(from_group) - pkg_size;
                    new_to_count = actual_counts(to_group) + pkg_size;
                    
                    if abs(new_from_count - target_items_per_group) < abs(actual_counts(from_group) - target_items_per_group) || ...
                       abs(new_to_count - target_items_per_group) < abs(actual_counts(to_group) - target_items_per_group)
                        temp_assign(pkg_to_move) = to_group;
                        break;
                    end
                end
            end
        else
            break;
        end
    end
    
    % 最后的验证和调整
    actual_counts = calculate_group_item_counts(repaired, packages, G);
    if any(actual_counts ~= target_items_per_group)
        % 如果仍然不满足约束，使用更简单的策略
        repaired = simple_item_repair(assign, packages, G, target_items_per_group);
    end
end