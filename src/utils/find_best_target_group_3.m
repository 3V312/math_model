function target_group = find_best_target_group_3(assign, packages, G, current_group, pkg_idx, varargin)
% 找到最佳目标组来移动包（支持问题三的约束）
% 输入:
%   assign - 当前分配（P x 1向量）
%   packages - 包结构体，包含.attrs字段，其中.material为数值类型
%   G - 大组数量
%   current_group - 当前组编号
%   pkg_idx - 包索引
%   varargin - 可选参数，包括'customs_map', 'buffer_groups', 'max_fragile_ratio'

    % 参数解析
    p = inputParser;
    addParameter(p, 'verbose', false, @islogical);
    addParameter(p, 'customs_map', [], @(x) isempty(x) || isstruct(x));
    addParameter(p, 'buffer_groups', [], @(x) isempty(x) || isvector(x));
    addParameter(p, 'max_fragile_ratio', 0.4, @isnumeric);
    parse(p, varargin{:});
    verbose = p.Results.verbose;
    customs_map = p.Results.customs_map;
    buffer_groups = p.Results.buffer_groups;
    max_fragile_ratio = p.Results.max_fragile_ratio;
    
    best_group = mod(current_group, G) + 1; % 默认下一个组
    best_score = -inf;
    
    % 获取当前包的材质（只处理数值类型）
    pkg_materials = [];
    if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
        if isnumeric(packages.attrs(pkg_idx).material)
            pkg_materials = packages.attrs(pkg_idx).material(:)';
        end
    end
    
    % 获取当前包的报关信息（如果有）
    pkg_customs_type = 0;
    if isfield(packages.attrs(pkg_idx), 'customs_type') && ~isempty(packages.attrs(pkg_idx).customs_type)
        customs_val = packages.attrs(pkg_idx).customs_type;
        % 转换为数值类型：A->1, B->2, C->3
        if ischar(customs_val) || isstring(customs_val)
            customs_str = lower(char(customs_val));
            if contains(customs_str, 'a')
                pkg_customs_type = 1;
            elseif contains(customs_str, 'b')
                pkg_customs_type = 2;
            elseif contains(customs_str, 'c')
                pkg_customs_type = 3;
            else
                warning('未知的报关类型: %s', customs_str);
            end
        elseif isnumeric(customs_val)
            pkg_customs_type = customs_val;
        end
    end
    
    % 获取当前包的易碎级别
    pkg_fragile_level = 0;
    if isfield(packages.attrs(pkg_idx), 'fragile_level') && ~isempty(packages.attrs(pkg_idx).fragile_level)
        fragile_val = packages.attrs(pkg_idx).fragile_level;
        if ischar(fragile_val) || isstring(fragile_val)
            pkg_fragile_level = str2double(fragile_val);
        elseif isnumeric(fragile_val)
            pkg_fragile_level = fragile_val;
        end
        % 验证易碎级别范围
        if pkg_fragile_level < 1 || pkg_fragile_level > 3
            warning('易碎级别 %d 超出有效范围(1-3)，已重置', pkg_fragile_level);
            pkg_fragile_level = 0;
        end
    end
    
    % 获取当前包的体积
    pkg_volume = 0;
    if isfield(packages, 'volumes') && ~isempty(packages.volumes) && length(packages.volumes) >= pkg_idx
        pkg_volume = packages.volumes(pkg_idx);
    end
    
    % 获取当前包的时效需求
    pkg_time_requirement = [];
    if isfield(packages.attrs(pkg_idx), 'time_requirement') && ~isempty(packages.attrs(pkg_idx).time_requirement)
        pkg_time_requirement = packages.attrs(pkg_idx).time_requirement;
    end
    
    if verbose
        fprintf('寻找包 %d 的目标组', pkg_idx);
    end
    
    % 尝试找到最适合的组
    for g = 1:G
        if g == current_group
            continue;
        end
        
        % 检查是否为缓冲组，如果是则跳过（除非有其他处理逻辑）
        if ~isempty(buffer_groups) && ismember(g, buffer_groups)
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
            
            % 收集该组的报关类型
            group_customs_types = [];
            customs_count = 0;
            
            % 收集该组的易碎品信息
            group_fragile_volumes = 0;  % 易碎品总体积
            group_total_volume = 0;     % 组总体积
            group_has_level2_fragile = false;  % 是否有2级易碎品
            group_has_level3_fragile = false;  % 是否有3级易碎品
            
            % 收集该组的时效需求
            group_time_requirements = {};
            time_req_count = 0;
            
            for p = 1:length(packages_in_group)
                group_pkg_idx = packages_in_group(p);
                
                % 收集材质信息
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
                
                % 收集报关类型信息（确保转换为数值类型）
                if isfield(packages.attrs(group_pkg_idx), 'customs_type') && ~isempty(packages.attrs(group_pkg_idx).customs_type)
                    customs_val = packages.attrs(group_pkg_idx).customs_type;
                    % 转换为数值类型：A->1, B->2, C->3
                    if ischar(customs_val) || isstring(customs_val)
                        customs_str = lower(char(customs_val));
                        if contains(customs_str, 'a')
                            customs_val = 1;
                        elseif contains(customs_str, 'b')
                            customs_val = 2;
                        elseif contains(customs_str, 'c')
                            customs_val = 3;
                        end
                    end
                    if isnumeric(customs_val) && customs_val >= 1 && customs_val <= 3
                        customs_count = customs_count + 1;
                        group_customs_types(end+1) = customs_val; %#ok<AGROW>
                    end
                end
                
                % 收集易碎品信息
                if isfield(packages.attrs(group_pkg_idx), 'fragile_level') && ~isempty(packages.attrs(group_pkg_idx).fragile_level)
                    fragile_val = packages.attrs(group_pkg_idx).fragile_level;
                    if ischar(fragile_val) || isstring(fragile_val)
                        fragile_val = str2double(fragile_val);
                    end
                    
                    if isnumeric(fragile_val)
                        if fragile_val == 2
                            group_has_level2_fragile = true;
                        elseif fragile_val == 3
                            group_has_level3_fragile = true;
                            % 累加易碎品体积
                            if isfield(packages, 'volumes') && ~isempty(packages.volumes) && length(packages.volumes) >= group_pkg_idx
                                group_fragile_volumes = group_fragile_volumes + packages.volumes(group_pkg_idx);
                            end
                        end
                    end
                end
                
                % 累加总体积
                if isfield(packages, 'volumes') && ~isempty(packages.volumes) && length(packages.volumes) >= group_pkg_idx
                    group_total_volume = group_total_volume + packages.volumes(group_pkg_idx);
                end
                
                % 收集时效需求
                if isfield(packages.attrs(group_pkg_idx), 'time_requirement') && ~isempty(packages.attrs(group_pkg_idx).time_requirement)
                    time_req_count = time_req_count + 1;
                    group_time_requirements{time_req_count} = packages.attrs(group_pkg_idx).time_requirement;
                end
            end
            
            % 约束检查
            valid = true;
            violation_penalty = 0;
            
            % 1. 时效约束检查
            if ~isempty(pkg_time_requirement) && time_req_count > 0
                unique_time_reqs = unique(group_time_requirements);
                if length(unique_time_reqs) > 0 && ~any(strcmp(pkg_time_requirement, unique_time_reqs))
                    valid = false;
                    violation_penalty = violation_penalty + 300;  % 时效约束违反惩罚
                    if verbose
                        fprintf('  组 %d: 违反时效约束\n', g);
                    end
                end
            end
            
            % 2. 报关约束检查（使用数值类型比较）
            if pkg_customs_type > 0 && customs_count > 0
                if ~ismember(pkg_customs_type, group_customs_types)
                    % 如果组内已有其他报关类型，检查是否允许混合
                    if isfield(customs_map, num2str(pkg_customs_type))
                        allowed_mixes = customs_map.(num2str(pkg_customs_type));
                        % 确保allowed_mixes是数值类型
                        if iscell(allowed_mixes)
                            allowed_mixes = cell2mat(allowed_mixes);
                        end
                        if ~any(ismember(group_customs_types, allowed_mixes))
                            valid = false;
                            violation_penalty = violation_penalty + 200;  % 报关约束违反惩罚
                            if verbose
                                fprintf('  组 %d: 违反报关约束\n', g);
                            end
                        end
                    else
                        valid = false;
                        violation_penalty = violation_penalty + 200;
                    end
                end
                % 检查添加后是否超过2种报关类型
                unique_customs = unique([group_customs_types, pkg_customs_type]);
                if length(unique_customs) > 2
                    valid = false;
                    violation_penalty = violation_penalty + 150;
                end
            end
            
            % 3. 易碎品约束检查
            % 检查3级易碎品是否有2级易碎品保护
            if pkg_fragile_level == 3 && ~group_has_level2_fragile
                valid = false;
                violation_penalty = violation_penalty + 250;  % 缓冲保护约束违反惩罚
                if verbose
                    fprintf('  组 %d: 违反缓冲保护约束\n', g);
                end
            end
            
            % 检查易碎品体积占比
            if pkg_fragile_level == 3 && pkg_volume > 0
                potential_fragile_volume = group_fragile_volumes + pkg_volume;
                potential_total_volume = group_total_volume + pkg_volume;
                if potential_total_volume > 0
                    potential_fragile_ratio = potential_fragile_volume / potential_total_volume;
                    if potential_fragile_ratio > max_fragile_ratio
                        valid = false;
                        violation_penalty = violation_penalty + 180;  % 易碎品体积约束违反惩罚
                        if verbose
                            fprintf('  组 %d: 违反易碎品体积约束 (比例: %.2f > %.2f)\n', ...
                                g, potential_fragile_ratio, max_fragile_ratio);
                        end
                    end
                end
            end
            
            % 如果有严重约束违反，直接跳过
            if ~valid
                score = violation_penalty;  % 违反约束，惩罚值
                if verbose
                    fprintf('  组 %d: 违反约束, 惩罚得分: %.2f\n', g, score);
                end
                continue;
            end
            
            % 材质约束检查和评分
            valid_material = true;
            if material_count > 0
                group_materials = group_materials(1:material_count);
                unique_group_materials = unique(group_materials);
                current_unique_count = length(unique_group_materials);
                
                % 计算添加当前包后的材质情况
                potential_materials = [group_materials, pkg_materials];
                potential_unique_count = length(unique(potential_materials));
                
                % 材质约束检查
                if potential_unique_count > 2
                    valid_material = false;
                    score = 150;  % 违反材质约束，惩罚值
                    if verbose
                        fprintf('  组 %d: 违反材质约束 (添加后%d种材质), 得分: %.2f\n', g, potential_unique_count, score);
                    end
                    continue;
                end
                
                % 材质匹配评分
                score = 50 - current_unique_count * 5;  % 材质种类少得分高
                
                % 相同材质加分
                if ~isempty(pkg_materials)
                    common_materials = intersect(unique(pkg_materials), unique_group_materials);
                    score = score + length(common_materials) * 10;
                end
            else
                % 组内没有材质数据，可视为空组处理
                score = 90;
            end
            
            % 报关类型匹配加分
            if pkg_customs_type > 0 && any(group_customs_types == pkg_customs_type)
                score = score + 15;
            end
            
            % 易碎品相关加分
            % 2级易碎品对3级易碎品有保护作用，优先组合
            if pkg_fragile_level == 3 && group_has_level2_fragile
                score = score + 20;  % 优先保护3级易碎品
            end
            
            % 避免将3级易碎品加入已有3级易碎品的组（分散风险）
            if pkg_fragile_level == 3 && group_has_level3_fragile
                score = score - 10;  % 降低得分
            end
            
            % 时效匹配加分
            if ~isempty(pkg_time_requirement) && time_req_count > 0 && any(strcmp(pkg_time_requirement, group_time_requirements))
                score = score + 25;  % 时效匹配重要性高
            end
            
            % 组大小加分（小群组优先）
            group_size_penalty = length(packages_in_group) * 0.5;
            score = score - group_size_penalty;
            
            % 体积平衡加分
            if pkg_volume > 0 && group_total_volume > 0
                % 避免体积过大的组
                if group_total_volume > 10000  % 假设10000为较大体积阈值
                    score = score - 15;
                end
            end
            
            if verbose
                fprintf('  组 %d: 材质%d种, 易碎品保护:%d, 时效匹配:%d, 得分: %.2f\n', ...
                    g, current_unique_count, group_has_level2_fragile, ...
                    any(strcmp(pkg_time_requirement, group_time_requirements)), score);
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