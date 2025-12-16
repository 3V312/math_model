function [sub_items_out, success] = try_move_fragile_out(sub_items, v, f, violating_group, ratios)
% 尝试从违反约束的小组移出易碎品到其他小组
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
    
    % 从违反约束的小组找易碎品
    violating_items = sub_items{violating_group};
    fragile_items = violating_items(f(violating_items) == 3);
    
    if isempty(fragile_items)
        return;
    end
    
    % 寻找最适合接收易碎品的目标小组
    for target_group = 1:length(sub_items)
        if target_group == violating_group
            continue;
        end
        
        % 检查目标小组是否能接收易碎品而不违反约束
        target_items = sub_items{target_group};
        for i = 1:length(fragile_items)
            fragile_item = fragile_items(i);
            
            % 计算移动后目标小组的新比例
            new_target_items = [target_items, fragile_item];
            new_target_ratio = compute_fragile_ratio_helper(new_target_items, v, f);
            
            % 检查移动是否有效
            if new_target_ratio <= 0.4
                % 执行移动
                sub_items_out{violating_group}(violating_items == fragile_item) = [];
                sub_items_out{target_group}(end+1) = fragile_item;
                success = true;
                return;
            end
        end
    end
end
