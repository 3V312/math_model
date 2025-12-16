function perturbed = random_perturbation(assign, G, perturbation_rate)
% 出现在：group_ga.m
% 对分配方案进行随机扰动，增加解的多样性
    perturbed = assign;
    n_packages = length(assign);
    
    % 确定要扰动的包数量
    n_to_perturb = max(1, round(n_packages * perturbation_rate));
    
    % 随机选择要扰动的包
    to_perturb = randperm(n_packages, n_to_perturb);
    
    % 对选中的包进行随机重新分配
    for i = 1:length(to_perturb)
        pkg_idx = to_perturb(i);
        perturbed(pkg_idx) = randi(G);
    end
end