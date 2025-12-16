function mutated = mutate_assign(assign, G, mutation_rate)
% 出现在：group_ga.m
% 遗传算法中的变异操作
    mutated = assign;
    n_packages = length(assign);
    
    % 确定要变异的包数量
    n_to_mutate = max(1, round(n_packages * mutation_rate));
    
    % 随机选择要变异的包
    to_mutate = randperm(n_packages, n_to_mutate);
    
    % 对选中的包进行变异
    for i = 1:length(to_mutate)
        pkg_idx = to_mutate(i);
        current_group = mutated(pkg_idx);
        
        % 随机选择一个不同的组
        possible_groups = setdiff(1:G, current_group);
        if ~isempty(possible_groups)
            new_group = possible_groups(randi(length(possible_groups)));
            mutated(pkg_idx) = new_group;
        end
    end
end