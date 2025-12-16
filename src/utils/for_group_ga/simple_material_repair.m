function repaired = simple_material_repair(assign, packages, G)
% 出现在：group_ga.m
% 简单的材质约束修复策略
    repaired = assign;
    max_attempts = 100;
    
    for attempt = 1:max_attempts
        % 检查当前是否满足材质约束
        if check_material_constraint(repaired, packages, G)
            return; % 已满足约束，直接返回
        end
        
        % 找出违反约束的组
        violation_groups = [];
        for g = 1:G
            % 检查单个组是否违反约束
            is_satisfied = true;
            packages_in_group = find(repaired == g);
            if ~isempty(packages_in_group)
                % 收集材质
                all_materials = [];
                for p = 1:length(packages_in_group)
                    pkg_idx = packages_in_group(p);
                    if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
                        pkg_materials = packages.attrs(pkg_idx).material;
                        if isnumeric(pkg_materials)
                            all_materials = [all_materials, pkg_materials(:)'];
                        elseif iscell(pkg_materials)
                            for j = 1:length(pkg_materials)
                                if isnumeric(pkg_materials{j})
                                    all_materials = [all_materials, pkg_materials{j}(:)'];
                                end
                            end
                        end
                    end
                end
                
                % 检查材质数量
                if length(unique(all_materials)) > 2
                    violation_groups = [violation_groups, g];
                end
            end
        end
        
        if isempty(violation_groups)
            break;
        end
        
        % 处理违反约束的组
        target_group = violation_groups(1);
        packages_in_target = find(repaired == target_group);
        
        if ~isempty(packages_in_target)
            % 随机选择一个包移动到其他组
            pkg_to_move = packages_in_target(randi(length(packages_in_target)));
            
            % 尝试找到一个可以接受该包的目标组
            possible_groups = setdiff(1:G, target_group);
            for g = possible_groups
                temp_assign = repaired;
                temp_assign(pkg_to_move) = g;
                
                % 检查移动后是否满足约束
                if check_material_constraint(temp_assign, packages, G)
                    repaired = temp_assign;
                    break;
                end
            end
        end
    end
end