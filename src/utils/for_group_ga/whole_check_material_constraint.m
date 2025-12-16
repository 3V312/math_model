function is_satisfied = whole_check_material_constraint(assign, packages, G)
% 出现在：group_ga.m
% 检查所有大组是否满足材质约束（每组不超过2种材质）
    is_satisfied = true;
    
    for g = 1:G
        % 获取该组中的所有包
        packages_in_group = find(assign == g);
        if isempty(packages_in_group)
            continue;
        end
        
        % 收集该组中的所有材质
        all_materials = [];
        for p = 1:length(packages_in_group)
            pkg_idx = packages_in_group(p);
            if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
                pkg_materials = packages.attrs(pkg_idx).material;
                
                % 处理数值材质数据
                if isnumeric(pkg_materials)
                    pkg_materials_vec = pkg_materials(:)';
                    all_materials = [all_materials, pkg_materials_vec];
                elseif iscell(pkg_materials)
                    for j = 1:length(pkg_materials)
                        if isnumeric(pkg_materials{j})
                            numeric_vec = pkg_materials{j}(:)';
                            all_materials = [all_materials, numeric_vec];
                        end
                    end
                end
            end
        end
        
        % 计算唯一材质数量
        if ~isempty(all_materials)
            unique_materials = unique(all_materials);
            
            % 如果材质种类超过2种，约束不满足
            if length(unique_materials) > 2
                is_satisfied = false;
                return;
            end
        end
    end
end