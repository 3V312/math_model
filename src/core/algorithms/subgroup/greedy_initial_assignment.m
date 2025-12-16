function [y, z] = greedy_initial_assignment(items, data, params)
% 贪心初始划分函数 - 实现轮询分配算法
% 输入：
%   items - 商品索引列表
%   data - 商品数据结构体
%   params - 算法参数
% 输出：
%   y - 初始分配矩阵
%   z - 大组到小组的归属矩阵

    n_items = length(items);
    n_subs = 3;
    
    % 按体积降序排序商品索引
    [~, sorted_idx] = sort(data.volumes(items), 'descend');
    sorted_items = items(sorted_idx);
    
    % 初始化小组体积和分配矩阵
    sub_volumes = zeros(1, n_subs);
    y = false(n_items, n_subs);
    
    % 贪心分配逻辑：遍历排序后的商品，每次分配到当前总体积最小的小组
    for i = 1:n_items
        % 找到当前体积最小的小组
        [~, min_sub] = min(sub_volumes);
        % 将商品分配给该小组
        y(i, min_sub) = true;
        % 更新小组体积
        sub_volumes(min_sub) = sub_volumes(min_sub) + data.volumes(sorted_items(i));
    end
    
    % 重新排列y矩阵以匹配原始商品顺序
    y_temp = false(n_items, n_subs);
    for i = 1:n_items
        original_pos = find(sorted_idx == i);
        y_temp(i, :) = y(original_pos, :);
    end
    y = y_temp;
    
    % 构建z矩阵（大组到小组归属）
    z = true(1, n_subs);
end
