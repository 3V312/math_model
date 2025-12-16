function [assign, success] = repair_buffer_constraint_3(assign, packages, G, varargin)
% repair_buffer_constraint_3 - 修复缓冲保护约束，确保3级易碎品周围有2级易碎品保护
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
    
    while iteration < max_iterations
        iteration = iteration + 1;
        
        % 检查是否满足约束
        constraint_violated = false;
        violating_groups = [];
        vulnerable_fragile_packages = {};
        
        for g = 1:G
            group_packages = find(assign == g);
            has_level3_fragile = false;
            has_level2_fragile = false;
            level3_packages = [];
            
            for i = 1:length(group_packages)
                pkg_idx = group_packages(i);
                if isfield(packages.attrs(pkg_idx), 'fragile_level') && ~isempty(packages.attrs(pkg_idx).fragile_level)
                    frag_level = packages.attrs(pkg_idx).fragile_level;
                    
                    % 获取易碎级别
                    frag_level = packages.attrs(pkg_idx).fragile_level;
                    % 确保易碎级别为数值
                    if ischar(frag_level) || isstring(frag_level)
                        frag_level = str2double(frag_level);
                    end
                    
                    if isnumeric(frag_level)
                        % 添加易碎等级取值范围验证
                        if frag_level < 1 || frag_level > 3
                            warning('易碎等级 %d 超出有效范围(1-3)，已忽略', frag_level);
                            continue;
                        end
                        
                        if frag_level == 3
                            has_level3_fragile = true;
                            level3_packages = [level3_packages, pkg_idx];
                        elseif frag_level == 2
                            has_level2_fragile = true;
                        end
                    end
                end
            end
            
            % 如果组中有3级易碎品但没有2级易碎品，则违反约束
            if has_level3_fragile && ~has_level2_fragile
                constraint_violated = true;
                violating_groups = [violating_groups, g];
                vulnerable_fragile_packages{g} = level3_packages;
            end
        end
        
        % 检查是否没有改进（可能陷入循环）
        current_violating_groups_count = length(violating_groups);
        if current_violating_groups_count >= prev_violating_groups_count && iteration > 1
            % 如果违规组数没有减少，尝试强制退出避免死循环
            if verbose
                fprintf('迭代 %d: 违规组数没有减少，尝试强制优化...\n', iteration);
            end
            % 可以在这里添加额外的优化策略
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
                fprintf('修复大组 %d 的缓冲保护约束\n', g);
            end
            
            % 策略1：从其他组寻找2级易碎品移动到该组
            level2_candidates = [];
            source_groups = [];
            
            for source_g = 1:G
                if source_g == g
                    continue;
                end
                
                source_packages = find(assign == source_g);
                for i = 1:length(source_packages)
                    pkg_idx = source_packages(i);
                    if isfield(packages.attrs(pkg_idx), 'fragile_level') && ~isempty(packages.attrs(pkg_idx).fragile_level)
                        frag_level = packages.attrs(pkg_idx).fragile_level;
                        
                        % 确保易碎级别为数值
                        if ischar(frag_level) || isstring(frag_level)
                            frag_level = str2double(frag_level);
                        end
                        
                        if isnumeric(frag_level) && frag_level == 2
                            % 检查移动该2级易碎品是否会导致源组违反约束
                            source_has_other_level2 = false;
                            source_has_level3 = false;
                            
                            for j = 1:length(source_packages)
                                other_pkg_idx = source_packages(j);
                                if other_pkg_idx == pkg_idx
                                    continue;
                                end
                                
                                if isfield(packages.attrs(other_pkg_idx), 'fragile_level') && ~isempty(packages.attrs(other_pkg_idx).fragile_level)
                                    other_frag_level = packages.attrs(other_pkg_idx).fragile_level;
                                    
                                    if ischar(other_frag_level) || isstring(other_frag_level)
                                        other_frag_level = str2double(other_frag_level);
                                    end
                                    
                                    if isnumeric(other_frag_level)
                                        if other_frag_level == 2
                                            source_has_other_level2 = true;
                                        elseif other_frag_level == 3
                                            source_has_level3 = true;
                                        end
                                    end
                                end
                            end
                            
                            % 如果源组还有其他2级易碎品，或者源组没有3级易碎品，则可以移动
                            if source_has_other_level2 || ~source_has_level3
                                level2_candidates = [level2_candidates, pkg_idx];
                                source_groups = [source_groups, source_g];
                            end
                        end
                    end
                end
            end
            
            % 如果找到合适的2级易碎品，移动一个到违反约束的组
            if ~isempty(level2_candidates)
                % 选择第一个候选移动
                pkg_to_move = level2_candidates(1);
                source_g = source_groups(1);
                
                assign(pkg_to_move) = g;
                
                if verbose
                    fprintf('  将2级易碎品包 %d 从大组 %d 移动到大组 %d\n', pkg_to_move, source_g, g);
                end
            else
                % 策略2：将3级易碎品移动到有2级易碎品的组
                if isfield(vulnerable_fragile_packages, num2str(g)) && ~isempty(vulnerable_fragile_packages{g})
                    level3_pkg = vulnerable_fragile_packages{g}(1);
                    
                    % 寻找有2级易碎品且没有3级易碎品的组
                    target_groups = [];
                    for target_g = 1:G
                        if target_g == g
                            continue;
                        end
                        
                        target_packages = find(assign == target_g);
                        has_level2 = false;
                        has_level3 = false;
                        
                        for i = 1:length(target_packages)
                            pkg_idx = target_packages(i);
                            if isfield(packages.attrs(pkg_idx), 'fragile_level') && ~isempty(packages.attrs(pkg_idx).fragile_level)
                                frag_level = packages.attrs(pkg_idx).fragile_level;
                                
                                if ischar(frag_level) || isstring(frag_level)
                                    frag_level = str2double(frag_level);
                                end
                                
                                if isnumeric(frag_level)
                                    if frag_level == 2
                                        has_level2 = true;
                                    elseif frag_level == 3
                                        has_level3 = true;
                                    end
                                end
                            end
                        end
                        
                        if has_level2 && ~has_level3
                            target_groups = [target_groups, target_g];
                        end
                    end
                    
                    if ~isempty(target_groups)
                        % 选择第一个目标组
                        target_g = target_groups(1);
                        assign(level3_pkg) = target_g;
                        
                        if verbose
                            fprintf('  将3级易碎品包 %d 从大组 %d 移动到大组 %d\n', level3_pkg, g, target_g);
                        end
                    else
                        % 策略3：如果没有理想目标组，选择任意有2级易碎品的组
                        target_groups_with_level2 = [];
                        for target_g = 1:G
                            if target_g == g
                                continue;
                            end
                            
                            target_packages = find(assign == target_g);
                            has_level2 = false;
                            
                            for i = 1:length(target_packages)
                                pkg_idx = target_packages(i);
                                if isfield(packages.attrs(pkg_idx), 'fragile_level') && ~isempty(packages.attrs(pkg_idx).fragile_level)
                                    frag_level = packages.attrs(pkg_idx).fragile_level;
                                    
                                    if ischar(frag_level) || isstring(frag_level)
                                        frag_level = str2double(frag_level);
                                    end
                                    
                                    if isnumeric(frag_level) && frag_level == 2
                                        has_level2 = true;
                                        break;
                                    end
                                end
                            end
                            
                            if has_level2
                                target_groups_with_level2 = [target_groups_with_level2, target_g];
                            end
                        end
                        
                        if ~isempty(target_groups_with_level2)
                            target_g = target_groups_with_level2(1);
                            assign(level3_pkg) = target_g;
                            
                            if verbose
                                fprintf('  将3级易碎品包 %d 从大组 %d 移动到大组 %d（含2级易碎品）\n', level3_pkg, g, target_g);
                            end
                        end
                    end
                end
            end
        end
    end
    
    if verbose
        if success
            fprintf('缓冲保护约束修复成功\n');
        else
            fprintf('超过最大迭代次数，缓冲保护约束修复可能不完整\n');
        end
    end
end