


function [y_best, z_best, volume_diff, dropped_items,success] = subgroup_assign(items_in_group, data, params)
% 小组细分主入口函数 - 协调整个细分流程
% 调用其他子函数完成两阶段划分
% 输入：
%   items_in_group - 该大组的商品索引列表（1×12 向量）
%   data - 商品属性数据（包含volumes, fragile_level等字段）
%   params - 算法参数
% 输出：
%   y_best - 商品到小组的分配矩阵（12×3 逻辑矩阵）
%   z_best - 大组到小组的归属矩阵（1×3 逻辑矩阵）
%   volume_diff - 小组间最大体积差
project_root = 'D:\MATLAB\projects\海外仓多约束规划_problem1';
addpath(fullfile(project_root, 'src', 'data'));                  % 数据加载 
addpath(fullfile(project_root, 'src', 'utils'));                 % 工具函数 
addpath(fullfile(project_root, 'src', 'core', 'algorithms', 'subgroup', 'utils', 'discard'));
addpath(fullfile(project_root, 'src', 'core', 'algorithms', 'subgroup', 'utils'));
% 工具函数子目录 - 根据实际存在的目录
addpath(fullfile(project_root, 'src', 'utils', 'for_group_ga')); % 分组GA相关工具（在之前的任务中确认存在）
addpath(fullfile(project_root, 'src', 'utils', 'fragile'));      % 易碎品相关工具（实际存在）
addpath(fullfile(project_root, 'src', 'utils', 'repair'));       % 修复相关工具（实际存在）
addpath(fullfile(project_root, 'src', 'utils', 'volume'));       % 体积相关工具（实际存在）
addpath(fullfile(project_root, 'problems'));                     % 问题定义目录   

% 初始化被丢弃商品列表
    dropped_items = [];
    
   
    % 检查商品数量是否超过目标值
    n_items = length(items_in_group);
    target_per_group = getfieldwithdefault(params, 'target_per_group', 12);
    
    if n_items > target_per_group
        % 计算需要丢弃的商品数量
        n_to_discard = n_items - target_per_group;
        
        % 基于约束违反的智能丢弃
        dropped_items = smart_constraint_based_discard(items_in_group, data, params, n_to_discard);
        
        % 更新商品列表，移除被丢弃的商品
        items_in_group = setdiff(items_in_group, dropped_items);
        
        fprintf(' 丢弃了 %d 件商品，剩余 %d 件商品进行分组\n', length(dropped_items), length(items_in_group));
    end

    

    % 增加重试机制，避免首次失败就退出
    fprintf('开始分组处理，当前时间: %s\n', datestr(now));
    fprintf('准备进入重试循环...\n');
    max_retries = getfieldwithdefault(params, 'max_retries', 6);
    success = false;

    for attempt = 1:max_retries
        fprintf('\n=== 第%d/%d次尝试 ===\n', attempt, max_retries);
        fprintf('当前商品列表: ');
        disp(items_in_group);
        
        % 调用贪心初始化
        fprintf('调用贪心初始化... 时间: %s\n', datestr(now));
        [y_init, z_init] = greedy_initial_assignment(items_in_group, data, params);
        fprintf('贪心初始化完成，返回y_init尺寸: %d x %d\n', size(y_init, 1), size(y_init, 2));
        
        % 调用局部搜索优化
        fprintf('调用局部搜索优化... 时间: %s\n', datestr(now));
        try
            [y_current, z_current, volume_diff] = local_search_optimization(y_init, z_init, items_in_group, data, params);
            fprintf('局部搜索优化完成，返回y_current尺寸: %d x %d\n', size(y_current, 1), size(y_current, 2));
        catch ME
            fprintf('错误: 局部搜索优化失败 - %s\n', ME.message);
            continue;
        end
    
        y_best = y_current;
        z_best = z_current;
    
        % 验证最终结果
        fprintf('验证最终结果...\n');
        if validate_assignment(y_best, z_best, items_in_group, data, params)
            fprintf('✅ 分配验证成功!\n');
            success = true;
            break;
        else
            fprintf('❌ 第%d次尝试失败，正在重试...\n', attempt);
            items_in_group = items_in_group(randperm(length(items_in_group)));
            fprintf('商品列表已随机打乱，继续下一次尝试\n');
        end
    end

    if ~success
        % 详细调试输出
        fprintf('=== 分配方案验证失败详情 ===\n');
        fprintf('输入商品数量: %d\n', length(items_in_group));
        
        % 检查y_best和z_best是否存在
        if exist('y_best', 'var') && ~isempty(y_best)
            fprintf('y_best 尺寸: %d x %d\n', size(y_best, 1), size(y_best, 2));
            fprintf('z_best 尺寸: %d x %d\n', size(z_best, 1), size(z_best, 2));
            
            % 检查各项约束
            sub_counts = sum(y_best, 1);
        else
            fprintf('警告: y_best和z_best变量未定义，所有局部搜索优化尝试均失败\n');
            return;
        end
        fprintf('各小组商品数量: ');
        disp(sub_counts);
        count_valid = all(sub_counts == params.target_per_sub);
        fprintf('数量约束满足 (%d件/组): %d\n', params.target_per_sub, count_valid);
        
        assignment_valid = all(sum(y_best, 2) == 1);
        fprintf('分配一致性(每商品1组): %d\n', assignment_valid);
        
        fragile_valid = check_fragile_constraint(y_best, items_in_group, data, params);
        fprintf('易碎品约束(≤40%%): %d\n', fragile_valid);
        
        % 如果是易碎品约束问题，显示详细信息
        if ~fragile_valid
            fprintf('=== 易碎品约束详情 ===\n');
            for k = 1:size(y_best, 2)
                sub_items = items_in_group(y_best(:, k));
                fragile_items = sub_items(data.fragile_level(sub_items) == 3);
                if ~isempty(fragile_items)
                    fragile_volume = sum(data.volumes(fragile_items));
                    total_volume = sum(data.volumes(sub_items));
                    if total_volume > 0
                        ratio = fragile_volume / total_volume;
                        fprintf('小组 %d: 易碎品占比 %.2f%% (要求≤40%%)\n', k, ratio*100);
                    end
                else
                    fprintf('小组 %d: 无3级易碎品\n', k);
                end
            end
        end
        if ~success
      
        fprintf('所有尝试均失败，请检查输入数据\n');
        end
   end