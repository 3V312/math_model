function best_candidate = find_best_forced_move_candidate(assign, packages, current_group, materials_to_remove, packages_in_group)
% 找到最适合强制移动的候选包
    best_candidate = 0;
    best_score = -inf;
    
    for i = 1:length(packages_in_group)
        pkg_idx = packages_in_group(i);
        
        % 确保包仍在当前组中
        if assign(pkg_idx) ~= current_group
            continue;
        end
        
        pkg_materials = packages.attrs(pkg_idx).material;
        if isnumeric(pkg_materials)
            % 评分：包含要移除的材质越多，优先级越高
            remove_count = sum(ismember(pkg_materials, materials_to_remove));
            if remove_count > 0
                score = remove_count * 10;
                
                % 包体积小优先（移动影响小）
                if isfield(packages, 'volumes') && ~isempty(packages.volumes)
                    volume = packages.volumes(pkg_idx);
                    score = score - volume * 0.01; % 体积小加分
                end
                
                if score > best_score
                    best_score = score;
                    best_candidate = pkg_idx;
                end
            end
        end
    end
end