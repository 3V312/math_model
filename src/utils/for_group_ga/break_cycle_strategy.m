% 出现在：group_ga.m中的safe_repair_assignment函数
function repaired = break_cycle_strategy(assign, packages, G, min_per_group, max_per_group)
% 打破循环的备选策略
    fprintf('  使用全局重新分配打破循环...\n');
    
    % 方法: 完全随机重新分配
    repaired = randi(G, size(assign));
    
    % 修复基本约束
    repaired = repair_package_count(repaired, G, min_per_group, max_per_group);
    repaired = repair_item_count(repaired, packages, G, 12);
    
    fprintf('  🔄 循环已打破，继续遗传算法优化\n');
end