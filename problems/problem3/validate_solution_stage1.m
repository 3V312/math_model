function [is_valid, info] = validate_solution_stage1(solution, data, params)
% 验证第一阶段解决方案的有效性
    is_valid = true;
    info = struct();
    info.violations = {};
    info.group_stats = struct();
    
    % 检查必要字段
    required_fields = {'package_assign', 'group_assign'};
    for field = required_fields
        if ~isfield(solution, field{1})
            is_valid = false;
            info.missing_fields{end+1} = field{1};  %#ok<AGROW>
        end
    end
    
    % 如果必要字段缺失，直接返回
    if ~is_valid
        return;
    end
    
    % 获取验证参数
    min_group_size = getfieldwithdefault(params, 'min_group_size', 6);
    max_group_size = getfieldwithdefault(params, 'max_group_size', 18);
    fragile_materials = getfieldwithdefault(params, 'fragile_materials', {'glass', 'ceramic', 'electronics'});
    
    % 验证包分配的有效性
    if any(solution.package_assign < 1)
        is_valid = false;
        info.violations{end+1} = '存在无效的组分配（小于1）';  %#ok<AGROW>
    end
    
    % 验证每个组的大小是否在允许范围内
    num_groups = max(solution.package_assign);
    group_sizes = zeros(num_groups, 1);
    
    for g = 1:num_groups
        group_sizes(g) = sum(solution.package_assign == g);
        info.group_stats(g).size = group_sizes(g);
        info.group_stats(g).valid_size = (group_sizes(g) >= min_group_size) && (group_sizes(g) <= max_group_size);
        
        if ~info.group_stats(g).valid_size
            is_valid = false;
            info.violations{end+1} = sprintf('组 %d 大小为 %d，不在允许范围内 [%d-%d]', ...  %#ok<AGROW>
                g, group_sizes(g), min_group_size, max_group_size);
        end
    end
    
    % 验证易碎品约束：检查易碎品是否与重物混合
    fragile_package_indices = [];
    heavy_package_indices = [];
    
    for i = 1:length(solution.package_assign)
        pkg_idx = i;  % 假设package list的索引与data索引对应
        
        % 检查是否为易碎品
        if ismember(lower(data.material_type(pkg_idx)), fragile_materials)
            fragile_package_indices = [fragile_package_indices; i];  %#ok<AGROW>
        end
        
        % 检查是否为重物（假设重量>50的为重物）
        weight_threshold = getfieldwithdefault(params, 'heavy_weight_threshold', 50);
        if data.weight(pkg_idx) > weight_threshold
            heavy_package_indices = [heavy_package_indices; i];  %#ok<AGROW>
        end
    end
    
    % 检查易碎品和重物是否在同一组
    for f_pkg = fragile_package_indices
        f_group = solution.package_assign(f_pkg);
        for h_pkg = heavy_package_indices
            if h_pkg ~= f_pkg && solution.package_assign(h_pkg) == f_group
                is_valid = false;
                info.violations{end+1} = sprintf('组 %d 包含易碎品和重物，违反约束', f_group);  %#ok<AGROW>
                break;
            end
        end
    end
    
    % 验证时间要求约束：检查同一组内的时间要求是否兼容
    for g = 1:num_groups
        group_package_indices = find(solution.package_assign == g);
        
        if ~isempty(group_package_indices)
            % 获取组内所有包的时间要求
            group_time_requirements = zeros(length(group_package_indices), 1);
            for i = 1:length(group_package_indices)
                pkg_idx = group_package_indices(i);
                group_time_requirements(i) = data.time_requirement(pkg_idx);
            end
            
            % 检查是否有不同的时间要求
            unique_times = unique(group_time_requirements);
            if length(unique_times) > 1
                % 记录但不视为违规，因为可能允许混合时间要求
                info.group_stats(g).mixed_time_requirements = true;
                info.group_stats(g).unique_times = unique_times;
            else
                info.group_stats(g).mixed_time_requirements = false;
            end
        end
    end
    
    % 验证报关类别约束：检查同一组内的报关类别
    for g = 1:num_groups
        group_package_indices = find(solution.package_assign == g);
        
        if ~isempty(group_package_indices)
            % 获取组内所有包的报关类别
            group_customs_types = cell(length(group_package_indices), 1);
            for i = 1:length(group_package_indices)
                pkg_idx = group_package_indices(i);
                group_customs_types{i} = data.customs_type(pkg_idx);
            end
            
            % 检查是否有不同的报关类别
            unique_customs = unique(group_customs_types);
            if length(unique_customs) > 1
                % 记录但不视为违规，取决于业务规则
                info.group_stats(g).mixed_customs_types = true;
                info.group_stats(g).unique_customs = unique_customs;
            else
                info.group_stats(g).mixed_customs_types = false;
            end
        end
    end
    
    % 汇总统计信息
    info.total_groups = num_groups;
    info.avg_group_size = mean(group_sizes);
    info.min_group