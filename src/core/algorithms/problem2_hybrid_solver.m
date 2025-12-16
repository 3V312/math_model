function [x_best, y_best, z_best, Q_best, history] = problem2_hybrid_solver(data, params)
% problem2_hybrid_solver 主求解器 - 协调整个两阶段求解流程
% 输入:
%   data - 商品数据结构体（来自load_data）
%   params - 算法参数结构体
% 输出:
%   x_best, y_best, z_best - 分组矩阵
%   Q_best - 最优目标值
%   history - 优化历史记录

    % 初始化历史记录
    history = struct();
    history.Q_values = [];
    history.feasible_counts = [];
    history.weight_differences = [];
    history.volume_differences = [];
    history.timestamps = [];
    
    % 初始化最优解
    Q_best = inf;
    x_best = [];
    y_best = [];
    z_best = [];
    
    % 预处理：商品打包：三打包，二不打包？？？
    packages = create_packages(data, params);
    
    % 外层循环参数
    max_outer_iterations = params.outer.max_iterations;
    stall_limit = params.outer.stall_limit;
    tolerance = params.outer.tolerance;
    
    % 收敛监控变量
    stall_count = 0;
    last_best_Q = inf;
    
    % 外层循环
    for outer_iter = 1:max_outer_iterations
        fprintf('开始第 %d 次外层迭代\n', outer_iter);
        
        % 阶段一：大组划分
        pkg_group_assign = group_ga(packages, data, params);
        
        % 构建全局x矩阵（包到大组的分配）(商品到大组）
        num_packages = length(packages.list); 
        %x_current = false(num_packages, params.G);
        [x_current, ~, ~] = expand_pkg_assign(pkg_group_assign, packages, data, params, params.G, length(pkg_group_assign));
        for g = 1:params.G
            package_indices = pkg_group_assign == g;
            x_current(package_indices, g) = true;
        end
        
        % 阶段二：小组细分（并行处理每个大组）
        y_current = false(size(data.volumes, 1), params.G * 3);  % 72×18矩阵
        z_current = false(params.G, params.G * 3);  % 6×18矩阵
        
        total_volume_diff = 0;
        dropped_items_record = {};
    for g = 1:params.G
            % 找出属于大组g的所有原始商品
            items_in_g = find(x_current(:, g));

            % 确保结果是列向量

            items_in_g = items_in_g(:);
            
            % 调用
    
            [y_g, z_g, vol_diff_g, dropped_g,success] = subgroup_assign(items_in_g, data, params);
    
          

           % 当丢弃商品时，使用商品的实际索引更新全局分配矩阵
            if ~isempty(dropped_g)
             % 从 items_in_g 中移除被丢弃的商品
            items_in_g = setdiff(items_in_g, dropped_g);
            fprintf('大组 %d: 丢弃 %d 件商品，剩余 %d 件商品\n', g, length(dropped_g), length(items_in_g));
    
            % 使用商品的实际索引更新全局分配矩阵
            % dropped_g 包含的是实际的商品编号（1-80），可以直接用于索引
            x_current(dropped_g, g) = false;  % 将被丢弃商品在当前大组的分配设为false
            end

        % 记录体积差
        total_volume_diff = total_volume_diff + vol_diff_g;

        % 整合到全局y,z矩阵
        % 使用更新后的 items_in_g（已移除丢弃商品）
        for k = 1:3
            global_sub_id = (g-1) * 3 + k;
            if ~isempty(items_in_g) && k <= size(y_g, 2)
                y_current(items_in_g, global_sub_id) = y_g(:, k);
                z_current(g, global_sub_id) = z_g(1, k);
            end
        end

        % 错误处理应该在调用之后
        if ~success
            fprintf('大组 %d 小组细分失败，尝试回退分配\n', g);
            % 当小组细分失败时，尝试简单地将所有商品平均分配到三个小组
            if ~isempty(items_in_g)
                n_items = length(items_in_g);
                items_per_sub = ceil(n_items / 3);
                
                for k = 1:3
                    global_sub_id = (g-1) * 3 + k;
                    start_idx = (k-1) * items_per_sub + 1;
                    end_idx = min(k * items_per_sub, n_items);
                    
                    if start_idx <= end_idx
                        sub_items = items_in_g(start_idx:end_idx);
                        y_current(sub_items, global_sub_id) = true;
                        z_current(g, global_sub_id) = true;
                        fprintf('大组 %d 回退分配：小组 %d 分配了 %d 件商品\n', g, k, length(sub_items));
                    end
                end
            end
            
            % 保存当前解
            solution = struct('x', x_best, 'y', y_best, 'z', z_best, 'Q', Q_best);
            problem2_save_solution(solution);
        end

        
        % 评估当前解
        [Q_current, comps] = problem2_evaluate(x_current, y_current, z_current, data, params);
        
        % 更新历史记录
        history.Q_values(end+1) = Q_current;
        history.feasible_counts(end+1) = comps.feasible;
        %history.weight_differences(end+1) = comps.weight_imbalance;
        history.weight_differences(end+1) = comps.deltaW_norm;
        history.volume_differences(end+1) = total_volume_diff;
        history.timestamps(end+1) = toc;
        
        % 检查是否为新的最优解
        if Q_current < Q_best
            Q_best = Q_current;
            x_best = x_current;
            y_best = y_current;
            z_best = z_current;
            
            % 显示进度
            fprintf('外层迭代 %d: 发现更优解 Q=%.6f\n', outer_iter, Q_best);
        end
        
        % 收敛检测
        if abs(last_best_Q - Q_best) < tolerance
            stall_count = stall_count + 1;
        else
            stall_count = 0;
        end
        
        last_best_Q = Q_best;
        
        % 如果连续停滞超过限制，则终止
        if stall_count >= stall_limit
            fprintf('检测到连续 %d 次停滞，提前终止优化\n', stall_limit);
            break;
        end
    end
    
    % 保存最终结果
    solution = struct('x', x_best, 'y', y_best, 'z', z_best, 'Q', Q_best);
    problem2_save_solution(solution);
    
    fprintf('优化完成，最优目标值 Q=%.6f\n', Q_best);
    end
