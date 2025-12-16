function pkg_group_best = group_ga(packages, data, params)
    % group_ga 在 package 级别上执行简化的改进遗传搜索，返回每个 package 的大组编号 1..G
    % 说明：此实现为轻量可运行版本，用 Q（调用 problem2_evaluate）作为目标（越小越好）
    % 输入:
    % packages: create_packages 输出
    % data: 原始数据结构（用于 evaluate 时展开包）
    % params: 包含 G, popsize, generations 等
    % 输出:
    % pkg_group_best: P x 1 整数向量
    %待实现：加载历史解
   
    % 添加必要的路径
    addpath('D:\MATLAB\projects\海外仓多约束规划_problem1\src\core\algorithms\subgroup\utils');
    addpath('D:\MATLAB\projects\海外仓多约束规划_problem1\src\utils\for_group_ga');
    
    % 参数
    G = getfieldwithdefault(params,'G',6);
    popsize = getfieldwithdefault(params,'ga.population_size',40);
    generations = getfieldwithdefault(params,'ga.generations',200);
    cx_rate = getfieldwithdefault(params,'ga.crossover_rate',0.7);
    mut_rate = getfieldwithdefault(params,'ga.mutation_rate',0.3);%？
    seed = getfieldwithdefault(params,'seed',0);
    if seed>0, rng(seed); end
    
    P = numel(packages.list);
    eval_func = @(assign) evaluate_assignment(assign, packages, data, params, G, P);
    
    % 初始化种群（整型矩阵 popsize x P）
    pop = zeros(popsize, P);
    % 60% random, 20% time guided, 20% material guided
    n_random = max(1,round(0.6*popsize));
    n_time = max(1,round(0.2*popsize));
    n_mat = max(1, popsize - n_random - n_time);
    function assign = random_assign()
        assign = randi(G,1,P);
    end
    
    % 计算关联强度矩阵
    A = compute_association_strength(data, packages, params);
    
    % 初始化
    for i = 1:n_random
        pop(i,:) = random_assign();
    end
    
    % 时间引
    for i = 1:n_time
        valid = false;
        attempts = 0;
        while ~valid && attempts < 200
            attempts = attempts + 1;
            assign = random_assign();
            
            % 尝试使每个大组内包的时效一致
           
            improved = false;
            for g_idx = 1:G
                packages_in_g = find(assign == g_idx);
                if ~isempty(packages_in_g)
                    times_in_g = [];
                    for j = 1:length(packages_in_g)
                        p_idx = packages_in_g(j);
                        % 安全获取时效值
                        time_val = packages.attrs(p_idx).time;
                        if ~isempty(time_val) && isnumeric(time_val)
                            times_in_g(end+1) = time_val(1);  % 取第一个值
                        end
                    end
                    
                    % 如果有多种时效则进行重新分配尝试
                    if length(unique(times_in_g)) > 1
                        % 按时效分组并重新分配到不同大组
                        unique_times = unique(times_in_g);
                        for t_idx = 1:length(unique_times)
                            time_packages = packages_in_g(times_in_g == unique_times(t_idx));
                            new_group = mod(g_idx + t_idx - 1, G) + 1;  % 分配到不同组
                            assign(time_packages) = new_group;
                        end
                        improved = true;
                    end
                end
            end
            valid = true;
        end
        
        if ~valid || attempts >= 200
            assign = random_assign();
        end
        pop(n_random+i,:) = assign;
    end
    
    % 材质引导初始化
    for i = 1:n_mat
        assign = random_assign();
        
        % 基于关联强度矩阵A进行聚类启发式分配
        % 将关联性强的商品尽可能放在同一组
        [~, sorted_idx] = sort(sum(A,2), 'descend');  % 按总关联强度排序
        top_packages = sorted_idx(1:min(20,P));  % 取前20个高关联商品
        
        % 为这些高关联商品创建"种子组"
        n_seeds = min(G, 5);
        if n_seeds > 0
            seed_groups = randperm(G, n_seeds);
            
            for s = 1:n_seeds
                if s <= length(top_packages)
                    pkg_idx = top_packages(s);
                    % 找到与该商品关联最强的其他商品
                    [~, related_idx] = sort(A(pkg_idx, :), 'descend');
                    n_related = min(8, numel(related_idx));  % 每组最多8个商品
                    
                    % 将这些相关商品分配到同一个组
                    assign(related_idx(1:n_related)) = seed_groups(s);
                end
            end
        end
        
        pop(n_random+n_time+i,:) = assign;
    end

    %易碎品引导
    
    
    % 串行评估初始种群（避免并行环境中嵌套函数访问问题）
    fitness = zeros(popsize, 1);
    for i = 1:popsize
        fitness(i) = eval_func(pop(i, :));
    end
    % GA loop (simple)
    best_idx = find(fitness==min(fitness),1);
    pkg_group_best = pop(best_idx,:)';
    best_q = fitness(best_idx);
    history = struct('bestQ',[],'meanQ',[],'stdQ',[],'worstQ',[]);
    
    % 提前终止参数
    no_improvement_count = 0;
    previous_best = inf;
    max_no_improvement = getfieldwithdefault(params, 'ga.max_no_improvement', 50);
    stagnation_threshold = getfieldwithdefault(params, 'ga.stagnation_threshold', 1e-6);
    
    for gen = 1:generations
        % 自适应参数调整
        if gen > generations/2
            % 后期降低变异率，提高收敛性
            adaptive_mut_rate = mut_rate * 0.7;
            adaptive_cx_rate = min(0.9, cx_rate * 1.1);
        else
            adaptive_mut_rate = mut_rate;
            adaptive_cx_rate = cx_rate;
        end
        
        % selection (tournament)
        newpop = pop;
        for k = 1:2:popsize
            % select parents
            i1 = tournament_select(fitness,3);
            i2 = tournament_select(fitness,3);
            p1 = pop(i1,:);
            p2 = pop(i2,:);
            
            % crossover
            if rand < adaptive_cx_rate
                cxpt = randi([2, P-1]);  % 避免极端切割点
                c1 = [p1(1:cxpt), p2(cxpt+1:end)];
                c2 = [p2(1:cxpt), p1(cxpt+1:end)];
            else
                c1 = p1;
                c2 = p2;
            end
            
            % mutation: randomly change group of some packages, guided by low association
            if rand < adaptive_mut_rate
                c1 = mutate_assign(c1, A, G);
            end
            if rand < adaptive_mut_rate
                c2 = mutate_assign(c2, A, G);
            end
            
            % 约束修复 - 修复死循环问题
            c1 = safe_repair_assignment(c1, packages, G, 6, 18);  % 每组最少6个，最多18个
            c2 = safe_repair_assignment(c2, packages, G, 6, 18);
            
            newpop(k,:) = c1;
            if k+1 <= popsize
                newpop(k+1,:) = c2;
            end
        end
        
        % 串行评估新种群（避免并行环境中嵌套函数访问问题）
        newfitness = zeros(popsize, 1);
        for i = 1:popsize
            newfitness(i) = eval_func(newpop(i, :));
        end
        
        % 精英保留：用旧种群中的精英替换新种群中的最差个体
        elit = getfieldwithdefault(params,'ga.elitism_count',4);
        [~, idx_old] = sort(fitness);    % 从小到大，最优在前
        [~, idx_new] = sort(newfitness); % 新种群从小到大
        replace_count = min(elit, popsize);
        if replace_count > 0
            % 把新种群最差的 replace_count 个替换为旧种群最好的 replace_count 个
            worst_new_idxs = idx_new(end-replace_count+1:end);
            best_old_idxs = idx_old(1:replace_count);
            newpop(worst_new_idxs, :) = pop(best_old_idxs, :);
            newfitness(worst_new_idxs) = fitness(best_old_idxs);
        end
        
        % 更新种群
        pop = newpop;
        fitness = newfitness;
        
        % update best
        [cur_best, idxb] = min(fitness);
        if cur_best < best_q
            best_q = cur_best;
            pkg_group_best = pop(idxb,:)';
            no_improvement_count = 0;  % 重置无改进计数器
        else
            no_improvement_count = no_improvement_count + 1;  % 增加无改进计数器
        end
        
        % 记录历史统计信息
        history.bestQ(end+1) = best_q;
        history.meanQ(end+1) = mean(fitness);
        history.stdQ(end+1) = std(fitness);
        history.worstQ(end+1) = max(fitness);
        
        % 进度显示
        if mod(gen,10)==0 || gen == 1 || gen == generations
            fprintf('Gen %3d: Best=%.4f, Mean=%.4f±%.4f, Worst=%.4f\n', ...
                    gen, history.bestQ(end), history.meanQ(end), history.stdQ(end), history.worstQ(end));
        end
        
        % 提前终止检查
        if no_improvement_count >= max_no_improvement
            fprintf('Early termination at generation %d: no improvement for %d generations\n', ...
                    gen, max_no_improvement);
            break;
        end
        
        % 检查收敛阈值
        if std(fitness) < stagnation_threshold
            fprintf('Early termination at generation %d: population converged (std < %.2e)\n', ...
                    gen, stagnation_threshold);
            break;
        end
    end
end  % 主函数结束标记


% ========== 局部函数 ==========


function i = tournament_select(fit,k)
%?
    n = numel(fit);
    cand = randi(n,1,k);
    [~,mi] = min(fit(cand));
    i = cand(mi);
end

function child = mutate_assign(assign, A, G)
%?
    P = numel(assign);
    child = assign;
    
    % 计算每个包在其当前组内的凝聚度(低凝聚度更容易变异)
    cohesion = zeros(1,P);
    for p = 1:P
        same_group = find(child==child(p));
        if ~isempty(same_group) && length(same_group) > 1
            cohesion(p) = sum(A(p,same_group)) / (length(same_group) - 1); % 排除自己
        end
    end
    
    % 选择凝聚度最低的5%包进行变异
    [~, idxs] = sort(cohesion);
    nmut = max(1, round(0.05 * P));
    to_mut = idxs(1:nmut);
    
    for t = to_mut
        original_group = child(t);
        
        % 70%概率: 移动到关联度最高的组
        % 20%概率: 随机移动到其他组
        % 10%概率: 保持不变
        r = rand;
        if r < 0.7
            % 找到与该包关联度最高的其他包所在的组
            [~, sorted_groups] = sort(sum(A(t,:),2), 'descend');
            % 查找这些包所在的组，选择第一个不同的组
            new_group = original_group;
            for sg = 1:min(length(sorted_groups), 5)
                related_p = sorted_groups(sg);
                if child(related_p) ~= original_group
                    new_group = child(related_p);
                    break;
                end
            end
            if new_group == original_group
                new_group = randi(G);
            end
        elseif r < 0.9
            % 随机移动到其他组
            available_groups = setdiff(1:G, original_group);
            if ~isempty(available_groups)
                new_group = available_groups(randi(length(available_groups)));
            else
                new_group = randi(G);
            end
        else
            % 保持不变
            new_group = original_group;
        end
        
        child(t) = new_group;
    end
end

function repaired = safe_repair_assignment(assign, packages, G, min_per_group, max_per_group)
    
    repaired = assign;
    
    % 先修复包数量约束
    repaired = repair_package_count(repaired, G, min_per_group, max_per_group);
    
    % 再修复商品数量约束
    repaired = repair_item_count(repaired, packages, G, 12);
    
    % 材质修复 - 简化版本（注释掉复杂循环以避免循环问题）
    % 保留基本的材质检查和简单修复
    material_satisfied = whole_check_material_constraint(repaired, packages, G);
    
    if ~material_satisfied
        % 只进行一次简单的材质修复尝试，不进行复杂的循环修复
        % 这样可以保留基本的材质修复功能，同时避免陷入循环
        if exist('repair_material_constraint', 'file')
            repaired = repair_material_constraint(repaired, packages, G);
        else
            % 使用简化修复
            repaired = simple_material_repair(repaired, packages, G);
        end
        
        % 重新检查包数量和商品数量约束
        repaired = repair_package_count(repaired, G, min_per_group, max_per_group);
        repaired = repair_item_count(repaired, packages, G, 12);
    end
    
    % 以下是原始的复杂材质修复循环（已注释，保留代码以备需要时恢复）
    % 材质修复
    % max_material_attempts = 5;
    % material_satisfied = whole_check_material_constraint(repaired, packages, G);
    % 
    % if ~material_satisfied
    %     %fprintf('🔄 开始材质约束修复 (最多%d次尝试)...\n', max_material_attempts);
    %     
    %     % 记录历史状态以避免循环
    %     % previous_states = {};
    %     % cycle_detected = false;
    %     
    %     for attempt = 1:max_material_attempts
    %         % 检查当前状态是否出现过（循环检测）
    %         % current_state = mat2str(sort(repaired));
    %         % if ismember(current_state, previous_states)
    %         %     %fprintf('  ⚠️  检测到循环状态，提前终止材质修复\n');
    %         %     cycle_detected = true;
    %         %     break;
    %         % end
    %         % previous_states{end+1} = current_state;
    %         
    %         old_repaired = repaired;
    %         
    %         % 尝试修复材质约束 - 使用utils/repair目录中的函数
    %         if exist('repair_material_constraint', 'file')
    %             repaired = repair_material_constraint(repaired, packages, G);
    %         else
    %             % 如果修复函数不存在，使用简化修复
    %             repaired = simple_material_repair(repaired, packages, G);
    %         end
    %         
    %         % 使用utils/for_group_ga中的whole_check_material_constraint函数
    %         material_satisfied = whole_check_material_constraint(repaired, packages, G);
    %         
    %         if material_satisfied
    %             %fprintf('  ✅ 材质约束满足 (尝试 %d/%d)\n', attempt, max_material_attempts);
    %             break;
    %         end
    %         
    %         % 如果修复没有效果，尝试随机扰动
    %         if isequal(old_repaired, repaired) && ~material_satisfied
    %             %fprintf('  🔄 修复无改进，尝试随机扰动...\n');
    %             repaired = random_perturbation(repaired, packages, G);
    %         end
    %         
    %         % 重新检查包数量和商品数量约束
    %         repaired = repair_package_count(repaired, G, min_per_group, max_per_group);
    %         repaired = repair_item_count(repaired, packages, G, 12);
    %         
    %         if attempt == max_material_attempts
    %             %fprintf('  ⚠️  达到最大材质修复尝试次数 (%d次)，接受当前解\n', max_material_attempts);
    %           
    %         end
    %     end
    %     
    %     % 如果检测到循环，使用备选修复策略
    %     if cycle_detected && attempt < max_material_attempts
    %         %fprintf('  🔄 使用备选策略打破循环...\n');
    %         repaired = break_cycle_strategy(repaired, packages, G, min_per_group, max_per_group);
    %     end
    % end
end

function repaired = simple_material_repair(assign, packages, G)
    % 改进的材质约束修复，增加随机性避免确定性循环
    repaired = assign;
    
    for g = 1:G
        if ~check_single_group_material_constraint(repaired, packages, g)
            % 获取组g中的所有包
            group_packages = find(repaired == g);
            
            % 获取这些包的材质
            all_materials = [];
            for p = 1:length(group_packages)
                pkg_idx = group_packages(p);
                if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
                    pkg_materials = packages.attrs(pkg_idx).material;
                    
                    if isnumeric(pkg_materials)
                        all_materials = [all_materials, pkg_materials(:)'];
                    elseif iscell(pkg_materials)
                        for m = 1:length(pkg_materials)
                            if isnumeric(pkg_materials{m})
                                all_materials = [all_materials, pkg_materials{m}(:)'];
                            end
                        end
                    end
                end
            end
            
            % 统计每种材质的数量
            unique_materials = unique(all_materials);
            material_counts = zeros(1, length(unique_materials));
            for i = 1:length(unique_materials)
                material_counts(i) = sum(all_materials == unique_materials(i));
            end
            
            % 保留数量最多的两种材质，移除其他材质
            % 添加随机性来避免确定性循环
            [~, top_indices] = sort(material_counts, 'descend');
            
            % 当材质数量超过2且数量相同时，随机选择保留的材质
            if length(unique_materials) > 2 && length(top_indices) >= 3 && ...
               material_counts(top_indices(2)) == material_counts(top_indices(3))
                % 在数量相同的材质中随机选择一个
                top_materials = top_indices(1); % 第一个总是数量最多的
                remaining_indices = top_indices(2:end);
                same_count_indices = find(material_counts(remaining_indices) == material_counts(top_indices(2)));
                selected_index = randi(length(same_count_indices));
                top_materials = [top_materials, remaining_indices(same_count_indices(selected_index))];
            else
                top_materials = top_indices(1:min(2, length(unique_materials)));
            end
            
            keep_materials = unique_materials(top_materials);
            
            % 识别包含移除材质的包
            packages_to_move = [];
            for p = 1:length(group_packages)
                pkg_idx = group_packages(p);
                if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
                    pkg_materials = packages.attrs(pkg_idx).material;
                    pkg_materials_vec = [];
                    
                    % 提取包中的所有材质
                    if isnumeric(pkg_materials)
                        pkg_materials_vec = pkg_materials(:)';
                    elseif iscell(pkg_materials)
                        for m = 1:length(pkg_materials)
                            if isnumeric(pkg_materials{m})
                                pkg_materials_vec = [pkg_materials_vec, pkg_materials{m}(:)'];
                            end
                        end
                    end
                    
                    % 检查包中是否只包含需要移除的材质
                    if ~isempty(pkg_materials_vec)
                        pkg_unique_materials = unique(pkg_materials_vec);
                        % 如果包中的所有材质都需要被移除，则移动该包
                        if isempty(intersect(pkg_unique_materials, keep_materials))
                            packages_to_move = [packages_to_move, pkg_idx];
                        end
                    end
                end
            end
            
            % 如果没有需要移动的包，则随机选择一些包移动
            if isempty(packages_to_move) && length(group_packages) > 1
                % 随机选择一些包，但避免每次都选择相同的包
                packages_to_move = group_packages(randperm(length(group_packages), ...
                                    max(1, round(0.2 * length(group_packages)))));
            end
            
            % 将选择的包移动到其他组
            for i = 1:length(packages_to_move)
                available_groups = setdiff(1:G, g);
                if ~isempty(available_groups)
                    pkg_idx = packages_to_move(i);
                    pkg_materials = [];
                    if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
                        pkg_materials = packages.attrs(pkg_idx).material;
                    end
                    
                    % 计算每个可用组的适合度得分
                    group_scores = zeros(1, length(available_groups));
                    for j = 1:length(available_groups)
                        target_group = available_groups(j);
                        % 计算该组当前材质
                        group_materials = get_group_materials(repaired, packages, target_group);
                        
                        % 计算与目标组的材质兼容性得分
                        if isempty(pkg_materials) || isempty(group_materials)
                            group_scores(j) = 0; % 无材质信息时给中性分
                        else
                            % 材质兼容性评分：共有材质越多得分越高
                            pkg_materials_vec = [];
                            if isnumeric(pkg_materials)
                                pkg_materials_vec = pkg_materials(:)';
                            elseif iscell(pkg_materials)
                                for m = 1:length(pkg_materials)
                                    if isnumeric(pkg_materials{m})
                                        pkg_materials_vec = [pkg_materials_vec, pkg_materials{m}(:)'];
                                    end
                                end
                            end
                            
                            % 计算交集大小
                            intersection_count = length(intersect(unique(pkg_materials_vec), group_materials));
                            group_scores(j) = intersection_count;
                        end
                    end
                    
                    % 找出得分最高的组
                    max_score = max(group_scores);
                    best_groups = available_groups(group_scores == max_score);
                    
                    % 从最佳组中随机选择一个，避免每次都选择同一组
                    if ~isempty(best_groups)
                        selected_group = best_groups(randi(length(best_groups)));
                        repaired(pkg_idx) = selected_group;
                    end
                end
            end
        end
    end
end

function repaired = random_perturbation(assign, packages, G)
    % 随机扰动分配
    repaired = assign;
    P = length(assign);
    
    % 随机移动一些包
    n_perturb = max(1, round(0.1 * P));
    perturb_indices = randperm(P, n_perturb);
    
    for i = 1:length(perturb_indices)
        pkg_idx = perturb_indices(i);
        current_group = repaired(pkg_idx);
        available_groups = setdiff(1:G, current_group);
        
        if ~isempty(available_groups)
            new_group = available_groups(randi(length(available_groups)));
            repaired(pkg_idx) = new_group;
        end
    end
end

function repaired = break_cycle_strategy(assign, packages, G, min_per_group, max_per_group)
    % 打破循环的备选策略
    fprintf('  使用全局重新分配打破循环...\n');
    
    % 方法: 完全随机重新分配
    repaired = randi(G, size(assign));
    
    % 修复基本约束
    repaired = repair_package_count(repaired, G, min_per_group, max_per_group);
    repaired = repair_item_count(repaired, packages, G, 12);
    
    %fprintf('  🔄 循环已打破，继续遗传算法优化\n');
end



function materials = get_group_materials(assign, packages, g)
    % 获取组的材质列表
    packages_in_group = find(assign == g);
    materials = [];
    for p = 1:length(packages_in_group)
        pkg_idx = packages_in_group(p);
        if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
            pkg_materials = packages.attrs(pkg_idx).material;
            if isnumeric(pkg_materials)
                materials = [materials, pkg_materials(:)'];
            elseif iscell(pkg_materials)
                for j = 1:length(pkg_materials)
                    if isnumeric(pkg_materials{j})
                        materials = [materials, pkg_materials{j}(:)'];
                    end
                end
            end
        end
    end
    materials = unique(materials);
end

% 移除内部重复的材质约束检查函数，改为调用外部工具函数
% 单个组材质约束检查 - 调用外部工具函数
function is_satisfied = check_single_group_material_constraint(assign, packages, g)
    % 获取该组中的所有包
    packages_in_group = find(assign == g);
    % 调用外部工具函数检查单个组材质约束
    is_satisfied = check_single_group_material_constrain(packages_in_group, packages);
end

% 所有组材质约束检查 - 调用外部工具函数
function is_satisfied = check_material_constraint(assign, packages, G)
    % 调用外部工具函数检查所有组材质约束
    is_satisfied = whole_check_material_constraint(assign, packages, G);
end

function repaired = repair_package_count(assign, G, min_per_group, max_per_group)
    % 调用外部工具函数进行包数量约束修复
    % 如果外部函数不存在或调用失败，使用内部备用实现
    if exist('utils/for_group_ga/repair_package_count.m', 'file')
        try
            % 尝试调用外部函数
            repaired = utils.for_group_ga.repair_package_count(assign, G, min_per_group, max_per_group);
            return;
        catch
            % 如果外部函数调用失败，使用内部实现
            warning('外部repair_package_count函数调用失败，使用内部实现');
        end
    end
    
    % 内部备用实现
    repaired = assign;
    group_counts = histcounts(repaired, [1:G+1]);
    
    % 检查是否有组超出上限或低于下限
    over_groups = find(group_counts > max_per_group);
    under_groups = find(group_counts < min_per_group);
    
    % 处理超出上限的组
    for g = over_groups
        members = find(repaired == g);
        excess = length(members) - max_per_group;
        if excess > 0
            % 随机选择excess个成员移动到其他组
            to_move = members(randperm(length(members), excess));
            for i = 1:length(to_move)
                % 寻找成员最少的组
                [~, target_group] = min(group_counts);
                if group_counts(target_group) >= max_per_group
                    % 如果所有组都满了，随机选择一个非当前组
                    available = setdiff(1:G, g);
                    target_group = available(randi(length(available)));
                end
                repaired(to_move(i)) = target_group;
                group_counts(g) = group_counts(g) - 1;
                group_counts(target_group) = group_counts(target_group) + 1;
            end
        end
    end
    
    % 处理低于下限的组
    for g = under_groups
        members = find(repaired == g);
        deficit = min_per_group - length(members);
        if deficit > 0
            % 从成员最多的组中借调
            while deficit > 0
                [~, source_group] = max(group_counts);
                if group_counts(source_group) <= min_per_group
                    break; % 无法再借调
                end
                
                % 从源组中选择一个成员
                source_members = find(repaired == source_group);
                if ~isempty(source_members)
                    member_to_move = source_members(1);
                    repaired(member_to_move) = g;
                    group_counts(source_group) = group_counts(source_group) - 1;
                    group_counts(g) = group_counts(g) + 1;
                    deficit = deficit - 1;
                else
                    break;
                end
            end
        end
    end
end

function repaired = repair_item_count(assign, packages, G, target_items_per_group)
    % 调用外部工具函数进行商品数量约束修复
    % 如果外部函数不存在或调用失败，使用内部备用实现
    if exist('utils/for_group_ga/repair_item_count.m', 'file')
        try
            % 尝试调用外部函数
            repaired = utils.for_group_ga.repair_item_count(assign, packages, G, target_items_per_group);
            return;
        catch
            % 如果外部函数调用失败，使用内部实现
            %warning('外部repair_item_count函数调用失败，使用内部实现');
        end
    end
    
    % 内部备用实现
    repaired = assign;
    
    % 计算每个组的实际商品数量
    actual_counts = calculate_group_item_counts(assign, packages, G);
    
    % 如果已经满足约束，直接返回
    if all(actual_counts == target_items_per_group)
        return;
    end
    
    % 简单修复策略：调整包的分配以满足商品数量约束
    max_attempts = 100;
    for attempt = 1:max_attempts
        temp_assign = repaired;
        actual_counts = calculate_group_item_counts(temp_assign, packages, G);
        
        % 如果满足约束，返回结果
        if all(actual_counts == target_items_per_group)
            repaired = temp_assign;
            return;
        end
        
        % 调整商品数量过多的组
        over_groups = find(actual_counts > target_items_per_group);
        under_groups = find(actual_counts < target_items_per_group);
        
        if ~isempty(over_groups) && ~isempty(under_groups)
            from_group = over_groups(1);
            to_group = under_groups(1);
            
            % 从商品数量过多的组中移动一个包到商品数量过少的组
            packages_in_from = find(temp_assign == from_group);
            if ~isempty(packages_in_from)
                % 选择商品数量最少的包进行移动
                package_sizes = zeros(length(packages_in_from), 1);
                for i = 1:length(packages_in_from)
                    pkg_id = packages_in_from(i);
                    package_sizes(i) = length(packages.list{pkg_id});
                end
                
                % 选择合适的包进行移动
                [~, sorted_idx] = sort(package_sizes);
                for i = 1:length(sorted_idx)
                    pkg_to_move = packages_in_from(sorted_idx(i));
                    pkg_size = package_sizes(sorted_idx(i));
                    
                    % 检查移动后是否更接近目标
                    new_from_count = actual_counts(from_group) - pkg_size;
                    new_to_count = actual_counts(to_group) + pkg_size;
                    
                    if abs(new_from_count - target_items_per_group) < abs(actual_counts(from_group) - target_items_per_group) || ...
                       abs(new_to_count - target_items_per_group) < abs(actual_counts(to_group) - target_items_per_group)
                        temp_assign(pkg_to_move) = to_group;
                        break;
                    end
                end
            end
        else
            break;
        end
    end
    
    % 最后的验证和调整
    actual_counts = calculate_group_item_counts(repaired, packages, G);
    if any(actual_counts ~= target_items_per_group)
        % 如果仍然不满足约束，使用更简单的策略
        repaired = simple_item_repair(assign, packages, G, target_items_per_group);
    end
end

function counts = calculate_group_item_counts(assign, packages, G)
    % 计算每个组的商品数量
    counts = zeros(1, G);
    for g = 1:G
        packages_in_group = find(assign == g);
        for p = 1:length(packages_in_group)
            pkg_id = packages_in_group(p);
            counts(g) = counts(g) + length(packages.list{pkg_id});
        end
    end
end

function repaired = simple_item_repair(assign, packages, G, target_items_per_group)
    % 简单的商品数量修复策略
    repaired = assign;
    actual_counts = calculate_group_item_counts(repaired, packages, G);
    
    % 重新随机分配直到满足约束或达到最大尝试次数
    max_attempts = 500;
    for attempt = 1:max_attempts
        if all(actual_counts == target_items_per_group)
            return;
        end
        
        % 重新随机分配
        temp_assign = randi(G, size(assign));
        actual_counts = calculate_group_item_counts(temp_assign, packages, G);
        
        if all(actual_counts == target_items_per_group)
            repaired = temp_assign;
            return;
        end
    end
end

function q = evaluate_assignment(assign, packages, data, params, G, P)
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
            item_penalty = item_penalty + deviation * 1000;  % 对每个商品偏差施加重罚
        end
    end
    
    q = q + item_penalty;
end

function score = calculate_group_score(pkg_idx, target_group, assign, packages, remove_materials)
    % 计算将包移动到目标组后的得分
    temp_assign = assign;
    temp_assign(pkg_idx) = target_group;
    
    % 检查移动后是否违反材质约束
    if ~check_material_constraint(temp_assign, packages, target_group)
        score = -100; % 违反约束，给低分
        return;
    end
    
    % 计算材质兼容性得分
    pkg_materials = [];
    if isfield(packages.attrs(pkg_idx), 'material') && ~isempty(packages.attrs(pkg_idx).material)
        pkg_materials = packages.attrs(pkg_idx).material;
    end
    
    group_materials = get_group_materials(temp_assign, packages, target_group);
    
    % 计算相同材质的数量
    if iscell(pkg_materials)
        pkg_materials_vec = [];
        for m = 1:length(pkg_materials)
            if isnumeric(pkg_materials{m})
                pkg_materials_vec = [pkg_materials_vec, pkg_materials{m}(:)'];
            end
        end
        pkg_materials = pkg_materials_vec;
    end
    
    same_material_count = sum(ismember(group_materials, pkg_materials));
    total_materials = length(group_materials);
    
    % 计算得分：相同材质越多，得分越高
    % 如果组内材质种类较少，也给予奖励
    if total_materials > 0
        material_diversity = length(unique(group_materials));
        diversity_bonus = 5 * (3 - material_diversity); % 材质越少，奖励越高
        score = same_material_count * 10 + diversity_bonus;
    else
        score = 50; % 空组给予较高分数
    end
end