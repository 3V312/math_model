function result = perform_smart_swap(y_current, z_current, items, data, params, current_vol_diff)
% 智能交换操作
% 出现在：local_search_optimization.m
    % 初始化返回结构
    result = struct('improved', false, 'y_new', y_current, 'new_vol_diff', current_vol_diff);
    
    % 安全检查
    try
        % 基本参数检查
        if isempty(items) || isempty(y_current)
            return;
        end
        
        % 确保y_current的行数与items的长度匹配
        if size(y_current, 1) ~= length(items)
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
                if isempty(group_i) || isempty(group_j) || any(group_i ~= group_j)
                    % 只有在不同小组时才进行交换
                    y_neighbor = y_current;
                    y_neighbor(idx_i,:) = y_current(idx_j,:);
                    y_neighbor(idx_j,:) = y_current(idx_i,:);
                    
                    valid = false;
                    try
                        valid = validate_assignment(y_neighbor, z_current, items, data, params);
                        % 确保valid是标量，然后使用短路逻辑运算符
                        if isscalar(valid) && valid
                            neighbor_vol_diff = compute_volume_difference(y_neighbor, items, data);
                            
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
        
        % 如果没有找到易碎品相关的交换，尝试非易碎品之间的交换
        for i = 1:length(non_fragile_items)
            for j = i+1:length(non_fragile_items)
                idx_i = non_fragile_items(i);
                idx_j = non_fragile_items(j);
                
                % 确保索引有效
                if idx_i < 1 || idx_i > size(y_current, 1) || idx_j < 1 || idx_j > size(y_current, 1)
                    continue;
                end
                
                % 安全地获取当前所在小组
                group_i = find(y_current(idx_i,:));
                group_j = find(y_current(idx_j,:));
                
                % 确保获取到的是标量值
                if isempty(group_i) || isempty(group_j) || any(group_i ~= group_j)
                    % 只有在不同小组时才进行交换
                    y_neighbor = y_current;
                    y_neighbor(idx_i,:) = y_current(idx_j,:);
                    y_neighbor(idx_j,:) = y_current(idx_i,:);
                    
                    valid = false;
                    try
                        valid = validate_assignment(y_neighbor, z_current, items, data, params);
                        % 确保valid是标量，然后使用短路逻辑运算符
                        if isscalar(valid) && valid
                            neighbor_vol_diff = compute_volume_difference(y_neighbor, items, data);
                            
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