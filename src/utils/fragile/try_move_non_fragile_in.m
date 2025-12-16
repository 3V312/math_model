function [sub_items_out, success] = try_move_non_fragile_in(sub_items, v, f, violating_group, ratios)
% 尝试向违反约束的小组移入非易碎品以稀释易碎品比例
% 输入:
%   sub_items: 当前小组分配
%   v: 商品体积向量
%   f: 易碎品等级向量
%   violating_group: 违反约束的小组索引
%   ratios: 各小组当前易碎品比例
% 输出:
%   sub_items_out: 移动后的小组分配
%   success: 是否成功移动

    sub_items_out = sub_items;
    success = false;
    
    % 寻找有非易碎品的源小组
    for source_group = 1:length(sub_items)
        if source_group == violating_group
            continue;
        end
        
        % 从源小组找非易碎品
        source_items = sub_items{source_group};
        non_fragile_items = source_items(f(source_items) ~= 3);
        
        if isempty(non_fragile_items)
            continue;
        end
        
        % 尝试移入非易碎品
        for i = 1:length(non_fragile_items)
            non_fragile_item = non_fragile_items(i);
            
            % 计算移动后违反约束小组的新比例
            violating_items = sub_items{violating_group};
            new_violating_items = [violating_items, non_fragile_item];
            new_violating_ratio = compute_fragile_ratio_helper(new_violating_items, v, f);
            
            % 检查移动是否有效
            if new_violating_ratio <= 0.4
                % 执行移动
                sub_items_out{source_group}(source_items == non_fragile_item) = [];
                sub_items_out{violating_group}(end+1) = non_fragile_item;
                success = true;
                return;
            end
        end
    end
end
