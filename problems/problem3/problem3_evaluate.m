function [Q, comps] = problem3_evaluate(x, y, z, a, b, new_items_attrs, data, params)
% problem3_evaluate 计算综合目标 Q 及所有分项指标（阶段一）
%   x: I x G, 现有商品到大组的分配矩阵（二进制）
%   y: I x K, 现有商品到小组的分配矩阵（二进制）
%   z: G x K, 大组到小组的映射矩阵（二进制）
%   a: M x G, 新增商品到大组的分配矩阵（二进制）
%   b: M x K, 新增商品到小组的分配矩阵（二进制）
%   new_items_attrs: 新增商品属性结构体数组
%   data: 数据结构体
%   params: 可选参数结构体

    % 参数验证
    if nargin < 8, params = struct(); end
    
    % 获取维度信息
    I = size(x,1);
    G = size(x,2);
    K = size(y,2);
    M = size(a,1);
    
    % 提取现有商品数据并确保数值类型
    w = data.weights(:);
    v = data.volumes(:);
    f = data.fragile_level(:);
    m = data.material(:);
    
    % 处理时效需求（转为数值：T1=1, T2=2）
    t = data.time_requirement(:);
    if iscell(t) || ischar(t(1))
        t_numeric = zeros(length(t), 1);
        for i = 1:length(t)
            if ischar(t{i}) || isstring(t{i})
                if strcmp(t{i}, 'T1')
                    t_numeric(i) = 1;
                else
                    t_numeric(i) = 2;
                end
            end
        end
        t = t_numeric;
    end
    
    % 处理报关类别（转为数值：A=1, B=2, C=3）
    c = data.customs_type(:);
    if iscell(c) || ischar(c(1))
        c_numeric = zeros(length(c), 1);
        for i = 1:length(c)
            if ischar(c{i}) || isstring(c{i})
                if strcmp(c{i}, 'A')
                    c_numeric(i) = 1;
                elseif strcmp(c{i}, 'B') 
                    c_numeric(i) = 2;
                else
                    c_numeric(i) = 3;
                end
            end
        end
        c = c_numeric;
    end
    
    % 提取新增商品数据并确保数值类型
    w_new = zeros(M, 1);
    v_new = zeros(M, 1);
    f_new = zeros(M, 1);
    m_new = zeros(M, 1);
    t_new = zeros(M, 1);
    c_new = zeros(M, 1);
    
    for i = 1:M
        if isfield(new_items_attrs, 'weight')
            w_new(i) = new_items_attrs(i).weight;
        end
        if isfield(new_items_attrs, 'volume')
            v_new(i) = new_items_attrs(i).volume;
        end
        if isfield(new_items_attrs, 'fragility_level')
            f_new(i) = new_items_attrs(i).fragility_level;
        end
        if isfield(new_items_attrs, 'material')
            m_new(i) = new_items_attrs(i).material;
        end
        if isfield(new_items_attrs, 'time_requirement')
            % 转换时效需求为数值
            time_val = new_items_attrs(i).time_requirement;
            if ischar(time_val) || isstring(time_val)
                if strcmp(time_val, 'T1')
                    t_new(i) = 1;
                else
                    t_new(i) = 2;
                end
            else
                t_new(i) = time_val;
            end
        end
        if isfield(new_items_attrs, 'customs_type')
            % 转换报关类别为数值
            customs_val = new_items_attrs(i).customs_type;
            if ischar(customs_val) || isstring(customs_val)
                if strcmp(customs_val, 'A')
                    c_new(i) = 1;
                elseif strcmp(customs_val, 'B')
                    c_new(i) = 2;
                else
                    c_new(i) = 3;
                end
            else
                c_new(i) = customs_val;
            end
        end
    end
    
    % 默认参数
    lambda1 = getfieldwithdefault(params, 'lambda1', 1.0); % 只保留重量差项
    rho1 = getfieldwithdefault(params, 'rho1', 0);  % 商品选择惩罚
    rho2 = getfieldwithdefault(params, 'rho2', 0);  % 大组规模惩罚
    rho3 = getfieldwithdefault(params, 'rho3', 300);  % 时效一致性惩罚
    rho4 = getfieldwithdefault(params, 'rho4', 170);   % 易碎品体积约束惩罚
    rho5 = getfieldwithdefault(params, 'rho5', 300);   % 材质多样性惩罚
    rho6 = getfieldwithdefault(params, 'rho6', 0);  % 小组规模惩罚
    rho7 = getfieldwithdefault(params, 'rho7', 300);  % 报关一致性惩罚（3）
    rho8 = getfieldwithdefault(params, 'rho8', 500);  % 新增商品数量惩罚（新增）
    rho9 = getfieldwithdefault(params, 'rho9', 500);  % 易碎品缓冲约束惩罚（新增）
    target_total = getfieldwithdefault(params, 'target_total', 72);
    target_per_group = getfieldwithdefault(params, 'target_per_group', 12);
    target_per_sub = getfieldwithdefault(params, 'target_per_sub', 4);
    
    % 计算总重量（现有商品 + 新增商品）
    W_existing = sum(x .* repmat(w, 1, G), 1);
    W_new = sum(a .* repmat(w_new, 1, G), 1);
    W = W_existing + W_new;  % 1 x G
    
    % 主目标项：只保留重量差项
    maxW = max(W); 
    minW = min(W);
    termW = (maxW - minW);
    
    % 归一化因子
    deltaW_norm = max(w) * target_per_group * 0.5;
    
    % 惩罚项计算
    % 1. P_selection - 商品选择惩罚（只惩罚现有商品，不惩罚新增商品数量）
    sum_x = sum(x, 'all');
    P_selection = (sum_x - target_total)^2 + sum((sum(x, 2) - 1).^2) + ...
                 sum((sum(a, 2) - 1).^2);  % 只惩罚新增商品的重复选择
    
    % 新增商品数量惩罚 - 鼓励新增商品数量尽可能少
    sum_a = sum(a, 'all');
    P_new_items_count = sum_a * rho8; % 直接按选择的新增商品数量惩罚
    
    % 2. P_grouping - 大组规模惩罚
    group_counts = sum(x, 1) + sum(a, 1);
    P_grouping = sum((group_counts - target_per_group).^2);
    
    % 3. P_timeliness - 时效一致性惩罚
    P_timeliness = 0;
    unique_t = unique(t);
    for g = 1:G
        for tt = unique_t'
            idx = (t == tt);
            c = sum(x(idx, g));
            P_timeliness = P_timeliness + (min(c, target_per_group - c)^2);
        end
        
        % 新增商品的时效一致性
        unique_t_new = unique(t_new);
        for tt_new = unique_t_new'
            idx_new = (t_new == tt_new);
            c_new = sum(a(idx_new, g));
            P_timeliness = P_timeliness + (min(c_new, target_per_group - c_new)^2);
        end
    end
    
    % 4. P_fragile - 易碎品体积约束惩罚
    P_fragile = 0;
    for g = 1:G
        ks = find(z(g, :) > 0.5);
        for k = ks
            idx_y = (y(:, k) > 0.5);
            idx_b = (b(:, k) > 0.5);
            
            % 计算该小组的总易碎品体积比例
            total_volume = sum(v(idx_y)) + sum(v_new(idx_b));
            fragile_volume = sum(v(idx_y & (f == 3))) + sum(v_new(idx_b & (f_new == 3)));
            
            if total_volume > 0
                ratio = fragile_volume / total_volume;
                excess = max(0, ratio - 0.35);%0.35
                P_fragile = P_fragile + excess^2;
            end
        end
    end
    
    % 5. P_material - 材质多样性惩罚
    P_material = 0;
    materials = unique([m; m_new]);
    for g = 1:G
        u_gm = zeros(numel(materials), 1);
        for mi = 1:numel(materials)
            idxm = (m == materials(mi));
            idxm_new = (m_new == materials(mi));
            if any(x(idxm, g) > 0.5) || any(a(idxm_new, g) > 0.5)
                u_gm(mi) = 1;
            end
        end
        P_material = P_material + max(0, sum(u_gm) - 2)^4;
    end
    
    % 6. P_subgroup - 小组规模惩罚
    sub_counts = sum(y, 1) + sum(b, 1);
    P_sub1 = sum((sub_counts - target_per_sub).^2);
    P_sub2 = sum((sum(y, 2) - sum(x, 2)).^2) + sum((sum(b, 2) - sum(a, 2)).^2);
    P_subgroup = P_sub1 + P_sub2;
    
    % 7. P_customs - 报关一致性惩罚（新增）
    P_customs = 0;
    for g = 1:G
        % 收集该组的所有报关类型
        group_customs = [];
        
        % 现有商品的报关类型
        for i = 1:I
            if x(i, g) > 0.5
                group_customs = [group_customs, c(i)];
            end
        end
        
        % 新增商品的报关类型
        for i = 1:M
            if a(i, g) > 0.5
                group_customs = [group_customs, c_new(i)];
            end
        end
        
        % 计算该组的报关类型数量
        unique_customs = unique(group_customs);
        customs_count = length(unique_customs);
        
        % 惩罚超过2种报关类型的情况
        if customs_count > 2
            P_customs = P_customs + (customs_count - 2)^2;
        end
    end
    
    % 组合 Q：只保留重量差项，删除体积差项，添加新增商品数量惩罚
    Q = lambda1 * (termW / max(deltaW_norm, eps)) + ...
        rho1*P_selection + rho2*P_grouping + rho3*P_timeliness + ...
        rho4*P_fragile + rho5*P_material + rho6*P_subgroup + rho7*P_customs + ...
        P_new_items_count; % 新增商品数量惩罚
    
    % 可行性粗判（不要求新增商品数量达到特定值）
    feasible = (sum((sum(x, 2) - 1).^2) == 0) && all(group_counts <= target_per_group) && all(sub_counts <= target_per_sub) && ...
               all(sum(z, 1) == 1) && all(sum(z, 2) == 3) && all(P_customs == 0);
    
    % 8. P_fragile_buffer - 易碎品缓冲约束惩罚（3级易碎品必须与2级易碎品同组）
    P_fragile_buffer = 0;
    
    for g = 1:G
        % 检查大组中是否有3级易碎品
        has_level3 = any(f == 3 & x(:, g) > 0.5) || any(f_new == 3 & a(:, g) > 0.5);
        
        % 检查大组中是否有2级易碎品
        has_level2 = any(f == 2 & x(:, g) > 0.5) || any(f_new == 2 & a(:, g) > 0.5);
        
        % 如果有3级易碎品但没有2级易碎品，则违反约束
        if has_level3 && ~has_level2
            % 计算该大组中3级易碎品的数量
            level3_count = sum(f == 3 & x(:, g) > 0.5) + sum(f_new == 3 & a(:, g) > 0.5);
            P_fragile_buffer = P_fragile_buffer + level3_count * rho9;
        end
    end
    
    % 组合 Q：只保留重量差项，删除体积差项，添加新增商品数量惩罚和易碎品缓冲约束惩罚
    Q = lambda1 * (termW / max(deltaW_norm, eps)) + ...
        rho1*P_selection + rho2*P_grouping + rho3*P_timeliness + ...
        rho4*P_fragile + rho5*P_material + rho6*P_subgroup + rho7*P_customs + ...
        P_new_items_count + rho9*P_fragile_buffer; % 新增商品数量惩罚和易碎品缓冲约束惩罚
    
    % 可行性粗判（不要求新增商品数量达到特定值，增加易碎品缓冲约束）
    feasible = (sum((sum(x, 2) - 1).^2) == 0) && all(group_counts <= target_per_group) && all(sub_counts <= target_per_sub) && ...
               all(sum(z, 1) == 1) && all(sum(z, 2) == 3) && all(P_customs == 0) && (P_fragile_buffer == 0);
    
    % 输出 components
    comps = struct();
    comps.W = W;
    comps.termW = termW;
    comps.deltaW_norm = deltaW_norm;
    comps.P_selection = P_selection;
    comps.P_grouping = P_grouping;
    comps.P_timeliness = P_timeliness;
    comps.P_fragile = P_fragile;
    comps.P_material = P_material;
    comps.P_subgroup = P_subgroup;
    comps.P_customs = P_customs;
    comps.P_new_items_count = P_new_items_count;  % 新增商品数量惩罚
    comps.P_fragile_buffer = P_fragile_buffer;  % 易碎品缓冲约束惩罚
    comps.Q = Q;
    comps.feasible = feasible;
    comps.selected_new_items_count = sum_a;  % 当前选择的新增商品数量
    
    % 新增指标：报关类型统计
    comps.customs_types_per_group = zeros(1, G);
    for g = 1:G
        group_customs = [];
        for i = 1:I
            if x(i, g) > 0.5
                group_customs = [group_customs, c(i)];
            end
        end
        for i = 1:M
            if a(i, g) > 0.5
                group_customs = [group_customs, c_new(i)];
            end
        end
        comps.customs_types_per_group(g) = length(unique(group_customs));
    end
end

function value = getfieldwithdefault(struct_obj, field_name, default_value)
    % 获取结构体字段值，如果不存在则返回默认值
    if isfield(struct_obj, field_name)
        value = struct_obj.(field_name);
    else
        value = default_value;
    end
end