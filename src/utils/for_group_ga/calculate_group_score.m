function score = calculate_group_score(pkg_idx, target_group, assign, packages, remove_materials)
% 出现在：group_ga.m
% 计算将包移动到目标组后的得分
    temp_assign = assign;
    temp_assign(pkg_idx) = target_group;
    
    % 检查移动后是否违反材质约束
    if ~check_material_constraint(temp_assign, packages, target_group)
        score = -100; % 违反约束，给低分
        return;
    end
    
    % 计算材质兼容性得分
    pkg_materials = [];
    if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
        pkg_materials = packages.attrs(pkg_idx).material;
    end
    
    group_materials = get_group_materials(temp_assign, packages, target_group);
    
    % 计算相同材质的数量
    if iscell(pkg_materials)
        pkg_materials_vec = [];
        for m = 1:length(pkg_materials)
            if isnumeric(pkg_materials{m})
                pkg_materials_vec = [pkg_materials_vec, pkg_materials{m}(:)'];
            end
        end
        pkg_materials = pkg_materials_vec;
    end
    
    same_material_count = sum(ismember(group_materials, pkg_materials));
    total_materials = length(group_materials);
    
    % 计算得分：相同材质越多，得分越高
    % 如果组内材质种类较少，也给予奖励
    if ~isempty(group_materials)
        material_diversity = length(unique(group_materials));
        diversity_bonus = 5 * (3 - material_diversity); % 材质越少，奖励越高
        score = same_material_count * 10 + diversity_bonus;
    else
        score = 50; % 空组给予较高分数
    end
end