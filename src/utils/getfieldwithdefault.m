


function value = getfieldwithdefault(structure, fieldname, default)
    % GETFIELDWITHDEFAULT 获取结构体字段值，如果不存在则返回默认值
    % 输入:
    %   structure - 结构体变量
    %   fieldname - 字段名称
    %   default - 默认值
    % 输出:
    %   value - 字段值或默认值
    %注释-出现在% 文件路径: d:\VScodeprojects\overseas_warehouse_optimization\src\core\algorithms\subgroup_assign_core.m
    %出现在% filepath: d:\VScodeprojects\overseas_warehouse_optimization\src\core\algorithms\compute_association_strength.m
    %出现在% filepath: d:\VScodeprojects\overseas_warehouse_optimization\src\problems\problem2_evaluate.m

    if isfield(structure, fieldname)
        value = getfield(structure, fieldname);
    else
        value = default;
    end
end
