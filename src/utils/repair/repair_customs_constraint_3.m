function [assign, success] = repair_customs_constraint_3(assign, packages, G, varargin)
% repair_customs_constraint_3 - 修复报关约束，确保每个大组最多包含2种报关类型
% 输入:
%   assign - 当前分配（P x 1向量）
%   packages - 包结构体
%   G - 大组数量
%   varargin - 可选参数
% 输出:
%   assign - 修复后的分配
%   success - 是否成功修复所有约束

    % 参数解析
    p = inputParser;
    addParameter(p, 'verbose', false, @islogical);
    addParameter(p, 'max_iterations', 100, @isnumeric);
    parse(p, varargin{:});
    verbose = p.Results.verbose;
    max_iterations = p.Results.max_iterations;
    
    success = false;
    iteration = 0;
    prev_violating_groups_count = inf; % 记录上一次迭代的违规组数
    no_improvement_count = 0;
    max_no_improvement = 5; % 最大无改进次数
    
    while iteration < max_iterations
        iteration = iteration + 1;
        
        % 检查是否满足约束
        constraint_violated = false;
        violating_groups = [];
        
        for g = 1:G
            group_packages = find(assign == g);
            customs_types = [];
            
            for i = 1:length(group_packages)
                pkg_idx = group_packages(i);
                if isfield(packages.attrs(pkg_idx), 'customs_type') && ~isempty(packages.attrs(pkg_idx).customs_type)
                    pkg_customs = packages.attrs(pkg_idx).customs_type;
                    
                    % 确保报关类型为数值
                    if ischar(pkg_customs) || isstring(pkg_customs)
                        str_type = char(pkg_customs);
                        if strcmpi(str_type, 'A')
                            pkg_customs = 1;
                        elseif strcmpi(str_type, 'B')
                            pkg_customs = 2;
                        elseif strcmpi(str_type, 'C')
                            pkg_customs = 3;
                        end
                    end
                    
                    if isnumeric(pkg_customs)
                        customs_types = [customs_types, pkg_customs];
                    end
                end
            end
            
            unique_customs = unique(customs_types);
            if length(unique_customs) > 2
                constraint_violated = true;
                violating_groups = [violating_groups, g];
            end
        end
        
        % 检查是否没有改进（可能陷入循环）
        current_violating_groups_count = length(violating_groups);
        if current_violating_groups_count >= prev_violating_groups_count && iteration > 1
            no_improvement_count = no_improvement_count + 1;
            if verbose
                fprintf('迭代 %d: 违规组数没有减少，无改进计数: %d\n', iteration, no_improvement_count);
            end
            
            % 如果连续多次无改进，退出循环避免死循环
            if no_improvement_count >= max_no_improvement
                if verbose
                    fprintf('连续多次无改进，强制退出循环\n');
                end
                break;
            end
        else
            no_improvement_count = 0; % 有改进时重置计数
        end
        prev_violating_groups_count = current_violating_groups_count;
        
        % 如果没有违反约束，退出循环
        if ~constraint_violated
            success = true;
            break;
        end
        
        % 修复违反约束的大组
        for g = violating_groups
            if verbose
                fprintf('修复大组 %d 的报关约束\n', g);
            end
            
            % 获取该组中的所有包及其报关类型
            group_packages = find(assign == g);
            customs_map = containers.Map();
            
            % 统计每种报关类型的包数量
            for i = 1:length(group_packages)
                pkg_idx = group_packages(i);
                if isfield(packages.attrs(pkg_idx), 'customs_type') && ~isempty(packages.attrs(pkg_idx).customs_type)
                    pkg_customs = packages.attrs(pkg_idx).customs_type;
                    
                    % 确保报关类型为数值
                    if ischar(pkg_customs) || isstring(pkg_customs)
                        str_type = char(pkg_customs);
                        if strcmpi(str_type, 'A')
                            pkg_customs = 1;
                        elseif strcmpi(str_type, 'B')
                            pkg_customs = 2;
                        elseif strcmpi(str_type, 'C')
                            pkg_customs = 3;
                        end
                    end
                    
                    if isnumeric(pkg_customs)
                        if isKey(customs_map, pkg_customs)
                            customs_map(pkg_customs) = [customs_map(pkg_customs), pkg_idx];
                        else
                            customs_map(pkg_customs) = [pkg_idx];
                        end
                    end
                end
            end
            
            % 获取报关类型及其数量
            customs_types = keys(customs_map);
            customs_counts = zeros(length(customs_types), 1);
            
            for i = 1:length(customs_types)
                customs_counts(i) = length(customs_map(customs_types{i}));
            end
            
            % 保留数量最多的两种报关类型
            [~, idx] = sort(customs_counts, 'descend');
            types_to_keep = customs_types(idx(1:2));
            types_to_remove = setdiff(customs_types, types_to_keep);
            
            % 移动多余报关类型的包
            for type = types_to_remove
                packages_to_move = customs_map(type);
                
                for pkg_idx = packages_to_move
                    % 寻找可以接收该包的大组（具有相同报关类型或只有一种报关类型）
                    target_groups = [];
                    target_scores = [];
                    
                    for target_g = 1:G
                        if target_g == g
                            continue;
                        end
                        
                        % 获取目标组的报关类型
                        target_packages = find(assign == target_g);
                        target_customs_types = [];
                        
                        for i = 1:length(target_packages)
                            t_pkg_idx = target_packages(i);
                            if isfield(packages.attrs(t_pkg_idx), 'customs_type') && ~isempty(packages.attrs(t_pkg_idx).customs_type)
                                t_pkg_customs = packages.attrs(t_pkg_idx).customs_type;
                                
                                % 确保报关类型为数值
                                if ischar(t_pkg_customs) || isstring(t_pkg_customs)
                                    str_type = char(t_pkg_customs);
                                    if strcmpi(str_type, 'A')
                                        t_pkg_customs = 1;
                                    elseif strcmpi(str_type, 'B')
                                        t_pkg_customs = 2;
                                    elseif strcmpi(str_type, 'C')
                                        t_pkg_customs = 3;
                                    end
                                end
                                
                                if isnumeric(t_pkg_customs)
                                    target_customs_types = [target_customs_types, t_pkg_customs];
                                end
                            end
                        end
                        
                        unique_target_customs = unique(target_customs_types);
                        
                        % 如果目标组已有相同报关类型或只有一种报关类型，则可以接收
                        if any(ismember(unique_target_customs, type)) || length(unique_target_customs) <= 1
                            % 计算评分：组大小越小越好
                            group_size = length(target_packages);
                            score = -group_size;
                            
                            target_groups = [target_groups, target_g];
                            target_scores = [target_scores, score];
                        end
                    end
                    
                    % 选择最佳目标组
                    if ~isempty(target_groups)
                        [~, best_idx] = max(target_scores);
                        assign(pkg_idx) = target_groups(best_idx);
                        
                        if verbose
                            fprintf('  将包 %d 从大组 %d 移动到大组 %d\n', pkg_idx, g, target_groups(best_idx));
                        end
                    else
                        % 如果没有合适的目标组，尝试创建新组或移动到任意组
                        % 这里简单地选择一个随机组
                        possible_groups = setdiff(1:G, g);
                        if ~isempty(possible_groups)
                            random_group = possible_groups(randi(length(possible_groups)));
                            assign(pkg_idx) = random_group;
                            
                            if verbose
                                fprintf('  将包 %d 从大组 %d 移动到随机大组 %d\n', pkg_idx, g, random_group);
                            end
                        end
                    end
                end
            end
        end
    end
    
    if verbose
        if success
            fprintf('报关约束修复成功\n');
        else
            fprintf('超过最大迭代次数，报关约束修复可能不完整\n');
        end
    end
end