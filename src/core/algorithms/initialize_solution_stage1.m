function solution = initialize_solution_stage1(data, packages, params)
% INITIALIZE_SOLUTION_STAGE1 初始化问题三第一阶段的解决方案
%   功能：根据提供的数据和打包结果，初始化解决方案结构体
%   输入：
%       data - 商品数据结构体
%       packages - 商品包结构体
%       params - 参数结构体
%   输出：
%       solution - 初始化后的解决方案结构体

    % 初始化解决方案结构体
    solution = struct();
    solution.stage = 1;
    solution.timestamp = datestr(now);
    solution.name = 'Problem3_Stage1';
    solution.status = 'initialized';
    
    % 初始化包分配向量 (package_assign)
    % 每个商品分配到一个包
    num_packages = length(packages);
    num_items = sum(cellfun(@length, {packages.items}));
    
    solution.package_assign = zeros(num_items, 1);
    
    % 遍历所有包，为每个商品分配包索引
    for p_idx = 1:num_packages
        pkg = packages(p_idx);
        for item_idx = 1:length(pkg.items)
            item_num = pkg.items(item_idx);
            solution.package_assign(item_num) = p_idx;
        end
    end
    
    % 初始化小组分配 (group_assign)
    % 为每个大组创建一个细胞数组，存储小组分配信息
    solution.group_assign = cell(params.G, 1);
    
    % 初始化商品到小组的分配
    solution.item_group_assign = zeros(data.N, 1);
    
    % 创建大组到小组的归属矩阵
    solution.z = zeros(params.G, params.K);
    group_size = params.group_size;
    
    % 初始化z矩阵
    for g = 1:params.G
        start_group = (g - 1) * group_size + 1;
        end_group = g * group_size;
        solution.z(g, start_group:end_group) = 1;
    end
    
    % 使用简化版的初始分配算法
    [solution.z, solution.item_group_assign] = simplified_initial_assignment(data, params.K, params.G, solution.package_assign);
    
    % 记录商品数量和大组数量
    solution.num_items = data.N;
    solution.num_groups = params.K;
    solution.num_large_groups = params.G;
    
    % 初始化评估指标
    solution.evaluation = struct();
    solution.evaluation.volume_diff = 0;
    solution.evaluation.weight_diff = 0;
    solution.evaluation.fragile_count = sum(data.fragile);
    
    % 更新状态
    solution.status = 'initialized';
    
    % 如果需要详细输出
    if isfield(params, 'verbose') && params.verbose
        fprintf('解决方案初始化完成！\n');
        fprintf('- 商品数量: %d\n', solution.num_items);
        fprintf('- 小组数量: %d\n', solution.num_groups);
        fprintf('- 大组数量: %d\n', solution.num_large_groups);
    end
end

% 内置的简化初始分配函数
function [z, item_group_assign] = simplified_initial_assignment(data, K, G, package_assign)
    % 创建大组到小组的归属矩阵 z
    z = zeros(G, K);
    
    % 每个大组包含 group_size 个小组
    group_size = K / G;
    
    % 初始化 z 矩阵
    for g = 1:G
        start_group = (g - 1) * group_size + 1;
        end_group = g * group_size;
        z(g, start_group:end_group) = 1;
    end
    
    % 初始化商品到小组的分配
    item_group_assign = zeros(data.N, 1);
    
    % 收集包信息：每个包包含哪些商品
    num_packages = max(package_assign);
    packages = cell(num_packages, 1);
    
    for item_idx = 1:data.N
        pkg_idx = package_assign(item_idx);
        if isempty(packages{pkg_idx})
            packages{pkg_idx} = item_idx;
        else
            packages{pkg_idx} = [packages{pkg_idx}; item_idx];
        end
    end
    
    % 初始化每个小组的当前总体积
    group_volumes = zeros(1, K);
    
    % 为每个包分配一个小组，然后将包内所有商品分配到该小组
    for pkg_idx = 1:num_packages
        if ~isempty(packages{pkg_idx})
            % 找到当前体积最小的小组
            [~, target_group] = min(group_volumes);
            
            % 将包内所有商品分配到该小组
            for i = 1:length(packages{pkg_idx})
                item_idx = packages{pkg_idx}(i);
                item_group_assign(item_idx) = target_group;
                group_volumes(target_group) = group_volumes(target_group) + data.volumes(item_idx);
            end
        end
    end
end