function best_assign = group_ga_u(packages, G, pop_size, max_gen, crossover_rate, mutation_rate)
% 分组遗传算法的主函数
    n_packages = length(packages.list);
    
    % 计算每组包的最小和最大数量
    min_per_group = max(1, floor(n_packages / (2*G)));
    max_per_group = ceil((n_packages / G)*1.5);
    
    % 创建初始种群
    population = create_initial_population(pop_size, n_packages, G, min_per_group, max_per_group, packages);
    
    % 初始化最佳解
    best_score = inf;
    best_assign = [];
    
    % 主循环
    for gen = 1:max_gen
        % 计算适应度
        scores = zeros(1, pop_size);
        for i = 1:pop_size
            scores(i) = evaluate_assignment(population(i, :), packages, G, 12);
        end
        
        % 更新最佳解
        [current_best_score, idx] = min(scores);
        if current_best_score < best_score
            best_score = current_best_score;
            best_assign = population(idx, :);
            fprintf('代数 %d: 最佳适应度 = %.2f\n', gen, best_score);
        end
        
        % 选择
        new_population = zeros(pop_size, n_packages);
        for i = 1:pop_size
            % 轮盘赌选择
            fitness_sum = sum(scores);
            if fitness_sum > 0
                % 使用倒数作为适应度（因为我们要最小化分数）
                inv_scores = 1 ./ (scores + eps);
                fitness_sum = sum(inv_scores);
                r = rand() * fitness_sum;
                cum_sum = 0;
                selected = 1;
                for j = 1:pop_size
                    cum_sum = cum_sum + inv_scores(j);
                    if cum_sum >= r
                        selected = j;
                        break;
                    end
                end
                new_population(i, :) = population(selected, :);
            else
                % 如果所有分数都是0，随机选择
                new_population(i, :) = population(randi(pop_size), :);
            end
        end
        
        % 交叉
        for i = 1:2:pop_size-1
            if rand() < crossover_rate
                [child1, child2] = cross_over(new_population(i, :), new_population(i+1, :));
                new_population(i, :) = child1;
                new_population(i+1, :) = child2;
            end
        end
        
        % 变异
        for i = 1:pop_size
            if rand() < mutation_rate
                new_population(i, :) = mutate_assign(new_population(i, :), G, mutation_rate);
            end
        end
        
        % 随机扰动
        for i = 1:pop_size
            if rand() < 0.1 % 较小的扰动概率
                new_population(i, :) = random_perturbation(new_population(i, :), G, 0.05);
            end
        end
        
        % 修复
        for i = 1:pop_size
            % 修复包数量约束
            new_population(i, :) = safe_repair_assignment(new_population(i, :), G, min_per_group, max_per_group);
            
            % 修复商品数量约束
            new_population(i, :) = repair_item_count(new_population(i, :), packages, G, 12);
            
            % 修复材质约束
            new_population(i, :) = simple_material_repair(new_population(i, :), packages, G);
        end
        
        % 更新种群
        population = new_population;
    end
    
    fprintf('遗传算法完成！\n');
end