function target_group = find_best_target_group(assign, packages, G, current_group, pkg_idx, varargin)
% 找到最佳目标组来移动包
% 输入:
%   assign - 当前分配（P x 1向量）
%   packages - 包结构体，包含.attrs字段，其中.material为数值类型
%   G - 大组数量
%   current_group - 当前组编号
%   pkg_idx - 包索引
%   varargin - 可选参数

    % 参数解析
    p = inputParser;
    addParameter(p, 'verbose', false, @islogical);
    parse(p, varargin{:});
    verbose = p.Results.verbose;
    
    best_group = mod(current_group, G) + 1; % 默认下一个组
    best_score = -inf;
    
    % 获取当前包的材质（只处理数值类型）
    pkg_materials = [];
    if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
        if isnumeric(packages.attrs(pkg_idx).material)
            pkg_materials = packages.attrs(pkg_idx).material(:)';
        end
    end
    
    if verbose
        fprintf('寻找包 %d 的目标组\n', pkg_idx);
    end
    
    % 尝试找到最适合的组
    for g = 1:G
        if g == current_group
            continue;
        end
        
        % 获取该组中的所有包
        packages_in_group = find(assign == g);
        
        score = 0;
        
        if isempty(packages_in_group)
            score = 100;  % 空组最高分
            if verbose
                fprintf('  组 %d: 空组, 得分: %d\n', g, score);
            end
        else
            % 收集该组的材质（只处理数值类型）
            max_materials = length(packages_in_group) * 5;
            group_materials = zeros(1, max_materials);
            material_count = 0;
            
            for p = 1:length(packages_in_group)
                group_pkg_idx = packages_in_group(p);
                if isfield(packages.attrs(group_pkg_idx), 'material') && ~isempty(packages.attrs(group_pkg_idx).material)
                    group_pkg_mats = packages.attrs(group_pkg_idx).material;
                    if isnumeric(group_pkg_mats)
                        mat_vec = group_pkg_mats(:)';
                        n_new = length(mat_vec);
                        if material_count + n_new <= max_materials
                            group_materials(material_count+1:material_count+n_new) = mat_vec;
                            material_count = material_count + n_new;
                        end
                    end
                end
            end
            
            % 处理收集到的材质数据
            if material_count > 0
                group_materials = group_materials(1:material_count);
                unique_group_materials = unique(group_materials);
                current_unique_count = length(unique_group_materials);
                
                % 计算添加当前包后的材质情况
                potential_materials = [group_materials, pkg_materials];
                potential_unique_count = length(unique(potential_materials));
                
                % 得分规则
                if potential_unique_count <= 2
                    score = 50 - current_unique_count * 5;  % 材质种类少得分高
                    
                    % 相同材质加分
                    if ~isempty(pkg_materials)
                        common_materials = intersect(unique(pkg_materials), unique_group_materials);
                        score = score + length(common_materials) * 10;
                    end
                    
                    if verbose
                        fprintf('  组 %d: 当前材质%d种, 添加后%d种, 得分: %.2f\n', ...
                            g, current_unique_count, potential_unique_count, score);
                    end
                else
                    score = -100;  % 违反约束，负分
                    if verbose
                        fprintf('  组 %d: 违反约束 (添加后%d种材质), 得分: %.2f\n', g, potential_unique_count, score);
                    end
                end
            else
                % 组内没有材质数据，可视为空组处理
                score = 90;
                if verbose
                    fprintf('  组 %d: 无材质数据, 得分: %.2f\n', g, score);
                end
            end
        end
        
        % 更新最佳组
        if score > best_score
            best_score = score;
            best_group = g;
        end
    end
    
    if verbose
        fprintf('最佳目标组: %d (得分: %.2f)\n', best_group, best_score);
    end
    
    target_group = best_group;
end