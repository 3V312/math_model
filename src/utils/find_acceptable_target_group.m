function target_group = find_acceptable_target_group(assign, packages, G, current_group, pkg_idx)
% 找到可接受的目标组（即使会轻微违反约束）
    target_group = current_group;
    
    % 获取包的材质
    pkg_materials = packages.attrs(pkg_idx).material;
    if ~isnumeric(pkg_materials)
        return;
    end
    
    pkg_materials_vec = pkg_materials(:)';
    
    % 按优先级尝试各组
    for g = 1:G
        if g == current_group
            continue;
        end
        
        packages_in_group = find(assign == g);
        
        if isempty(packages_in_group)
            target_group = g; % 空组是最佳选择
            return;
        end
        
        % 收集目标组材质
        group_materials = [];
        for i = 1:length(packages_in_group)
            group_pkg_idx = packages_in_group(i);
            group_mats = packages.attrs(group_pkg_idx).material;
            if isnumeric(group_mats)
                group_materials = [group_materials, group_mats(:)']; %#ok<AGROW>
            end
        end
        
        % 计算添加后的材质种类数
        potential_materials = [group_materials, pkg_materials_vec];
        potential_unique_count = length(unique(potential_materials));
        
        % 可接受的条件：材质种类不超过3种（轻微违反）
        if potential_unique_count <= 3
            target_group = g;
            return;
        end
    end