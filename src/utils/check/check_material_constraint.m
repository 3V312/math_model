function material_ok = check_material_constraint(items, data, params)
% 检查材质约束：每个大组材质种类不超过2种
% 输入：
%   items - 商品索引列表
%   data - 商品数据结构体
%   params - 算法参数
% 输出：
%   material_ok - 是否满足材质约束
    
    % 获取该大组所有商品的材质类型
    group_materials = data.material(items);
    
    % 计算唯一材质种类数
    unique_materials = unique(group_materials);
    
    % 检查材质种类数是否不超过2种
    material_ok = length(unique_materials) <= 2;
end