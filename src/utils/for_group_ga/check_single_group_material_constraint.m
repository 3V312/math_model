



function is_satisfied = check_single_group_material_constraint(packages_in_group, packages)
% 出现在：group_ga.m
% 检查单个组是否满足材质约束（每个组不超过2种材质）
    is_satisfied = true;
    
    if isempty(packages_in_group)
        return; % 空组自动满足约束
    end
    
    % 收集组内所有材质
    all_materials = [];
    
    for p = 1:length(packages_in_group)
        pkg_idx = packages_in_group(p);
        if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
            pkg_materials = packages.attrs(pkg_idx).material;
            
            % 处理不同类型的材质数据
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
    
    % 检查唯一材质数量是否超过2
    unique_materials = unique(all_materials);
    if length(unique_materials) > 2
        is_satisfied = false;
    end
end