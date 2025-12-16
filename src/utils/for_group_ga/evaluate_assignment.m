function q = evaluate_assignment(assign, packages, data, params, G, P)
% 出现在：group_ga.m
% 评估分配方案质量，包含商品数量约束惩罚
    
    % 首先进行商品数量约束修复
    assign = repair_item_count(assign, packages, G, 12);
    
    % 展开包分配到商品级别
    [x0,y0,z0] = expand_pkg_assign(assign, packages, data, params, G, P);
    
    % 评估解的质量
    [q, comps] = problem2_evaluate(x0,y0,z0,data,params);
    
    % 添加商品数量约束违反惩罚
    group_item_counts = calculate_group_item_counts(assign, packages, G);
    item_penalty = 0;
    for g = 1:G
        deviation = abs(group_item_counts(g) - 12);
        if deviation > 0
            item_penalty = item_penalty + deviation * 10; % 每违反一个商品，惩罚10分
        end
    end
    
    q = q + item_penalty;
end