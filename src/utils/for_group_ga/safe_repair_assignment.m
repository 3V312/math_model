function repaired = safe_repair_assignment(assign, packages, G, min_per_group, max_per_group)
% 安全修复分配方案，确保每组包数量在限制范围内
    repaired = assign;
    
    % 计算每个组的包数量
    group_counts = zeros(1, G);
    for g = 1:G
        group_counts(g) = sum(repaired == g);
    end
    
    % 处理包数量超过最大值的组
    over_groups = find(group_counts > max_per_group);
    for g = over_groups
        excess = group_counts(g) - max_per_group;
        if excess <= 0
            continue;
        end
        
        % 找出该组中的所有包
        members = find(repaired == g);
        
        % 随机选择要移动的包
        to_move = randperm(length(members), excess);
        move_candidates = members(to_move);
        
        % 移动包到未满的组
        for i = 1:length(move_candidates)
            % 找出未满的组
            under_groups = find(group_counts < max_per_group);
            if isempty(under_groups)
                break;
            end
            
            % 随机选择一个目标组
            target_group = under_groups(randi(length(under_groups)));
            
            % 移动包
            repaired(move_candidates(i)) = target_group;
            group_counts(g) = group_counts(g) - 1;
            group_counts(target_group) = group_counts(target_group) + 1;
        end
    end
    
    % 处理包数量少于最小值的组
    under_groups = find(group_counts < min_per_group);
    for g = under_groups
        deficit = min_per_group - length(members);
        if deficit > 0
            % 从成员最多的组中借调
            while deficit > 0
                [~, source_group] = max(group_counts);
                if group_counts(source_group) <= min_per_group
                    break; % 无法再借调
                end
                
                % 从源组中选择一个成员
                source_members = find(repaired == source_group);
                if ~isempty(source_members)
                    member_to_move = source_members(1);
                    repaired(member_to_move) = g;
                    group_counts(source_group) = group_counts(source_group) - 1;
                    group_counts(g) = group_counts(g) + 1;
                    deficit = deficit - 1;
                else
                    break;
                end
            end
        end
    end
end