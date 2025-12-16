% 问题三求解主入口脚本
% 功能：提供交互式和参数化的阶段选择，自动保存结果，并设置关键参数

%% 清除环境变量
clc;
clear;
close all;

%% 添加项目路径到MATLAB搜索路径
project_root = 'd:\MATLAB\projects\海外仓多约束规划_problem1';
addpath(genpath(fullfile(project_root, 'src')));
addpath(genpath(fullfile(project_root, 'problems')));

%% 参数初始化
params = struct();

% 小组数量设置 (6个大组，每组3个小组，共18个小组)
params.K = 18;
% 大组数量设置
params.G = 6;
% 每组包含的小组数
params.group_size = 3;

% 易碎品配对打包标志
params.pair_fragile = true;
% 新增商品惩罚系数
params.rho8 = 10;
% 问题类型标识
params.problem_type = 3;

% 打包策略设置
params.package_strategy = struct();
params.package_strategy.problem_type = 3;  % 问题三打包策略
params.package_strategy.verbose = false;  % 打包过程详细输出
params.package_strategy.pair_fragile = true;  % 易碎品配对打包

%% 阶段选择
% 检查是否通过命令行参数指定了阶段
    if exist('stage', 'var')
        selected_stage = stage;
        disp(['通过命令行参数选择了阶段 ', num2str(selected_stage)]);
    else
    % 交互式选择阶段
    disp('请选择求解阶段:');
    disp('1 - 阶段一（初始打包）');
    disp('2 - 阶段二（新增商品处理）');
    disp('3 - 完整求解（阶段一+阶段二）');
    
    prompt = '请输入阶段编号 (1/2/3): ';
    selected_stage = input(prompt, 's');
    selected_stage = str2double(selected_stage);
    
    % 验证输入
    while ~ismember(selected_stage, [1, 2, 3])
        disp('输入无效，请重新选择!');
        selected_stage = input(prompt, 's');
        selected_stage = str2double(selected_stage);
    end
end

%% 求解过程
switch selected_stage
    case 1
        % 仅执行阶段一
        disp('开始执行阶段一：初始打包...');
        [solution, params] = problem3_stage1(params);
        
        % 设置当前阶段
        params.current_stage = 1;
        
        % 保存阶段一结果
        save_filename = generate_save_filename('problem3', 1);
        problem3_save_solution(solution, save_filename, params);
        disp(['阶段一结果已保存至: ', save_filename]);
        
    case 2
        % 仅执行阶段二
        disp('开始执行阶段二：新增商品处理...');
        
        % 询问是否加载阶段一结果作为初始解
        prompt = '是否加载阶段一结果作为初始解? (y/n): ';
        load_initial = input(prompt, 's');
        
        if strcmpi(load_initial, 'y')
            % 寻找最新的阶段一结果
            initial_solution_file = find_latest_solution_file('problem3', 1);
            
            if ~isempty(initial_solution_file)
                disp(['加载阶段一结果: ', initial_solution_file]);
                load(initial_solution_file, 'solution', 'params');
                [solution, params] = problem3_stage2(solution, params);
            else
                error('未找到阶段一结果文件，请先执行阶段一!');
            end
        else
            % 使用默认初始解
            disp('使用默认初始解执行阶段二...');
            [solution, params] = problem3_stage2([], params);
        end
        
        % 保存阶段二结果
        save_filename = generate_save_filename('problem3', 2);
        problem3_save_solution(solution, save_filename, params);
        disp(['阶段二结果已保存至: ', save_filename]);
        
    case 3
        % 执行完整求解（阶段一+阶段二）
        disp('开始执行完整求解流程...');
        
        % 阶段一
        disp('执行阶段一：初始打包...');
        [solution_stage1, params] = problem3_stage1(params);
        
        % 保存阶段一结果
        save_filename1 = generate_save_filename('problem3', 1);
        problem3_save_solution(solution_stage1, save_filename1, params);
        disp(['阶段一结果已保存至: ', save_filename1]);
        
        % 阶段二
        disp('执行阶段二：新增商品处理...');
        [solution_stage2, params] = problem3_stage2(solution_stage1, params);
        
        % 保存阶段二结果
        save_filename2 = generate_save_filename('problem3', 2);
        problem3_save_solution(solution_stage2, save_filename2, params);
        disp(['阶段二结果已保存至: ', save_filename2]);
        
        disp('完整求解流程已完成!');
end

%% 辅助函数 - 生成保存文件名
function filename = generate_save_filename(problem, stage)
    % 检查输出目录
    output_dir = fullfile('..', '..', 'output', 'solutions');
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % 生成带编号的文件名
    base_name = sprintf('%s_stage_%d', problem, stage);
    count = 1;
    
    while exist(fullfile(output_dir, [base_name, '_', sprintf('%03d', count), '.mat']), 'file')
        count = count + 1;
    end
    
    filename = fullfile(output_dir, [base_name, '_', sprintf('%03d', count), '.mat']);
end

%% 辅助函数 - 查找最新的解决方案文件
function file_path = find_latest_solution_file(problem, stage)
    output_dir = fullfile('..', '..', 'output', 'solutions');
    pattern = sprintf('%s_stage_%d_*.mat', problem, stage);
    files = dir(fullfile(output_dir, pattern));
    
    if isempty(files)
        file_path = '';
        return;
    end
    
    % 按修改时间排序，获取最新文件
    [~, idx] = sort([files.datenum], 'descend');
    latest_file = files(idx(1));
    file_path = fullfile(output_dir, latest_file.name);
end