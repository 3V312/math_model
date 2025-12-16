


function [time_viol, material_viol, fragile_viol] = check_group_constraints(items, data, params)
% CHECK_GROUP_CONSTRAINTS 检查小组的约束违反状态
% 输入:
%   items - 商品索引列表
%   data - 数据结构体，包含商品属性
%   params - 算法参数
% 输出:
%   time_viol - 时效违反程度
%   material_viol - 材质违反程度  
%   fragile_viol - 易碎品违反程度

    time_viol = 0;
    material_viol = 0;
    fragile_viol = 0;
    
    % === 1. 时效约束检查 ===
    % 要求每个大组内所有商品的时效需求保持完全一致
    unique_times = unique(data.time_requirement(items));
    if length(unique_times) > 1
        % 时效种类数超过1种即违反约束，违反程度为超岀的种类数
        time_viol = length(unique_times) - 1;
    end
    
    % === 2. 材质约束检查 ===
    % 每个大组内商品的材质种类不得超过2种
    unique_materials = unique(data.material(items));
    if length(unique_materials) > 2
        % 材质种类超过2种即违反约束，违反程度为超出的数量
        material_viol = length(unique_materials) - 2;
    end
    
    % === 3. 易碎品约束检查 ===
    % 每个小组中3级易碎品体积占比不得超过40%
    fragile_3_items = items(data.fragile_level(items) == 3);
    if ~isempty(fragile_3_items)
        fragile_volume = sum(data.volumes(fragile_3_items));
        total_volume = sum(data.volumes(items));
        if total_volume > 0
            fragile_ratio = fragile_volume / total_volume;
            if fragile_ratio > 0.4
                % 易碎品比例超过40%即违反约束，违反程度为超出的比例
                fragile_viol = fragile_ratio - 0.4;
            end
        end
    end
end
