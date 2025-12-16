

function violation_scores = compute_constraint_violations(items, data, params)
% COMPUTE_CONSTRAINT_VIOLATIONS 计算每个商品在小组中的约束违反程度
% 输入: 
%   items - 商品索引列表
%   data - 数据结构体，包含商品属性
%   params - 算法参数
% 输出: 
%   violation_scores - 每个商品的约束违反分数（分数越高越应该丢弃）

    n_items = length(items);
    violation_scores = zeros(n_items, 1);
    
    % 先计算当前小组的整体约束状态
    [time_violation, material_violation, fragile_violation] = check_group_constraints(items, data, params);
    
    for i = 1:n_items
        item_idx = items(i);
        score = 0;
        
        % === 1. 时效约束违反贡献 ===
        if time_violation > 0
            item_time = data.time_requirement(item_idx);
            
            % 找出当前小组的时效分布
            all_times = data.time_requirement(items);
            unique_times = unique(all_times);
            time_counts = arrayfun(@(t) sum(all_times == t), unique_times);
            
            % 找出主流时效（数量最多的时效）
            [max_count, max_idx] = max(time_counts);
            mainstream_time = unique_times(max_idx);
            
            if item_time == mainstream_time
                % 属于主流时效，移除它会破坏一致性 → 低分（应该保留）
                score = score + 0.1;
            else
                % 属于少数时效，移除它能改善一致性 → 高分（应该丢弃）
                minority_ratio = sum(all_times == item_time) / n_items;
                score = score + (1 - minority_ratio) * 3.0;  
            end
        end
        
        % === 2. 材质约束违反贡献 ===  
        if material_violation > 0
            item_material = data.material(item_idx);
            same_material_count = sum(data.material(items) == item_material);
            
            if same_material_count == 1
                % 这是该材质的唯一商品，移除可减少材质种类 → 高分（应该丢弃）
                score = score + 2.5;
            else
                % 有同材质替代品，可以丢弃但对减少种类无帮助 → 中等分
                score = score + 0.8;
            end
        else
            % 材质未违反时，尽量保持现状
            item_material = data.material(item_idx);
            same_material_count = sum(data.material(items) == item_material);
            if same_material_count == 1
                score = score - 1.0;  
            end
        end
        
        % === 3. 易碎品约束违反贡献 ===
        if fragile_violation > 0
            item_fragile = data.fragile_level(item_idx);
            if item_fragile == 3
                % 3级易碎品超标，应该优先移除 → 高分
                fragile_volume = data.volumes(item_idx);
                total_fragile_volume = sum(data.volumes(items(data.fragile_level(items) == 3)));
                if total_fragile_volume > 0
                    volume_contribution = fragile_volume / total_fragile_volume;
                    score = score + volume_contribution * 3.0;
                else
                    score = score + 1.5;
                end
            else
                % 非3级易碎品，在违反时次优先 → 低分
                score = score + 0.3;
            end
        else
            % 易碎品未违反时，3级易碎品应该保留
            if data.fragile_level(item_idx) == 3
                score = score - 0.5;  
            end
        end
        
        violation_scores(i) = score;
    end
end