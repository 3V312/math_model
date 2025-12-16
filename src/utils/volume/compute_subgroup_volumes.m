


function sub_volumes = compute_subgroup_volumes(y, items, data)
% 计算各小组体积 
% 输入：
%   y - 商品到小组的分配矩阵
%   items - 商品索引列表
%   data - 商品数据结构体
% 输出：
%   sub_volumes - 各小组体积向量

    n_subs = size(y, 2);
    sub_volumes = zeros(1, n_subs);
    for k = 1:n_subs
        sub_items = items(y(:, k));
        sub_volumes(k) = sum(data.volumes(sub_items));
    end
end
