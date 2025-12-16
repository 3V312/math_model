function [child1, child2] = cross_over(parent1, parent2)
% 出现在：group_ga.m
% 遗传算法的交叉操作（单点交叉）
    n_packages = length(parent1);
    
    % 随机选择交叉点
    crossover_point = randi(n_packages-1);
    
    % 创建后代
    child1 = [parent1(1:crossover_point), parent2(crossover_point+1:end)];
    child2 = [parent2(1:crossover_point), parent1(crossover_point+1:end)];
end