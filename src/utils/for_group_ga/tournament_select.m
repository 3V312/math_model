function selected = tournament_select(population, scores, tournament_size)
% 出现在：group_ga.m
% 锦标赛选择操作
    [pop_size, n_packages] = size(population);
    selected = zeros(1, n_packages);
    
    % 随机选择锦标赛参与者
    participants_idx = randperm(pop_size, tournament_size);
    participants_scores = scores(participants_idx);
    
    % 选择得分最低的个体（因为我们是最小化问题）
    [~, best_idx] = min(participants_scores);
    selected = population(participants_idx(best_idx), :);
end