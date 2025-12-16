%% problem2_solver 问题二完整求解驱动脚本
% 负责环境配置、数据加载、参数设置、求解执行和结果分析

%% 1. 环境初始化
clear; clc; close all;

% 创建错误日志文件
log_file = 'error_log.txt';
fid = fopen(log_file, 'w');
try
    fprintf(fid, '开始执行求解器...\n');
    disp('开始执行求解器...');
   % 配置项目路径 
project_root = 'D:\MATLAB\projects\海外仓多约束规划_problem1';

% 重新配置的路径设置
addpath(fullfile(project_root, 'src'));                          % 主源码目录 
addpath(fullfile(project_root, 'src', 'core'));                  % 核心算法 
addpath(fullfile(project_root, 'src', 'core', 'algorithms'));    % 算法模块 
addpath(fullfile(project_root, 'src', 'core', 'algorithms', 'subgroup')); % 小组细分 
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
    %% 2. 数据加载
    data = load_data();
    fprintf('数据加载完成，共%d个商品\n', length(data.volumes));
    
   %% 3. 参数配置
params = struct();

% 分组固定参数
params.G = 6;                           % 大组数量 - 总共要分成几个大组
params.target_total = 72;               % 总商品数 - 所有商品的总数量目标
params.target_per_group = 12;           % 每大组商品数 - 每个大组应该包含的商品数量
params.target_per_sub = 4;              % 每小组商品数 - 每个小组应该包含的商品数量

% 遗传算法参数
params.ga.population_size = 80;         % 种群大小 - 每代有多少个个体（解决方案）
params.ga.generations = 700;            % 迭代代数 - 算法总共运行多少代
params.ga.crossover_rate = 0.7;         % 交叉率 - 两个父代进行交叉操作产生后代的概率
params.ga.mutation_rate = 0.2;          % 变异率 - 个体发生变异的概率
params.ga.elitism_count = 10;            % 精英保留数 - 每代中直接保留到下一代的最优个体数量

% 关联强度权重（这些权重用于计算商品之间的关联程度）
params.w_customs = 0.0;     % 报关相同权重 - 如果两个商品报关要求相同，关联强度加1.0分
params.w_material = 1.2;    % 材质相同权重 - 如果两个商品材质相同，关联强度加0.5分  
params.w_time = 1.0;        % 时效相同权重 - 如果两个商品时效要求相同，关联强度加0.3分

% 收敛控制参数（控制算法何时停止）
params.outer.max_iterations = 10;       % 最大外层迭代次数 - 整个算法最多运行10次
params.outer.stall_limit = 800;        % 停滞限制 - 如果连续1000代没有改进就停止
params.outer.tolerance = 1e-6;          % 容忍度 - 当改进小于这个数值时认为已经收敛

% 显示参数（控制输出信息）
params.display_interval = 10;           % 显示间隔 - 每10代显示一次进度信息
params.display_verbose = true;          % 详细显示 - 是否显示详细的调试信息
    
% 小组细分参数（将大组细分为小组时的控制参数）
params.subgroup.max_iterations = 100;   % 最大迭代次数 - 小组细分最多尝试100次
params.subgroup.no_improve_limit = 50;  % 无改进限制 - 如果连续20次没有改进就停止
params.subgroup.enable_swap = true;     % 启用交换 - 是否允许在小组之间交换商品
params.subgroup.enable_shift = true;    % 启用移动 - 是否允许将商品从一个小组移动到另一个小组

    %% 4. 求解执行
    fprintf('开始执行问题二求解...\n');
    tic;
    
    try
        [x_best, y_best, z_best, Q_best, history] = problem2_hybrid_solver(data, params);
        elapsed_time = toc;
        
        fprintf('求解完成，耗时 %.2f 秒\n', elapsed_time);
        
    catch ME
        fprintf('求解过程中发生错误：%s\n', ME.message);
        rethrow(ME);
    end
    
    %% 5. 结果分析
    fprintf('\n=== 问题二求解结果 ===\n');
    fprintf('最优目标值 Q = %.6f\n', Q_best);
    fprintf('总运行时间: %.2f 秒\n', elapsed_time);
    
    % 评估最终解的质量
    [Q_final, comps] = problem2_evaluate(x_best, y_best, z_best, data, params);
    
    fprintf('不可行解数量: %d\n', ~comps.feasible);
    fprintf('可行解数量: %d\n', comps.feasible);
    fprintf('大组间重量差: %.2f\n', comps.deltaW_norm );
    fprintf('小组间体积差总和: %.2f\n', sum(history.volume_differences));
    
    % 显示分组统计信息
    fprintf('\n分组统计:\n');
    for g = 1:params.G
        n_packages = sum(x_best(:, g));
        fprintf('  大组 %d: %d 个包\n', g, n_packages);
    end
    
    %% 6. 可视化输出（可选）
    if ~isempty(history.Q_values)
        figure;
        subplot(2,1,1);
        plot(history.Q_values, 'b-o');
        title('目标函数值收敛曲线');
        xlabel('迭代次数');
        ylabel('Q值');
        grid on;
        
        subplot(2,1,2);
        plot(history.feasible_counts, 'r-s');
        title('可行解数量变化');
        xlabel('迭代次数');
        ylabel('可行解数量');
        grid on;
        
        fprintf('收敛曲线已绘制\n');
    end
    
    fprintf('问题二求解全部完成！\n');
    
    % 关闭日志文件
    fclose(fid);
    
catch ME
    % 捕获错误并记录到日志
    fprintf('\n执行出错: %s\n', ME.message);
    fprintf(fid, '\n执行出错: %s\n', ME.message);
  
    
    % 关闭日志文件
    fclose(fid);
    
    % 重新抛出错误
    rethrow(ME);
end
