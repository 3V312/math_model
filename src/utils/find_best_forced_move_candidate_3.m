function best_candidate = find_best_forced_move_candidate_3(assign, packages, current_group, materials_to_remove, packages_in_group, varargin)
% 找到最适合强制移动的候选包（支持问题三的约束）
% 输入:
%   assign - 当前分配（P x 1向量）
%   packages - 包结构体
%   current_group - 当前组编号
%   materials_to_remove - 需要移除的材质列表
%   packages_in_group - 当前组内的包索引列表
%   varargin - 可选参数，包括'customs_types_to_remove'（需要移除的报关类型）
    
    % 参数解析
    p = inputParser;
    addParameter(p, 'verbose', false, @islogical);
    addParameter(p, 'customs_types_to_remove', [], @(x) iscell(x) || isnumeric(x));
    parse(p, varargin{:});
    verbose = p.Results.verbose;
    customs_types_to_remove = p.Results.customs_types_to_remove;
    
    % 确保customs_types_to_remove为数值类型（与数据加载函数保持一致）
    if iscell(customs_types_to_remove)
        % 将字符类型转换为数值类型：A->1, B->2, C->3
        numeric_customs_types = zeros(size(customs_types_to_remove));
        for i = 1:length(customs_types_to_remove)
            if ischar(customs_types_to_remove{i}) || isstring(customs_types_to_remove{i})
                str_type = char(customs_types_to_remove{i});
                if strcmpi(str_type, 'A')
                    numeric_customs_types(i) = 1;
                elseif strcmpi(str_type, 'B')
                    numeric_customs_types(i) = 2;
                elseif strcmpi(str_type, 'C')
                    numeric_customs_types(i) = 3;
                else
                    warning('未知的报关类型: %s', str_type);
                    numeric_customs_types(i) = 0; % 无效值标记
                end
            elseif isnumeric(customs_types_to_remove{i})
                numeric_customs_types(i) = customs_types_to_remove{i};
            else
                warning('无效的报关类型格式');
                numeric_customs_types(i) = 0; % 无效值标记
            end
        end
        % 过滤无效值
        valid_indices = numeric_customs_types ~= 0;
        if any(valid_indices)
            customs_types_to_remove = numeric_customs_types(valid_indices);
        else
            customs_types_to_remove = [];
        end
    end
    
    best_candidate = 0;
    best_score = -inf;
    
    for i = 1:length(packages_in_group)
        pkg_idx = packages_in_group(i);
        
        % 确保包仍在当前组中
        if assign(pkg_idx) ~= current_group
            continue;
        end
        
        score = 0;
        
        % 基于材质的评分
        if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
            pkg_materials = packages.attrs(pkg_idx).material;
            if isnumeric(pkg_materials)
                % 评分：包含要移除的材质越多，优先级越高
                remove_count = sum(ismember(pkg_materials, materials_to_remove));
                if remove_count > 0
                    score = score + remove_count * 10;
                end
            end
        end
        
        % 基于报关类型的评分
        if isfield(packages.attrs(pkg_idx), 'customs_type') && ~isempty(packages.attrs(pkg_idx).customs_type)
            pkg_customs_type = packages.attrs(pkg_idx).customs_type;
            
            % 确保pkg_customs_type为数值类型
            if ischar(pkg_customs_type) || isstring(pkg_customs_type)
                str_type = char(pkg_customs_type);
                if strcmpi(str_type, 'A')
                    pkg_customs_type = 1;
                elseif strcmpi(str_type, 'B')
                    pkg_customs_type = 2;
                elseif strcmpi(str_type, 'C')
                    pkg_customs_type = 3;
                else
                    pkg_customs_type = NaN; % 无效类型标记
                end
            end
            
            if isnumeric(pkg_customs_type) && ~isnan(pkg_customs_type) && any(ismember(pkg_customs_type, customs_types_to_remove))
                score = score + 15;  % 报关类型匹配加分更高
            end
        end
        
        % 包体积小优先（移动影响小）
        if isfield(packages, 'volumes') && ~isempty(packages.volumes)
            volume = packages.volumes(pkg_idx);
            score = score - volume * 0.01; % 体积小加分
        end
        
        % 包重量小优先（如果有重量信息）
        if isfield(packages.attrs(pkg_idx), 'weight') && ~isempty(packages.attrs(pkg_idx).weight)
            weight = packages.attrs(pkg_idx).weight;
            if isnumeric(weight)
                score = score - weight * 0.005; % 重量小加分
            end
        end
        
        % 检查是否同时满足材质和报关约束移除条件
        if isfield(packages.attrs(pkg_idx), 'material') && isfield(packages.attrs(pkg_idx), 'customs_type') && ...
           ~isempty(packages.attrs(pkg_idx).material) && ~isempty(packages.attrs(pkg_idx).customs_type) && ...
           isnumeric(packages.attrs(pkg_idx).material)
            
            % 确保报关类型为数值类型
            pkg_customs_type = packages.attrs(pkg_idx).customs_type;
            if ischar(pkg_customs_type) || isstring(pkg_customs_type)
                str_type = char(pkg_customs_type);
                if strcmpi(str_type, 'A')
                    pkg_customs_type = 1;
                elseif strcmpi(str_type, 'B')
                    pkg_customs_type = 2;
                elseif strcmpi(str_type, 'C')
                    pkg_customs_type = 3;
                end
            end
            
            if isnumeric(pkg_customs_type) && any(ismember(pkg_customs_type, customs_types_to_remove)) && ...
               any(ismember(packages.attrs(pkg_idx).material, materials_to_remove))
                score = score + 20;  % 同时满足两个条件的包有额外加分
            end
        end
        
        % 缓冲保护约束检查 - 避免移动关键的2级易碎品
        if isfield(packages.attrs(pkg_idx), 'fragile_level') && ~isempty(packages.attrs(pkg_idx).fragile_level)
            fragile_level = packages.attrs(pkg_idx).fragile_level;
            if isnumeric(fragile_level) && fragile_level == 2
                % 计算当前组中是否有3级易碎品需要这个2级易碎品保护
                has_level3_in_group = false;
                for j = 1:length(packages_in_group)
                    other_pkg_idx = packages_in_group(j);
                    if other_pkg_idx == pkg_idx
                        continue;
                    end
                    if isfield(packages.attrs(other_pkg_idx), 'fragile_level') && ~isempty(packages.attrs(other_pkg_idx).fragile_level) && ...
                       packages.attrs(other_pkg_idx).fragile_level == 3
                        has_level3_in_group = true;
                        break;
                    end
                end
                
                if has_level3_in_group
                    % 如果该组中有3级易碎品，移动2级易碎品会破坏缓冲保护
                    score = score - 1000;  % 大幅降低分数，避免移动关键的2级易碎品
                end
            end
        end
        
        % 移动后约束违反检查
        if isfield(packages.attrs(pkg_idx), 'fragile_level') && ~isempty(packages.attrs(pkg_idx).fragile_level)
            fragile_level = packages.attrs(pkg_idx).fragile_level;
            
            % 确保易碎级别为数值
            if ischar(fragile_level) || isstring(fragile_level)
                fragile_level = str2double(fragile_level);
            end
            
            % 易碎等级验证
            if ~isnumeric(fragile_level) || fragile_level < 1 || fragile_level > 3
                continue;
            end
            
            % 检查是否是3级易碎品
            if fragile_level == 3
                % 如果移除3级易碎品，评估对组内其他3级易碎品的影响
                remaining_level3_count = 0;
                has_level2_protection = false;
                
                for j = 1:length(packages_in_group)
                    other_pkg_idx = packages_in_group(j);
                    if other_pkg_idx == pkg_idx
                        continue;
                    end
                    
                    if isfield(packages.attrs(other_pkg_idx), 'fragile_level') && ~isempty(packages.attrs(other_pkg_idx).fragile_level)
                        other_frag_level = packages.attrs(other_pkg_idx).fragile_level;
                        
                        if ischar(other_frag_level) || isstring(other_frag_level)
                            other_frag_level = str2double(other_frag_level);
                        end
                        
                        if isnumeric(other_frag_level)
                            if other_frag_level == 3
                                remaining_level3_count = remaining_level3_count + 1;
                            elseif other_frag_level == 2
                                has_level2_protection = true;
                            end
                        end
                    end
                end
                
                % 如果移动后该组仍然有3级易碎品但没有2级易碎品保护，则增加分数
                % 这表示移动该包可能导致新的约束违反，应该避免
                if remaining_level3_count > 0 && ~has_level2_protection
                    score = score - 15; % 降低分数以避免移动
                    if verbose
                        fprintf('  包 %d: 移动可能导致其他3级易碎品失去保护，分数降低15\n', pkg_idx);
                    end
                end
            elseif fragile_level == 2
                % 评估移动2级易碎品的影响
                level3_in_group = false;
                other_level2_in_group = false;
                
                for j = 1:length(packages_in_group)
                    other_pkg_idx = packages_in_group(j);
                    if other_pkg_idx == pkg_idx
                        continue;
                    end
                    
                    if isfield(packages.attrs(other_pkg_idx), 'fragile_level') && ~isempty(packages.attrs(other_pkg_idx).fragile_level)
                        other_frag_level = packages.attrs(other_pkg_idx).fragile_level;
                        
                        if ischar(other_frag_level) || isstring(other_frag_level)
                            other_frag_level = str2double(other_frag_level);
                        end
                        
                        if isnumeric(other_frag_level)
                            if other_frag_level == 3
                                level3_in_group = true;
                            elseif other_frag_level == 2
                                other_level2_in_group = true;
                            end
                        end
                    end
                end
                
                % 如果该组有3级易碎品且没有其他2级易碎品保护，则降低分数
                if level3_in_group && ~other_level2_in_group
                    score = score - 20; % 大幅降低分数，避免移除唯一的保护者
                    if verbose
                        fprintf('  包 %d: 是组内唯一的2级易碎品保护者，分数降低20\n', pkg_idx);
                    end
                end
            end
            
            % 检查易碎品体积占比约束
            % 计算移动后该包原组的易碎品体积占比
            group_volume = 0;
            fragile_volume = 0;
            
            for j = 1:length(packages_in_group)
                other_pkg_idx = packages_in_group(j);
                if other_pkg_idx == pkg_idx
                    continue; % 模拟移动后的状态
                end
                
                % 获取体积
                if isfield(packages, 'volumes') && ~isempty(packages.volumes(other_pkg_idx))
                    vol = packages.volumes(other_pkg_idx);
                    if isnumeric(vol) && vol >= 0
                        group_volume = group_volume + vol;
                        
                        % 检查是否是易碎品
                        if isfield(packages.attrs(other_pkg_idx), 'fragile_level') && ~isempty(packages.attrs(other_pkg_idx).fragile_level)
                            other_frag_level = packages.attrs(other_pkg_idx).fragile_level;
                            if ischar(other_frag_level) || isstring(other_frag_level)
                                other_frag_level = str2double(other_frag_level);
                            end
                            if isnumeric(other_frag_level) && other_frag_level == 3
                                fragile_volume = fragile_volume + vol;
                            end
                        end
                    end
                end
            end
            
            % 如果移动后易碎品体积占比仍然过高，降低分数
            if group_volume > 0
                new_fragile_ratio = fragile_volume / group_volume;
                if new_fragile_ratio > 0.4
                    score = score - 10; % 降低分数以避免移动后仍违反约束
                    if verbose
                        fprintf('  包 %d: 移动后原组易碎品体积占比仍过高 %.2f%%，分数降低10\n', 
                            pkg_idx, new_fragile_ratio*100);
                    end
                end
            end
        end
        
        % 更新最佳候选
        if score > best_score
            best_score = score;
            best_candidate = pkg_idx;
            if verbose
                fprintf('  包 %d: 得分 %.2f\n', pkg_idx, score);
            end
        end
    end
    
    if verbose && best_candidate > 0
        fprintf('最佳强制移动候选: 包 %d (得分: %.2f)\n', best_candidate, best_score);
    elseif verbose && best_candidate == 0
        fprintf('未找到合适的强制移动候选\n');
    end
end