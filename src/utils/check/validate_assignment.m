function is_valid = validate_assignment(y, z, items, data, params)
% 分配方案验证函数 - 检查所有约束满足情况
% 输入：
%   y - 商品到小组的分配矩阵
%   z - 大组到小组的归属矩阵
%   items - 商品索引列表
%   data - 商品数据结构体
%   params - 算法参数
% 输出：
%   is_valid - 分配方案是否有效
project_root = 'D:\MATLAB\projects\海外仓多约束规划_problem1';
addpath(fullfile(project_root, 'src', 'utils'));                 % 工具函数 
addpath(fullfile(project_root, 'src', 'core', 'algorithms', 'subgroup', 'utils', 'discard'));
addpath(fullfile(project_root, 'src', 'core', 'algorithms', 'subgroup', 'utils'));
% 工具函数子目录 - 根据实际存在的目录
addpath(fullfile(project_root, 'src', 'utils', 'for_group_ga')); % 分组GA相关工具（在之前的任务中确认存在）
addpath(fullfile(project_root, 'src', 'utils', 'fragile'));      % 易碎品相关工具（实际存在）
addpath(fullfile(project_root, 'src', 'utils', 'repair'));       % 修复相关工具（实际存在）
addpath(fullfile(project_root, 'src', 'utils', 'volume'));       % 体积相关工具（实际存在）
addpath(fullfile(project_root, 'problems'));                     % 问题定义目录
 
    
    % 检查大组商品总数是否为12 
    group_size_valid = length(items) == 12;
    
    % 检查数量约束：每个小组恰好4件商品
    sub_counts = sum(y, 1);
    count_valid = all(sub_counts == params.target_per_sub);
    
    % 检查易碎品约束：3级易碎品体积占比 <= 40%
    fragile_valid = check_fragile_constraint(y, items, data, params);
    
    % 检查材质约束：每个大组材质种类不超过2种
    material_valid = check_material_constraint(items, data, params);
    
    % 检查分配一致性
    assignment_valid = all(sum(y, 2) == 1); % 每件商品只属于一个小组
    
    % 确保所有验证结果都是标量，并使用元素级逻辑运算符
    group_size_valid = isscalar(group_size_valid) && group_size_valid;
    count_valid = isscalar(count_valid) && count_valid;
    fragile_valid = isscalar(fragile_valid) && fragile_valid;
    material_valid = isscalar(material_valid) && material_valid;
    assignment_valid = isscalar(assignment_valid) && assignment_valid;
    
    % 使用元素级逻辑运算符组合结果
    is_valid = group_size_valid & count_valid & fragile_valid & material_valid & assignment_valid;
end


