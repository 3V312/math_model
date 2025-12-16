function solution = run_solver_algorithm_stage1(solution, data, packages, params)
% RUN_SOLVER_ALGORITHM_STAGE1 执行问题三第一阶段的求解算法
%   功能：使用局部搜索算法优化初始解决方案
%   输入：
%       solution - 初始解决方案结构体
%       data - 商品数据结构体
%       packages - 商品包结构体
%       params - 参数结构体
%   输出：
%       solution - 优化后的解决方案结构体

    % 检查必要的字段
    if ~isfield(solution, 'group_assign') || ~isfield(solution, 'package_assign')
        error('解决方案结构体缺少必要的字段');
    end
    
    % 记录算法开始时间
    start_time = now;
    
    % 设置算法参数
    if ~isfield(params, 'max_iterations')
        params.max_iterations = 1000;
    end
    
    if ~isfield(params, 'tol')
        params.tol = 1e-6;
    end
    
    % 创建子组参数
    subgroup_params = params;
    subgroup_params.subgroup = struct();
    subgroup_params.subgroup.max_iterations = 100;
    subgroup_params.subgroup.no_improve_limit = 20;
    subgroup_params.subgroup.enable_swap = true;
    subgroup_params.subgroup.enable_shift = true;
    subgroup_params.subgroup.enable_fragile_repair = true;
    subgroup_params.subgroup.enable_fragile_rebalance = true;
    subgroup_params.subgroup.fragile_volume_ratio_limit = 0.4;
    
    % 保存优化历史
    history = struct();
    history.objective_values = [];
    history.feasibility = [];
    history.iterations = [];
    
    % 迭代计数器
    iter = 0;
    
    % 初始评估
    [current_objective, current_feasible] = evaluate_solution(solution, data, params);
    history.objective_values(1) = current_objective;
    history.feasibility(1) = current_feasible;
    history.iterations(1) = iter;
    
    % 保存当前最佳解
    best_solution = solution;
    best_objective = current_objective;
    best_iter = iter;
    
    % 无改进计数器
    no_improve_count = 0;
    max_no_improve = 50;
    
    if isfield(params, 'verbose') && params.verbose
        fprintf('开始求解算法，最大迭代次数: %d\n', params.max_iterations);
        fprintf('初始目标函数值: %.6f, 可行解: %s\n', current_objective, current_feasible ? '是' : '否');
    end
    
    % 主循环
    while iter < params.max_iterations && no_improve_count < max_no_improve
        iter = iter + 1;
        
        % 对每个大组进行优化
        for g_idx = 1:params.G
            group_subgroups = solution.group_assign{g_idx};
            
            % 收集大组中的所有商品
            group_items = [];
            for sub_idx = 1:length(group_subgroups)
                if ~isempty(group_subgroups{sub_idx})
                    group_items = [group_items, group_subgroups{sub_idx}];
                end
            end
            
            if ~isempty(group_items)
                % 创建当前分配矩阵
                num_items = length(group_items);
                num_subgroups = 3;
                y_current = false(num_items, num_subgroups);
                
                % 填充当前分配矩阵
                for sub_idx = 1:length(group_subgroups)
                    if ~isempty(group_subgroups{sub_idx})
                        for item_idx = 1:length(group_subgroups{sub_idx})
                            item_num = group_subgroups{sub_idx}(item_idx);
                            item_pos = find(group_items == item_num);
                            if ~isempty(item_pos)
                                y_current(item_pos, sub_idx) = true;
                            end
                        end
                    end
                end
                
                % 创建z矩阵（大组到小组归属）
                z_current = true(1, num_subgroups);
                
                % 尝试使用局部搜索优化
                try
                    [y_optimized, z_optimized, ~] = local_search_optimization(...
                        y_current, z_current, group_items, data, subgroup_params);
                    
                    % 更新小组分配
                    optimized_subgroups = cell(num_subgroups, 1);
                    for sub_idx = 1:num_subgroups
                        assigned_items = group_items(y_optimized(:, sub_idx));
                        optimized_subgroups{sub_idx} = assigned_items;
                    end
                    
                    % 更新解决方案
                    solution.group_assign{g_idx} = optimized_subgroups;
                    
                catch ME
                    % 处理错误情况
                    if isfield(params, 'verbose') && params.verbose
                        fprintf('警告：局部搜索优化失败 (大组 %d): %s\n', g_idx, ME.message);
                    end
                end
            end
        end
        
        % 评估优化后的解决方案
        [new_objective, new_feasible] = evaluate_solution(solution, data, params);
        
        % 记录历史
        history.objective_values(end + 1) = new_objective;
        history.feasibility(end + 1) = new_feasible;
        history.iterations(end + 1) = iter;
        
        % 检查是否有改进
        if new_objective < best_objective - params.tol
            best_objective = new_objective;
            best_solution = solution;
            best_iter = iter;
            no_improve_count = 0;
            
            if isfield(params, 'verbose') && params.verbose
                fprintf('迭代 %d: 找到更好的解 - 目标函数值: %.6f, 可行解: %s\n', ...
                    iter, new_objective, new_feasible ? '是' : '否');
            end
        else
            no_improve_count = no_improve_count + 1;
        end
        
        % 显示进度
        if isfield(params, 'verbose') && params.verbose && mod(iter, 10) == 0
            fprintf('迭代 %d: 目标函数值: %.6f, 可行解: %s, 无改进次数: %d\n', ...
                iter, new_objective, new_feasible ? '是' : '否', no_improve_count);
        end
    end
    
    % 返回最佳解
    solution = best_solution;
    
    % 更新解决方案状态
    solution.status = 'optimized';
    solution.optimization_info = struct();
    solution.optimization_info.method = 'local_search';
    solution.optimization_info.iterations = iter;
    solution.optimization_info.best_iteration = best_iter;
    solution.optimization_info.no_improve_count = no_improve_count;
    solution.optimization_info.start_time = start_time;
    solution.optimization_info.end_time = now;
    solution.optimization_info.execution_time = etime(datevec(now), datevec(start_time));
    solution.optimization_info.history = history;
    
    % 最终评估
    [solution.evaluation.objective_value, solution.evaluation.feasible] = evaluate_solution(solution, data, params);
    
    if isfield(params, 'verbose') && params.verbose
        fprintf('求解算法完成\n');
        fprintf('迭代次数: %d\n', iter);
        fprintf('最佳解目标函数值: %.6f\n', best_objective);
        fprintf('最佳解可行性: %s\n', solution.evaluation.feasible ? '可行' : '不可行');
        fprintf('执行时间: %.2f 秒\n', solution.optimization_info.execution_time);
    end
end

function [objective_value, feasible] = evaluate_solution(solution, data, params)
% 评估解决方案的质量
    
    % 默认返回值
    objective_value = 0;
    feasible = false;
    
    try
        % 检查是否有evaluate_assignment_3函数可用
        if exist('evaluate_assignment_3', 'file') == 2
            % 使用problem3专用评估函数
            [objective_value, feasible, ~] = evaluate_assignment_3(solution, data, params);
        else
            % 简单的启发式评估
            total_volume_diff = 0;
            constraint_violations = 0;
            
            % 遍历每个大组
            for g_idx = 1:params.G
                group_subgroups = solution.group_assign{g_idx};
                
                % 计算小组体积
                subgroup_volumes = zeros(1, length(group_subgroups));
                for sub_idx = 1:length(group_subgroups)
                    if ~isempty(group_subgroups{sub_idx})
                        subgroup_volumes(sub_idx) = sum(data.volumes(group_subgroups{sub_idx}));
                    end
                end
                
                % 计算体积差异
                if length(group_subgroups) > 1
                    max_vol = max(subgroup_volumes);
                    min_vol = min(subgroup_volumes);
                    total_volume_diff = total_volume_diff + (max_vol - min_vol);
                end
                
                % 检查易碎品约束
                for sub_idx = 1:length(group_subgroups)
                    if ~isempty(group_subgroups{sub_idx})
                        fragile_items = group_subgroups{sub_idx}(data.fragile(group_subgroups{sub_idx}));
                        fragile_volume = sum(data.volumes(fragile_items));
                        total_volume = sum(data.volumes(group_subgroups{sub_idx}));
                        
                        % 易碎品体积比例约束
                        if total_volume > 0 && fragile_volume / total_volume > 0.4
                            constraint_violations = constraint_violations + 1;
                        end
                    end
                end
            end
            
            % 计算目标函数值
            objective_value = total_volume_diff + constraint_violations * 1000;
            
            % 检查是否可行
            feasible = (constraint_violations == 0);
        end
    catch ME
        % 处理评估过程中的错误
        fprintf('警告：评估解决方案时出错: %s\n', ME.message);
        objective_value = Inf;
        feasible = false;
    end
end