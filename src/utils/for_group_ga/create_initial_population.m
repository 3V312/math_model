function population = create_initial_population(n_individuals, n_packages, G, min_per_group, max_per_group, packages)
% 出现在：group_ga.m
% 创建遗传算法的初始种群
    population = zeros(n_individuals, n_packages);
    
    for i = 1:n_individuals
        % 生成初始随机分配
        individual = zeros(1, n_packages);
        
        % 确保每个组至少有min_per_group个包
        for g = 1:G
            available_packages = find(individual == 0);
            if ~isempty(available_packages) && length(available_packages) >= min_per_group
                selected_packages = available_packages(randperm(length(available_packages), min_per_group));
                individual(selected_packages) = g;
            end
        end
        
        % 随机分配剩余的包
        remaining_packages = find(individual == 0);
        if ~isempty(remaining_packages)
            individual(remaining_packages) = randi(G, 1, length(remaining_packages));
        end
        
        % 修复包数量约束
        individual = repair_package_count(individual, G, min_per_group, max_per_group);
        
        % 修复商品数量约束
        individual = repair_item_count(individual, packages, G, 12);
        
        % 修复材质约束
        individual = simple_material_repair(individual, packages, G);
        
        population(i, :) = individual;
    end
end

function repaired = repair_package_count(assign, G, min_per_group, max_per_group)
% 辅助函数：修复包数量约束
    repaired = assign;
    
    for g = 1:G
        % 计算当前组的包数量
        current_count = sum(repaired == g);
        
        % 处理包数量不足的情况
        if current_count < min_per_group
            needed = min_per_group - current_count;
            % 从其他组随机选择包移动到当前组
            other_groups = find(repaired ~= g);
            if length(other_groups) >= needed
                selected = other_groups(randperm(length(other_groups), needed));
                repaired(selected) = g;
            end
        end
    end
    
    % 处理包数量过多的情况
    for g = 1:G
        current_count = sum(repaired == g);
        if current_count > max_per_group
            excess = current_count - max_per_group;
            % 将多余的包移动到其他组
            packages_in_group = find(repaired == g);
            if length(packages_in_group) >= excess
                to_move = packages_in_group(randperm(length(packages_in_group), excess));
                % 随机选择目标组
                for i = 1:length(to_move)
                    target_groups = setdiff(1:G, g);
                    if ~isempty(target_groups)
                        target_group = target_groups(randi(length(target_groups)));
                        repaired(to_move(i)) = target_group;
                    end
                end
            end
        end
    end
end