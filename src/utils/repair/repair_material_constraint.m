



function repaired = repair_material_constraint(assign, packages, G, varargin)
% repair_material_constraint 修复材质约束违反
% 输入:
%   assign - 当前的包到组的分配（P x 1向量）
%   packages - 包结构体，包含.list和.attrs字段
%   G - 大组数量
%   varargin - 可选参数：
%     'verbose' - 是否显示调试信息 (默认: false)
%     'max_forced_moves' - 最大强制移动次数 (默认: 3)
% 输出:
%   repaired - 修复后的分配

    % 输入参数验证
    if nargin < 3
        error('至少需要3个输入参数: assign, packages, G');
    end
    
    if ~isvector(assign) || ~isnumeric(assign)
        error('assign 必须是数值向量');
    end
    
    if ~isstruct(packages) || ~all(isfield(packages, {'list', 'attrs'}))
        error('packages 必须包含 list 和 attrs 字段的结构体');
    end
    
    if ~isscalar(G) || G <= 0 || floor(G) ~= G
        error('G 必须是正整数');
    end
    
    % 解析可选参数，保持向后兼容性
    p = inputParser;
    addParameter(p, 'verbose', false, @islogical); % 默认关闭调试信息
    addParameter(p, 'max_forced_moves', 3, @(x) isscalar(x) && x > 0);
    parse(p, varargin{:});
    
    verbose = p.Results.verbose;
    max_forced_moves = p.Results.max_forced_moves;
    
    repaired = assign;
    P = numel(assign);
    
    % 检查每个大组的材质约束
    for g = 1:G
        % 获取该组中的所有包
        packages_in_group = find(repaired == g);
        if isempty(packages_in_group)
            continue;
        end
        
        n_packages = length(packages_in_group);
        
        % 优化数组预分配
        max_possible_materials = n_packages * 5; % 假设每个包最多5种材质
        all_materials = zeros(1, max_possible_materials);
        material_count = 0;
        
        % 收集材质数据（只处理数值类型）
        for p_idx = 1:n_packages
            pkg_idx = packages_in_group(p_idx);
            if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
                pkg_materials = packages.attrs(pkg_idx).material;
                if isnumeric(pkg_materials)
                    pkg_materials_vec = pkg_materials(:)';
                    n_new_materials = length(pkg_materials_vec);
                    if material_count + n_new_materials <= max_possible_materials
                        all_materials(material_count+1:material_count+n_new_materials) = pkg_materials_vec;
                        material_count = material_count + n_new_materials;
                    end
                end
            end
        end
        
        % 调整数组大小
        all_materials = all_materials(1:material_count);
        unique_materials = unique(all_materials);
        
        % 如果材质种类超过2种，需要修复
        if length(unique_materials) > 2
            if verbose
                fprintf('修复大组 %d: %d 种材质 [', g, length(unique_materials));
                fprintf('%d ', unique_materials);
                fprintf('] -> ');
            end
            
            % 确定要保留和移除的材质
            material_counts = zeros(1, length(unique_materials));
            for i = 1:length(unique_materials)
                material = unique_materials(i);
                material_counts(i) = sum(all_materials == material);
            end
            
            [~, sorted_idx] = sort(material_counts, 'descend');
            materials_to_keep = unique_materials(sorted_idx(1:2));
            materials_to_remove = unique_materials(sorted_idx(3:end));
            
            if verbose
                fprintf('保留材质: [%d %d], 移除材质: [', materials_to_keep(1), materials_to_keep(2));
                fprintf('%d ', materials_to_remove);
                fprintf(']\n');
            end
            
            moved_count = 0;
            forced_moves_count = 0;
            
            % 使用原始包列表的副本
            original_packages_in_group = packages_in_group;
            processed_packages = false(size(original_packages_in_group));
            
            for p_idx = 1:length(original_packages_in_group)
                pkg_idx = original_packages_in_group(p_idx);
                
                % 确保包仍在当前组中且未处理
                if repaired(pkg_idx) ~= g || processed_packages(p_idx)
                    continue;
                end
                
                pkg_materials = packages.attrs(pkg_idx).material;
                
                if isnumeric(pkg_materials)
                    pkg_materials_vec = pkg_materials(:)';
                    
                    % 检查包是否包含要移除的材质
                    contains_remove = any(ismember(pkg_materials_vec, materials_to_remove));
                    
                    if contains_remove
                        if verbose
                            fprintf('  候选包 %d: 材质[', pkg_idx);
                            fprintf('%d ', pkg_materials_vec);
                            fprintf('], 包含移除材质: %d\n', contains_remove);
                        end
                        
                        % 尝试移动，调用外部的find_best_target_group函数
                        target_group = find_best_target_group(repaired, packages, G, g, pkg_idx, 'verbose', verbose);
                        
                        if verbose
                            fprintf('  目标组: %d (当前组: %d)\n', target_group, g);
                        end
                        
                        if target_group ~= g
                            repaired(pkg_idx) = target_group;
                            moved_count = moved_count + 1;
                            if verbose
                                fprintf('  ✓ 移动包 %d 到组 %d\n', pkg_idx, target_group);
                            end
                            processed_packages(p_idx) = true;
                        end
                    end
                end
            end
            
            if verbose
                fprintf('  成功移动: %d\n', moved_count);
            end
            
            % 强制移动逻辑，当常规移动失败时使用
            if moved_count == 0 && forced_moves_count < max_forced_moves
                if verbose
                    fprintf('  尝试强制移动...\n');
                end
                
                % 找到最适合强制移动的包
                best_candidate = find_best_forced_move_candidate(repaired, packages, g, materials_to_remove, original_packages_in_group);
                
                if best_candidate > 0
                    % 找到可接受的目标组
                    target_group = find_acceptable_target_group(repaired, packages, G, g, best_candidate);
                    
                    if target_group ~= g
                        repaired(best_candidate) = target_group;
                        forced_moves_count = forced_moves_count + 1;
                        moved_count = moved_count + 1;
                        if verbose
                            fprintf('  ⚡ 强制移动包 %d 到组 %d\n', best_candidate, target_group);
                        end
                    end
                end
            end
            
            if verbose
                fprintf('最终移动了 %d 个包\n\n', moved_count);
            end
        end
    end
end

% function target_group = find_best_target_group(assign, packages, G, current_group, pkg_idx)
% % 找到最佳目标组来移动包
%     best_group = mod(current_group, G) + 1; % 默认下一个组
%     min_material_count = Inf;
% 
%     % 尝试找到材质种类最少的组
%     for g = 1:G
%         if g == current_group
%             continue;
%         end
% 
%         % 获取该组中的所有包
%         packages_in_group = find(assign == g);
%         if isempty(packages_in_group)
%             best_group = g;
%             break;
%         end
% 
%         % 收集该组中的所有材质种类
%         all_materials = {};
%         for p = 1:length(packages_in_group)
%             group_pkg_idx = packages_in_group(p);
%             if isfield(packages.attrs(group_pkg_idx), 'material') && ~isempty(packages.attrs(group_pkg_idx).material)
%                 pkg_materials = packages.attrs(group_pkg_idx).material;
%                 if iscell(pkg_materials)
%                     for j = 1:length(pkg_materials)
%                         if ischar(pkg_materials{j}) && ~isempty(pkg_materials{j})
%                             all_materials{end+1} = pkg_materials{j}; %#ok<AGROW>
%                         end
%                     end
%                 else
%                     if ischar(pkg_materials) && ~isempty(pkg_materials)
%                         all_materials{end+1} = pkg_materials; %#ok<AGROW>
%                     end
%                 end
%             end
%         end
% 
%         % 确保all_materials只包含字符向量
%         if ~isempty(all_materials)
%             char_mask = cellfun(@ischar, all_materials);
%             all_materials = all_materials(char_mask);
%         end
% 
%         % 计算该组的材质种类数量
%         unique_material_count = length(unique(all_materials));
% 
%         % 如果添加当前包后材质种类仍不超过2，则选择该组
%         pkg_materials = packages.attrs(pkg_idx).material;
%         new_materials = all_materials;
% 
%         if iscell(pkg_materials)
%             for j = 1:length(pkg_materials)
%                 if ischar(pkg_materials{j}) && ~isempty(pkg_materials{j})
%                     new_materials{end+1} = pkg_materials{j}; %#ok<AGROW>
%                 end
%             end
%         else
%             if ischar(pkg_materials) && ~isempty(pkg_materials)
%                 new_materials{end+1} = pkg_materials; %#ok<AGROW>
%             end
%         end
% 
%         % 确保new_materials只包含字符向量
%         if ~isempty(new_materials)
%             char_mask = cellfun(@ischar, new_materials);
%             new_materials = new_materials(char_mask);
%         end
% 
%         new_unique_count = length(unique(new_materials));
% 
%         if new_unique_count <= 2 && unique_material_count < min_material_count
%             min_material_count = unique_material_count;
%             best_group = g;
%         end
%     end
% 
%     target_group = best_group;
% end