






function items_to_discard = smart_constraint_based_discard(items, data, params, n_to_discard)
% SMART_CONSTRAINT_BASED_DISCARD 基于约束违反的智能丢弃决策
% 综合考虑约束违反程度和目标函数影响，选择最优的丢弃商品
% 输入:
%   items - 商品索引列表
%   data - 数据结构体，包含商品属性
%   params - 算法参数
%   n_to_discard - 需要丢弃的商品数量
% 输出:
%   items_to_discard - 要丢弃的商品索引列表

    % 初始化要丢弃的商品列表
    items_to_discard = [];
    
    % === 1. 计算约束违反分数 ===
    % 评估每个商品对约束违反的贡献程度
    violation_scores = compute_constraint_violations(items, data, params);
    
    % === 2. 计算目标函数影响分数 ===
    % 评估丢弃每个商品对优化目标的影响
    target_scores = compute_target_impact(items, data, params);
    
    % === 3. 综合评分 ===
    % 优先考虑约束违反（权重较高），其次考虑目标函数优化
    % violation_scores 权重为 1.0，target_scores 权重为 0.3
    total_scores = violation_scores + target_scores * 0.3;
    
    % === 4. 按综合分数排序 ===
    % 分数高的商品优先丢弃（违反约束严重且对目标函数影响小）
    [~, sort_idx] = sort(total_scores, 'descend');
    
    % === 5. 选择要丢弃的商品 ===
    % 选择综合评分最高的前 n_to_discard 个商品
    items_to_discard = items(sort_idx(1:n_to_discard));
    
    % === 6. 输出决策详情 ===
    % 打印决策过程和结果，便于调试和监控
    fprintf('智能丢弃决策：\n');
    [time_viol, material_viol, fragile_viol] = check_group_constraints(items, data, params);
    fprintf('   约束状态: 时效%d, 材质%d, 易碎品%.3f\n', time_viol, material_viol, fragile_viol);
    
    % 显示前3个被丢弃商品的详细评分
    for i = 1:min(3, n_to_discard)
        item_idx = items_to_discard(i);
        fprintf('   丢弃商品%d: 违-%.2f, 目-%.2f, 总-%.2f\n', ...
            item_idx, violation_scores(sort_idx(i)), ...
            target_scores(sort_idx(i)), total_scores(sort_idx(i)));
    end
end
