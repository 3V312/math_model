function q = evaluate_assignment_3(assign, packages, data, params, G, P)
% evaluate_assignment_3 - 问题三专用的分配方案评估函数
% 评估分配方案质量，包含问题三特有的约束惩罚
% 输入：
%   assign - 包分配向量（P x 1）
%   packages - 包结构体，包含list和attrs字段
%   data - 商品数据结构体
%   params - 算法参数
%   G - 大组数量
%   P - 包数量
% 输出：
%   q - 评估得分（越小越好）
    
    % 参数解析
    if nargin < 5 || isempty(params)
        params = struct();
    end
    
    % 设置默认惩罚权重
    rho_fragile_buffer = getfieldwithdefault(params, 'rho_fragile_buffer', 500); % 易碎品缓冲保护约束惩罚
    rho_customs_compatibility = getfieldwithdefault(params, 'rho_customs_compatibility', 400); % 报关类别约束惩罚
    rho_weight_protection = getfieldwithdefault(params, 'rho_weight_protection', 300); % 重物与易碎品混合惩罚
    rho_item_count = getfieldwithdefault(params, 'rho_item_count', 1000); % 商品数量约束惩罚
    
    % 首先进行商品数量约束修复
    assign = repair_item_count(assign, packages, G, 12);
    
    % 展开包分配到商品级别
    [x0, y0, z0] = expand_pkg_assign(assign, packages, data, params, G, P);
    
    % 评估解的质量（使用问题二的评估函数作为基础）
    [q_base, comps] = problem2_evaluate(x0, y0, z0, data, params);
    
    % 添加问题三特有的约束惩罚
    q = q_base;
    
    % 1. 添加商品数量约束违反惩罚
    group_item_counts = calculate_group_item_counts(assign, packages, G);
    item_penalty = 0;
    for g = 1:G
        deviation = abs(group_item_counts(g) - 12);
        if deviation > 0
            item_penalty = item_penalty + deviation * rho_item_count;
        end
    end
    q = q + item_penalty;
    
    % 2. 易碎品缓冲保护约束惩罚
    fragile_buffer_penalty = 0;
    for g = 1:G
        group_packages = find(assign == g);
        has_level3 = false;
        has_level2 = false;
        
        for i = 1:length(group_packages)
            pkg_idx = group_packages(i);
            if isfield(packages.attrs(pkg_idx), 'fragile_level') && ~isempty(packages.attrs(pkg_idx).fragile_level)
                if packages.attrs(pkg_idx).fragile_level == 3
                    has_level3 = true;
                elseif packages.attrs(pkg_idx).fragile_level == 2
                    has_level2 = true;
                end
            end
        end
        
        % 如果有3级易碎品但没有2级易碎品，施加惩罚
        if has_level3 && ~has_level2
            fragile_buffer_penalty = fragile_buffer_penalty + rho_fragile_buffer;
        end
    end
    q = q + fragile_buffer_penalty;
    
    % 3. 报关类别约束惩罚
    customs_penalty = 0;
    for g = 1:G
        group_packages = find(assign == g);
        customs_types = {};
        
        for i = 1:length(group_packages)
            pkg_idx = group_packages(i);
            if isfield(packages.attrs(pkg_idx), 'customs_type') && ~isempty(packages.attrs(pkg_idx).customs_type)
                customs_type = packages.attrs(pkg_idx).customs_type;
                if ~ismember(customs_type, customs_types)
                    customs_types{end+1} = customs_type; %#ok<AGROW>
                end
            end
        end
        
        % 如果大组包含超过2种报关类型，施加惩罚
        if length(customs_types) > 2
            customs_penalty = customs_penalty + (length(customs_types) - 2) * rho_customs_compatibility;
        end
    end
    q = q + customs_penalty;
    
    % 4. 重物与易碎品混合惩罚
    weight_protection_penalty = 0;
    for g = 1:G
        group_packages = find(assign == g);
        has_heavy = false;
        has_fragile = false;
        
        for i = 1:length(group_packages)
            pkg_idx = group_packages(i);
            % 检查是否有易碎品
            if isfield(packages.attrs(pkg_idx), 'fragile_level') && ~isempty(packages.attrs(pkg_idx).fragile_level)
                if packages.attrs(pkg_idx).fragile_level >= 2
                    has_fragile = true;
                end
            end
            
            % 检查是否有重物
            if isfield(packages.attrs(pkg_idx), 'is_heavy') && packages.attrs(pkg_idx).is_heavy
                has_heavy = true;
            end
        end
        
        % 如果大组同时包含重物和易碎品，施加惩罚
        if has_heavy && has_fragile
            weight_protection_penalty = weight_protection_penalty + rho_weight_protection;
        end
    end
    q = q + weight_protection_penalty;
end

function v = getfieldwithdefault(s, name, def)
% 获取结构体字段值，如果字段不存在则返回默认值
    if isfield(s, name)
        v = s.(name);
    else 
        v = def; 
    end
end