function [y_best, z_best, best_volume_diff] = local_search_optimization(y_init, z_init, items, data, params)
% 局部搜索优化函数 - 通过邻域搜索改进解质量，特别针对易碎品约束进行智能调整

    % 安全检查
    if isempty(items) | isempty(y_init) | ~isfield(params, 'subgroup')
        y_best = y_init;
        z_best = z_init;
        best_volume_diff = 0;
        return;
    end
    
    % 确保y_init的行数与items的长度匹配
    if size(y_init, 1) ~= length(items)
        fprintf('警告：y_init的行数(%d)与items的长度(%d)不匹配\n', size(y_init, 1), length(items));
        % 调整y_init的大小以匹配items的长度
        y_best = zeros(length(items), size(y_init, 2), 'logical');
        min_rows = min(size(y_init, 1), length(items));
        y_best(1:min_rows, :) = y_init(1:min_rows, :);
        z_best = z_init;
        best_volume_diff = 0;
        return;
    end
    
    % 初始化当前最优解
    y_current = y_init;
    z_current = z_init;
    
    % 安全计算体积差
    try
        current_vol_diff = compute_volume_difference(y_current, items, data);
    catch ME
        fprintf('计算体积差时出错: %s\n', ME.message);
        current_vol_diff = 0;
    end
    
    % 使用现有的参数，添加安全检查
    if ~isfield(params.subgroup, 'max_iterations')
        params.subgroup.max_iterations = 100;
    end
    
    if ~isfield(params.subgroup, 'no_improve_limit')
        params.subgroup.no_improve_limit = 20;
    end
    if ~isfield(params.subgroup, 'enable_swap')
        params.subgroup.enable_swap = true;
    end
    if ~isfield(params.subgroup, 'enable_shift')
        params.subgroup.enable_shift = true;
    end
    
    max_iterations = params.subgroup.max_iterations;
    no_improve_limit = params.subgroup.no_improve_limit;
    enable_swap = params.subgroup.enable_swap;
    enable_shift = params.subgroup.enable_shift;
    
    % 添加易碎品相关参数
    if ~isfield(params.subgroup, 'enable_fragile_repair')
        params.subgroup.enable_fragile_repair = true;
    end
    if ~isfield(params.subgroup, 'enable_fragile_rebalance')
        params.subgroup.enable_fragile_rebalance = true;
    end
    if ~isfield(params.subgroup, 'fragile_volume_ratio_limit')
        params.subgroup.fragile_volume_ratio_limit = 0.4;
    end
    
    best_solution = y_current;
    best_volume_diff = current_vol_diff;
    no_improve_count = 0;
    
    % 局部搜索主循环
    fprintf('开始局部搜索优化，最大迭代次数: %d\n', max_iterations);
    for iter = 1:max_iterations
        fprintf('迭代 %d/%d，无改进计数: %d\n', iter, max_iterations, no_improve_count);
        improved = false;
        
        % 记录当前时间用于性能监控
        iter_start_time = now;
        
        % 1. 首先检查并修复易碎品约束违反
        if params.subgroup.enable_fragile_repair
            try
                y_current = repair_fragile_constraints(y_current, z_current, items, data, params);
                current_vol_diff = compute_volume_difference(y_current, items, data);
                
                if current_vol_diff < best_volume_diff
                    best_solution = y_current;
                    best_volume_diff = current_vol_diff;
                    improved = true;
                end
            catch ME
                fprintf('修复易碎品约束时出错: %s\n', ME.message);
            end
        end
        
        % 2. 尝试商品交换操作
        if enable_swap
            try
                improved_swap = perform_smart_swap(y_current, z_current, items, data, params, current_vol_diff);
                if improved_swap.improved
                    y_current = improved_swap.y_new;
                    current_vol_diff = improved_swap.new_vol_diff;
                    improved = true;
                    
                    if current_vol_diff < best_volume_diff
                        best_solution = y_current;
                        best_volume_diff = current_vol_diff;
                    end
                end
            catch ME
                fprintf('执行智能交换时出错: %s\n', ME.message);
            end
        end
        
        % 3. 尝试商品转移操作
        if enable_shift
            try
                improved_shift = perform_smart_shift(y_current, z_current, items, data, params, current_vol_diff);
                if improved_shift.improved
                    y_current = improved_shift.y_new;
                    current_vol_diff = improved_shift.new_vol_diff;
                    improved = true;
                    
                    if current_vol_diff < best_volume_diff
                        best_solution = y_current;
                        best_volume_diff = current_vol_diff;
                    end
                end
            catch ME
                fprintf('执行智能转移时出错: %s\n', ME.message);
            end
        end
        
        % 4. 尝试易碎品重分配操作
        if params.subgroup.enable_fragile_rebalance
            try
                improved_rebalance = rebalance_fragile_items(y_current, z_current, items, data, params, current_vol_diff);
                if improved_rebalance.improved
                    y_current = improved_rebalance.y_new;
                    current_vol_diff = improved_rebalance.new_vol_diff;
                    improved = true;
                    
                    if current_vol_diff < best_volume_diff
                        best_solution = y_current;
                        best_volume_diff = current_vol_diff;
                    end
                end
            catch ME
                fprintf('执行易碎品重分配时出错: %s\n', ME.message);
            end
        end
        
        % 更新最佳解和无改进计数
        if improved
            best_solution = y_current;
            best_volume_diff = current_vol_diff;
            no_improve_count = 0;
            fprintf('✅ 迭代 %d: 找到改进解，体积差: %.4f\n', iter, best_volume_diff);
        else
            no_improve_count = no_improve_count + 1;
            fprintf('❌ 迭代 %d: 无改进，计数增加至 %d\n', iter, no_improve_count);
        end
        
        % 计算迭代时间
        iter_time = etime(datevec(now), datevec(iter_start_time));
        fprintf('迭代 %d 耗时: %.2f 秒\n', iter, iter_time);
        
        % 早期终止条件
        if no_improve_count >= no_improve_limit
            fprintf('Early termination at generation %d: no improvement for %d generations\n', ...
                    iter, no_improve_limit);
            break;
        end
        
        % 安全检查：如果单次迭代时间过长，提前结束
        if iter_time > 5 % 超过5秒视为异常
            fprintf('警告：迭代 %d 耗时过长 (%.2f 秒)，提前结束\n', iter, iter_time);
            break;
        end
    end
    
    y_best = best_solution;
    z_best = z_current;
end

% 辅助函数 - 使用正确的字段&&名 fragile_level
function fragile_items = get_fragile_items(items, data)
% 获取3级易碎品的索引
    fragile_items = [];
    
    % 安全检查：确保items和data有效
    if isempty(items) | ~isfield(data, 'fragile_level')
        return;
    end
    
    for i = 1:length(items)
        item_idx = items(i);
        if item_idx < 1 ||item_idx > length(data)
            %fprintf('警告：无效商品索引 %d，跳过\n', item_idx);
            continue;
        end
        if isfield(data(item_idx), 'fragile_level') & data(item_idx).fragile_level == 3
            fragile_items = [fragile_items, i];
        end
    end
end

function is_fragile = is_item_fragile(item_idx, data)
% 判断商品是否为3级易碎品
    is_fragile = false;
    
    % 安全检查
    if item_idx < 1 || item_idx > length(data) || ~isfield(data, 'fragile_level')
        return;
    end
    
    if isfield(data(item_idx), 'fragile_level')
        is_fragile = (data(item_idx).fragile_level == 3);
    end
end

function y_new = repair_fragile_constraints(y_current, z_current, items, data, params)
% 修复易碎品约束违反
    y_new = y_current;
    
    % 安全检查
    if isempty(items) | isempty(y_new)
        return;
    end
    
    % 确保y_new的行数与items的长度匹配
    if size(y_new, 1) ~= length(items)
        fprintf('警告：y_new的行数(%d)与items的长度(%d)不匹配\n', size(y_new, 1), length(items));
        return;
    end
    
    for group_idx = 1:size(y_new, 2)
        % 安全地获取小组商品
        valid_indices = find(y_new(:, group_idx));
        valid_indices = valid_indices(valid_indices <= length(items));
        
        if isempty(valid_indices)
            continue;
        end
        
        group_items = items(valid_indices);
        fragile_ratio = compute_fragile_ratio(group_items, data);
        
        if fragile_ratio > params.subgroup.fragile_volume_ratio_limit + 1e-6
            y_new = repair_violating_fragile_group(y_new, group_idx, items, data, params);
        end
    end
end

function result = perform_smart_swap(y_current, z_current, items, data, params, current_vol_diff)
% 智能交换操作
    % 初始化返回结构
    result = struct('improved', false, 'y_new', y_current, 'new_vol_diff', current_vol_diff);
    
    % 安全检查
    try
        % 基本参数检查
        if isempty(items) | isempty(y_current)
            return;
        end
        
        % 确保y_current的行数与items的长度匹配
        if size(y_current, 1) ~= length(items)
            fprintf('警告：y_current的行数(%d)与items的长度(%d)不匹配\n', size(y_current, 1), length(items));
            return;
        end
        
        % 使用正确的字段名获取易碎品（确保结果是标量）
        fragile_items = get_fragile_items(items, data);
        non_fragile_items = setdiff(1:length(items), fragile_items);
        
        % 优先考虑易碎品的交换
        for i = 1:length(fragile_items)
            for j = 1:length(non_fragile_items)
                idx_i = fragile_items(i);
                idx_j = non_fragile_items(j);
                
                % 确保索引有效
                if idx_i < 1 || idx_i > size(y_current, 1) || idx_j < 1 || idx_j > size(y_current, 1)
                    continue;
                end
                
                % 安全地获取当前所在小组
                group_i = find(y_current(idx_i,:));
                group_j = find(y_current(idx_j,:));
                
                % 确保获取到的是标量值
                if isempty(group_i) | isempty(group_j) | any(group_i ~= group_j)
                    % 只有在不同小组时才进行交换
                    y_neighbor = y_current;
                    y_neighbor(idx_i,:) = y_current(idx_j,:);
                    y_neighbor(idx_j,:) = y_current(idx_i,:);
                    
                    % 验证分配（确保validate_assignment返回标量）
                    valid = false;
                    try
                        valid = validate_assignment(y_neighbor, z_current, items, data, params);
                        % 确保valid是标量
                        if isscalar(valid) && valid
                                % 计算体积差异
                                neighbor_vol_diff = compute_volume_difference(y_neighbor, items, data);
                                 
                                % 确保比较是标量
                                if isscalar(neighbor_vol_diff) && neighbor_vol_diff < current_vol_diff
                                result.improved = true;
                                result.y_new = y_neighbor;
                                result.new_vol_diff = neighbor_vol_diff;
                                return;
                                end
                        end
                    catch ME
                        fprintf('验证分配时出错: %s\n', ME.message);
                    end
                end
            end
        end
        
        % 普通交换
        for i = 1:length(items)-1
            for j = i+1:length(items)
                % 确保索引有效
                if i > size(y_current, 1) || j > size(y_current, 1)
                    continue;
                end
                
                % 安全地获取当前所在小组
                group_i = find(y_current(i,:));
                group_j = find(y_current(j,:));
                
                % 确保获取到的是标量值
                if isempty(group_i) | isempty(group_j) | any(group_i ~= group_j)
                    % 只有在不同小组时才进行交换
                    y_neighbor = y_current;
                    y_neighbor(i,:) = y_current(j,:);
                    y_neighbor(j,:) = y_current(i,:);
                    
                    % 验证分配（确保validate_assignment返回标量）
                    valid = false;
                    try
                        valid = validate_assignment(y_neighbor, z_current, items, data, params);
                        % 确保valid是标量
                        if isscalar(valid) && valid
                                    % 计算体积差异
                                    neighbor_vol_diff = compute_volume_difference(y_neighbor, items, data);
                                     
                                    % 确保比较是标量
                                    if isscalar(neighbor_vol_diff) && neighbor_vol_diff < current_vol_diff
                                result.improved = true;
                                result.y_new = y_neighbor;
                                result.new_vol_diff = neighbor_vol_diff;
                                return;
                                    end
                        end
                    catch ME
                        fprintf('验证分配时出错: %s\n', ME.message);
                     end
                end
            end
        end
    catch ME
        fprintf('执行智能交换时出错: %s\n', ME.message);
        % 出错时返回初始状态
        result.improved = false;
        result.y_new = y_current;
        result.new_vol_diff = current_vol_diff;
    end
end

function result = perform_smart_shift(y_current, z_current, items, data, params, current_vol_diff)
% 智能转移操作
    % 初始化返回结构
    result = struct('improved', false, 'y_new', y_current, 'new_vol_diff', current_vol_diff);
    
    try
        % 安全检查
        if isempty(items) |isempty(y_current)
            return;
        end
        
        % 确保y_current的行数与items的长度匹配
        if size(y_current, 1) ~= length(items)
            fprintf('警告：y_current的行数(%d)与items的长度(%d)不匹配\n', size(y_current, 1), length(items));
            return;
        end
        
        n_groups = size(y_current, 2);
        
        % 使用正确的字段名获取易碎品（确保结果是标量）
        fragile_items = get_fragile_items(items, data);
        
        % 首先处理易碎品的转移
        for i = 1:length(fragile_items)
            idx = fragile_items(i);
            
            % 确保索引有效
            if idx < 1 || idx > size(y_current, 1)
                continue;
            end
            
            % 安全地获取当前所在小组（确保是标量）
            current_group = find(y_current(idx,:));
            if isempty(current_group) | length(current_group) > 1
                continue;
            end
            current_group = current_group(1); % 确保是标量
            
            for k = 1:n_groups
                if k ~= current_group
                    % 安全地获取目标小组商品
                    valid_target_indices = find(y_current(:, k));
                    valid_target_indices = valid_target_indices(valid_target_indices <= length(items));
                    target_group_items = items(valid_target_indices);
                    
                    % 检查目标小组是否能接受易碎品（确保返回标量）
                    can_accept = false;
                    try
                        can_accept = can_accept_fragile(target_group_items, data, params);
                        if isscalar(can_accept) && can_accept
                            % 执行转移
                            y_neighbor = y_current;
                            y_neighbor(idx, :) = false;
                            y_neighbor(idx, k) = true;
                            
                            % 验证分配（确保返回标量）
                            valid = false;
                            try
                                valid = validate_assignment(y_neighbor, z_current, items, data, params);
                                if isscalar(valid) && valid
                                    % 检查小组大小约束
                                    group_sizes = sum(y_neighbor, 1);
                                    if all(group_sizes >= 1)
                                        % 计算体积差异（确保是标量）
                                        neighbor_vol_diff = compute_volume_difference(y_neighbor, items, data);
                                        if isscalar(neighbor_vol_diff) && neighbor_vol_diff < current_vol_diff
                                            result.improved = true;
                                            result.y_new = y_neighbor;
                                            result.new_vol_diff = neighbor_vol_diff;
                                            return;
                                        end
                                    end
                                end
                            catch ME
                                fprintf('验证分配时出错: %s\n', ME.message);
                            end
                        end
                    catch ME
                        fprintf('检查是否接受易碎品时出错: %s\n', ME.message);
                    end
                end
            end
        end
        
        % 普通商品转移
        for i = 1:length(items)
            % 确保索引有效
            if i > size(y_current, 1)
                continue;
            end
            
            % 安全地获取当前所在小组（确保是标量）
            current_group = find(y_current(i,:));
            if isempty(current_group) | length(current_group) > 1
                continue;
            end
            current_group = current_group(1); % 确保是标量
            
            for k = 1:n_groups
                if k ~= current_group
                    % 执行转移
                    y_neighbor = y_current;
                    y_neighbor(i, :) = false;
                    y_neighbor(i, k) = true;
                    
                    % 验证分配（确保返回标量）
                    valid = false;
                    try
                        valid = validate_assignment(y_neighbor, z_current, items, data, params);
                        if isscalar(valid) && valid
                            % 检查小组大小约束
                            group_sizes = sum(y_neighbor, 1);
                            if all(group_sizes >= 1)
                                % 计算体积差异（确保是标量）
                                neighbor_vol_diff = compute_volume_difference(y_neighbor, items, data);
                                if isscalar(neighbor_vol_diff) && neighbor_vol_diff < current_vol_diff
                                    result.improved = true;
                                    result.y_new = y_neighbor;
                                    result.new_vol_diff = neighbor_vol_diff;
                                    return;
                                end
                            end
                        end
                    catch ME
                        fprintf('验证分配时出错: %s\n', ME.message);
                    end
                end
            end
        end
    catch ME
        fprintf('执行智能转移时出错: %s\n', ME.message);
        % 出错时返回初始状态
        result.improved = false;
        result.y_new = y_current;
        result.new_vol_diff = current_vol_diff;
    end
end

function result = rebalance_fragile_items(y_current, z_current, items, data, params, current_vol_diff)
% 重新平衡易碎品分布
    result.improved = false;
    result.y_new = y_current;
    result.new_vol_diff = current_vol_diff;
    
    % 安全检查
    if isempty(items) | isempty(y_current)
        return;
    end
    
    % 确保y_current的行数与items的长度匹配
    if size(y_current, 1) ~= length(items)
        fprintf('警告：y_current的行数(%d)与items的长度(%d)不匹配\n', size(y_current, 1), length(items));
        return;
    end
    
    % 找出易碎品比例过高和过低的小组
    fragile_ratios = zeros(1, size(y_current, 2));
    for group_idx = 1:size(y_current, 2)
        % 安全地获取小组商品
        valid_indices = find(y_current(:, group_idx));
        if isempty(valid_indices)
            fragile_ratios(group_idx) = 0;
            continue;
        end
        
        % 确保valid_indices在items的有效范围内
        valid_indices = valid_indices(valid_indices <= length(items));
        if isempty(valid_indices)
            fragile_ratios(group_idx) = 0;
            continue;
        end
        
        group_items = items(valid_indices);
        fragile_ratios(group_idx) = compute_fragile_ratio(group_items, data);
    end
    
    [~, high_fragile_groups] = find(fragile_ratios > params.subgroup.fragile_volume_ratio_limit);
    [~, low_fragile_groups] = find(fragile_ratios < params.subgroup.fragile_volume_ratio_limit * 0.5);
    
    if isempty(high_fragile_groups) | isempty(low_fragile_groups)
        return;
    end
    
    % 尝试从高比例组转移易碎品到低比例组
    for high_group = high_fragile_groups
        % 安全地获取高比例组的商品
        valid_high_indices = find(y_current(:, high_group));
        valid_high_indices = valid_high_indices(valid_high_indices <= length(items));
        if isempty(valid_high_indices)
            continue;
        end
        
        high_group_items = items(valid_high_indices);
        
        % 安全地找出高比例组中的易碎品
        high_fragile_items = [];
        for i = 1:length(high_group_items)
            item_idx = high_group_items(i);
            % 确保所有条件都是标量逻辑值，使用短路逻辑运算符
            if item_idx >= 1 && item_idx <= length(data) && isfield(data(item_idx), 'fragile_level') && data(item_idx).fragile_level == 3
                high_fragile_items = [high_fragile_items, item_idx];
            end
        end
        
        for low_group = low_fragile_groups
            for fragile_idx = 1:length(high_fragile_items)
                % 安全地查找商品在items中的位置
                item_pos = find(items == high_fragile_items(fragile_idx), 1);
                
                % 确保item_pos有效
                if isempty(item_pos) | item_pos > size(y_current, 1)
                    continue;
                end
                
                y_neighbor = y_current;
                y_neighbor(item_pos, :) = false;
                y_neighbor(item_pos, low_group) = true;
                
                valid = false;
                try
                    valid = validate_assignment(y_neighbor, z_current, items, data, params);
                    % 确保valid是标量，然后使用短路逻辑运算符
                    if isscalar(valid) && valid
                        neighbor_vol_diff = compute_volume_difference(y_neighbor, items, data);
                          
                        % 确保neighbor_vol_diff是标量，然后使用短路逻辑运算符
                        if isscalar(neighbor_vol_diff) && neighbor_vol_diff <= current_vol_diff
                            result.improved = true;
                            result.y_new = y_neighbor;
                            result.new_vol_diff = neighbor_vol_diff;
                            return;
                        end
                    end
                catch ME
                    fprintf('验证分配时出错: %s\n', ME.message);
                end
            end
        end
    end
end

function can_accept = can_accept_fragile(group_items, data, params)
% 检查小组是否能接受更多易碎品
    can_accept = false;
    
    % 安全检查
    if isempty(group_items) | ~isfield(params.subgroup, 'fragile_volume_ratio_limit')
        can_accept = true;
        return;
    end
    
    current_ratio = 0;
    try
        current_ratio = compute_fragile_ratio(group_items, data);
    catch ME
        fprintf('计算易碎品比例时出错: %s\n', ME.message);
        can_accept = true;  % 出错时保守处理，允许添加
        return;
    end
    
    can_accept = current_ratio < params.subgroup.fragile_volume_ratio_limit * 0.8;
end

function y_new = repair_violating_fragile_group(y_current, violating_group, items, data, params)
% 修复违反易碎品约束的小组
% 注意：这里的items是当前大组中剩余的商品索引，不是全局索引
    
    y_new = y_current;
    
    % 安全检查
    if isempty(items) | isempty(y_new) | violating_group < 1 || violating_group > size(y_new, 2)
        return;
    end
    
    % 确保y_new的行数与items的长度匹配
    if size(y_new, 1) ~= length(items)
        fprintf('警告：y_new的行数(%d)与items的长度(%d)不匹配\n', size(y_new, 1), length(items));
        return;
    end
    
    % 检查y_new的列数（小组数量）
    n_subs = size(y_new, 2);
    if n_subs <= 1
        % 如果只有1个小组，无法进行转移，直接返回
        return;
    end
    
    % 安全地获取小组商品
    valid_group_indices = find(y_new(:, violating_group));
    valid_group_indices = valid_group_indices(valid_group_indices <= length(items));
    if isempty(valid_group_indices)
        return;
    end
    group_items = items(valid_group_indices);
    
    % 安全地找出该小组中的易碎品
    fragile_in_group = [];
    for i = 1:length(group_items)
        item_idx = group_items(i);  % 这是全局商品索引
        % 确保所有条件都是标量逻辑值
        if item_idx >= 1 && item_idx <= length(data) && isfield(data(item_idx), 'fragile_level') && data(item_idx).fragile_level == 3
            fragile_in_group = [fragile_in_group, item_idx];
        end
    end
    
    % 如果没有易碎品，直接返回
    if isempty(fragile_in_group)
        return;
    end
    
    % 限制尝试次数以避免死循环
    max_attempts = min(length(fragile_in_group) * 2, 20);
    attempt_count = 0;
    
    % 尝试将易碎品转移到其他小组
    for i = 1:length(fragile_in_group)
        if attempt_count >= max_attempts
            fprintf('警告：易碎品转移尝试次数过多，提前返回\n');
            break;
        end
        
        fragile_item = fragile_in_group(i);  % 全局商品索引
        
        % 找到这个商品在当前items列表中的位置
        item_pos = find(items == fragile_item, 1);
        
        % 如果找不到（商品已被丢弃）或位置无效，跳过
        if isempty(item_pos) | item_pos < 1 || item_pos > size(y_new, 1)
            continue;
        end
        
        for target_group = 1:size(y_new, 2)
            attempt_count = attempt_count + 1;
            if attempt_count >= max_attempts
                break;
            end
            
            if target_group == violating_group
                continue;
            end
            
            % 安全地获取目标小组商品
            valid_target_indices = find(y_new(:, target_group));
            valid_target_indices = valid_target_indices(valid_target_indices <= length(items));
            target_items = items(valid_target_indices);
            
            if can_accept_fragile(target_items, data, params)
                % 执行转移
                y_new(item_pos, :) = false;
                y_new(item_pos, target_group) = true;
                
                % 检查转移后是否还违反约束（添加异常处理）
                new_valid_indices = find(y_new(:, violating_group));
                new_valid_indices = new_valid_indices(new_valid_indices <= length(items));
                current_group_items = items(new_valid_indices);
                
                constraint_satisfied = false;
                try
                    new_fragile_ratio = compute_fragile_ratio(current_group_items, data);
                    % 确保比例是有效的数值
                    if isnumeric(new_fragile_ratio) && isscalar(new_fragile_ratio) && ~isnan(new_fragile_ratio) && ~isinf(new_fragile_ratio)
                        constraint_satisfied = (new_fragile_ratio <= params.subgroup.fragile_volume_ratio_limit);
                    end
                catch ME
                    fprintf('计算易碎品比例时出错: %s\n', ME.message);
                end
                
                if constraint_satisfied
                    break;
                end
            end
        end
    end
end