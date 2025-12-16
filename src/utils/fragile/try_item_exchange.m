function [sub_items_out, success] = try_item_exchange(sub_items, v, f, violating_group, ratios)
% 尝试在小组间交换商品以优化易碎品分布
    sub_items_out = sub_items;
    success = false;
    
    % 从违反约束的小组找易碎品
    fragile_items = sub_items{violating_group}(f(sub_items{violating_group}) == 3);
    if isempty(fragile_items)
        return;
    end
    
    % 寻找合适的交换对象
    for target_group = 1:length(sub_items)
        if target_group == violating_group
            continue;
        end
        
        % 从目标小组找非易碎品
        non_fragile_items = sub_items{target_group}(f(sub_items{target_group}) ~= 3);
        if isempty(non_fragile_items)
            continue;
        end
        
        % 尝试交换第一个商品
        frag_item = fragile_items(1);
        non_frag_item = non_fragile_items(1);
        
        % 计算交换后的新比例
        new_violating_items = sub_items{violating_group};
        new_violating_items(new_violating_items == frag_item) = non_frag_item;
        
        new_target_items = sub_items{target_group};
        new_target_items(new_target_items == non_frag_item) = frag_item;
        
        new_violating_ratio = calculate_fragile_ratio(new_violating_items, v, f);
        new_target_ratio = calculate_fragile_ratio(new_target_items, v, f);
        
        % 检查交换是否有效，使用all()确保条件是标量逻辑值
        if all(new_violating_ratio <= 0.4) && all(new_target_ratio <= 0.4)
            % 执行交换
            sub_items_out{violating_group} = new_violating_items;
            sub_items_out{target_group} = new_target_items;
            success = true;
            return;
        end
    end
end
