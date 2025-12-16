function [sub_items_out, repaired] = repair_violating_group(sub_items_in, v, f, violating_group, ratios, max_attempts)
% 修复违反易碎品比例约束的小组
% 输入:
%   sub_items_in: 当前小组分配
%   v: 商品体积
%   f: 易碎品等级
%   violating_group: 违反约束的小组索引
%   ratios: 各小组当前易碎品比例
%   max_attempts: 最大尝试次数
% 输出:
%   sub_items_out: 修复后的小组分配
%   repaired: 是否成功修复

   sub_items_out = sub_items_in;
repaired = false;
attempt_count = 0;

while attempt_count < max_attempts && ~repaired
    attempt_count = attempt_count + 1;
    
    % ★★★ 关键：每次循环都重新计算当前比例 ★★★
    current_ratio = compute_current_ratio(sub_items_out{violating_group}, v, f);
    
    % 如果当前比例已经满足要求，直接返回成功
    if current_ratio <= 0.4
        repaired = true;
        break;
    end
    
    % 根据当前情况选择最佳修复策略
    if current_ratio > 0.6
        % 高比例情况：优先移出易碎品
        [sub_items_out, repaired] = try_move_fragile_out(sub_items_out, v, f, violating_group);
    elseif current_ratio > 0.4
        % 中等比例情况：尝试交换
        [sub_items_out, repaired] = try_item_exchange(sub_items_out, v, f, violating_group);
    end
    
    % 如果上述策略都失败，尝试移入非易碎品
    if ~repaired
        [sub_items_out, repaired] = try_move_non_fragile_in(sub_items_out, v, f, violating_group);
    end
    
    % ★★★ 关键：检查修复后的实际效果 ★★★
    if repaired
        new_ratio = compute_current_ratio(sub_items_out{violating_group}, v, f);
        % 如果修复后比例仍然>0.4，认为修复不成功，继续尝试
        if new_ratio > 0.4
            repaired = false;
        end
    end
end