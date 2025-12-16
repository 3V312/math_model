function materials = get_group_materials(assign, packages, g)
% 出现在：group_ga.m
% 获取组的材质列表
    packages_in_group = find(assign == g);
    materials = [];
    for p = 1:length(packages_in_group)
        pkg_idx = packages_in_group(p);
        if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
            pkg_materials = packages.attrs(pkg_idx).material;
            if isnumeric(pkg_materials)
                materials = [materials, pkg_materials(:)'];
            elseif iscell(pkg_materials)
                for j = 1:length(pkg_materials)
                    if isnumeric(pkg_materials{j})
                        materials = [materials, pkg_materials{j}(:)'];
                    end
                end
            end
        end
    end
    materials = unique(materials);
end