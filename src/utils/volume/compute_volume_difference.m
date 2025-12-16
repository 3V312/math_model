function vol_diff = compute_volume_difference(y, items, data)
% 计算小组间体积差 - 无状态变化的工具函数
% 输入：
%   y - 商品到小组的分配矩阵
%   items - 商品索引列表
%   data - 商品数据结构体
% 输出：
%   vol_diff - 小组间最大体积差

    sub_volumes = compute_subgroup_volumes(y, items, data);
    vol_diff = max(sub_volumes) - min(sub_volumes);
end
