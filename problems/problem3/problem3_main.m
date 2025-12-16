function [solution, params] = problem3_main(varargin)
% PROBLEM3_MAIN 问题三求解入口
%   功能：
%   1. 允许用户选择求解阶段（1或2）
%   2. 支持通过参数设置求解阶段
%   3. 自动保存每一阶段的求解结果
%   4. 保存名称包含问题三、阶段和保存次数
%   5. 清晰的标志变量控制打包策略
% 
%   输入参数：
%   - 可选参数：通过name-value对设置
%     'Stage': 求解阶段（1或2，默认交互式选择）
%     'Verbose': 是否显示详细信息（true/false，默认true）
%     'UseDefaultParams': 是否使用默认参数（true/false，默认true）
%     'CustomParams': 自定义参数结构体（当UseDefaultParams为false时使用）
% 
%   输出参数：
%   - solution: 求解结果结构体
%   - params: 使用的参数结构体

    % 解析输入参数
    p = inputParser;
    addParameter(p, 'Stage', 0, @(x) isscalar(x) && (x == 0 || x == 1 || x == 2));
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'UseDefaultParams', true, @islogical);
    addParameter(p, 'CustomParams', struct(), @isstruct);
    parse(p, varargin{:});
    
    % 获取参数值
    stage_input = p.Results.Stage;
    verbose = p.Results.Verbose;
    use_default_params = p.Results.UseDefaultParams;
    custom_params = p.Results.CustomParams;
    
    % 如果没有指定阶段，交互式选择
    if stage_input == 0
        stage = select_solver_stage();
    else
        stage = stage_input;
    end
    
    % 初始化参数
    params = initialize_params(use_default_params, custom_params, verbose);
    
    % 设置打包策略标志
    params.package_strategy = struct();
    params.package_strategy.problem_type = 3;  % 问题三模式，启用f3与f2配对
    params.package_strategy.enable_pairing = true;  % 启用易碎品配对
    
    % 输出开始信息
    if verbose
        fprintf('\n==================================\n');
        fprintf('问题三求解器 v1.0\n');
        fprintf('==================================\n');
        fprintf('当前求解阶段: %d\n', stage);
        fprintf('打包策略: 问题三模式（易碎品配对）\n');
        fprintf('==================================\n\n');
    end
    
    % 根据阶段调用相应的求解函数
    switch stage
        case 1
            if verbose
                fprintf('开始第一阶段求解（不包含新增商品）...\n');
            end
            [solution, params] = solve_stage_1(params, verbose);
            
        case 2
            if verbose
                fprintf('开始第二阶段求解（包含新增商品）...\n');
            end
            [solution, params] = solve_stage_2(params, verbose);
            
        otherwise
            error('无效的求解阶段，必须为1或2');
    end
    
    % 保存结果
    if verbose
        fprintf('\n保存求解结果...\n');
    end
    save_solution(solution, stage, verbose);
    
    % 输出完成信息
    if verbose
        fprintf('\n==================================\n');
        fprintf('问题三阶段 %d 求解完成！\n', stage);
        fprintf('==================================\n');
    end
end

function stage = select_solver_stage()
% 交互式选择求解阶段
    fprintf('请选择问题三的求解阶段：\n');
    fprintf('1. 第一阶段（不包含新增商品）\n');
    fprintf('2. 第二阶段（包含新增商品）\n');
    
    % 输入验证
    valid_input = false;
    while ~valid_input
        stage_str = input('请输入选择 (1 或 2): ', 's');
        stage = str2double(stage_str);
        if isscalar(stage) && (stage == 1 || stage == 2)
            valid_input = true;
        else
            fprintf('无效输入，请重新输入 1 或 2\n');
        end
    end
end

function params = initialize_params(use_default, custom_params, verbose)
% 初始化参数
    if use_default
        % 使用默认参数
        params = struct();
        
        % 基本参数
        params.G = 6;  % 大组数量
        params.K = 18;  % 小组数量（3小组/大组）
        params.target_per_group = 12;  % 大组目标商品数
        params.target_per_sub = 4;     % 小组目标商品数
        
        % 惩罚系数
        params.rho1 = 100;  % 选择惩罚
        params.rho2 = 100;  % 分组惩罚
        params.rho3 = 100;  % 时效惩罚
        params.rho4 = 100;  % 易碎品惩罚
        params.rho5 = 100;  % 材质惩罚
        params.rho6 = 100;  % 小组惩罚
        params.rho7 = 300;  % 报关惩罚
        params.rho8 = 500;  % 新增商品数量惩罚（第二阶段使用）
        params.rho9 = 500;  % 易碎品缓冲约束惩罚
        
        % 权重系数
        params.lambda1 = 10;  % 重量差权重
        
        % 算法参数
        params.max_iterations = 1000;
        params.tol = 1e-6;
        
        % 其他参数
        params.verbose = verbose;
        params.random_seed = 42;
        
    else
        % 使用自定义参数
        params = custom_params;
        params.verbose = verbose;
    end
end

function [solution, params] = solve_stage_1(params, verbose)
% 第一阶段求解
    try
        % 检查stage1函数是否存在并调用
        if exist('problem3_stage1', 'file') == 2
            [solution, params] = problem3_stage1(params);
        else
            % 如果stage1函数不存在，创建基础结果
            solution = struct();
            solution.stage = 1;
            solution.timestamp = datestr(now);
            solution.params = params;
            solution.status = 'placeholder';
            
            if verbose
                fprintf('警告: problem3_stage1.m 文件不存在，创建了基础结果结构体\n');
            end
        end
        
    catch ME
        error('第一阶段求解出错: %s', ME.message);
    end
end

function [solution, params] = solve_stage_2(params, verbose)
% 第二阶段求解
    try
        % 加载第一阶段的结果作为初始解
        initial_solution = load_initial_solution(verbose);
        
        % 设置第二阶段特定参数
        params.rho8 = getfieldwithdefault(params, 'rho8', 500);  % 确保有新增商品惩罚
        
        % 检查stage2函数是否存在并调用
        if exist('problem3_stage2', 'file') == 2
            [solution, params] = problem3_stage2(params, initial_solution);
        else
            % 如果stage2函数不存在，创建基础结果
            solution = initial_solution;
            solution.stage = 2;
            solution.timestamp = datestr(now);
            solution.params = params;
            solution.status = 'placeholder';
            
            if verbose
                fprintf('警告: problem3_stage2.m 文件不存在，创建了基础结果结构体\n');
            end
        end
        
    catch ME
        error('第二阶段求解出错: %s', ME.message);
    end
end

function initial_solution = load_initial_solution(verbose)
% 加载第一阶段结果作为初始解
    % 查找最新的第一阶段结果
    base_dir = 'D:\MATLAB\projects\海外仓多约束规划_problem1\output\solutions';
    pattern = fullfile(base_dir, 'solution_problem3_stage1_*.mat');
    existing_files = dir(pattern);
    
    if isempty(existing_files)
        % 如果没有第一阶段结果，创建空的初始解
        initial_solution = struct();
        initial_solution.stage = 1;
        initial_solution.status = 'no_initial_solution';
        
        if verbose
            fprintf('警告: 未找到第一阶段结果，使用空的初始解\n');
        end
    else
        % 找到最新的文件
        [~, idx] = max([existing_files.datenum]);
        latest_file = fullfile(base_dir, existing_files(idx).name);
        
        % 加载文件
        load(latest_file, '-mat', 'solution_copy');
        initial_solution = solution_copy;
        
        if verbose
            fprintf('已加载第一阶段初始解: %s\n', existing_files(idx).name);
        end
    end
end

function save_solution(solution, stage, verbose)
% 保存求解结果
    % 确保solution是结构体
    if ~isstruct(solution)
        solution = struct('status', 'unknown', 'stage', stage);
    end
    
    % 调用保存函数
    try
        problem3_save_solution(solution, '', stage);
    catch ME
        warning('保存结果时出错: %s\n', ME.message);
        % 备用保存逻辑
        backup_save(solution, stage, verbose);
    end
end

function backup_save(solution, stage, verbose)
% 备用保存逻辑
    base_dir = 'D:\MATLAB\projects\海外仓多约束规划_problem1\output\solutions';
    if ~exist(base_dir, 'dir')
        mkdir(base_dir);
    end
    
    % 生成文件名
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    filename = fullfile(base_dir, sprintf('backup_problem3_stage%d_%s.mat', stage, timestamp));
    
    % 保存
    save(filename, '-struct', 'solution');
    
    if verbose
        fprintf('备用保存成功: %s\n', filename);
    end
end

function value = getfieldwithdefault(struct_obj, field_name, default_value)
% 获取结构体字段值，如果不存在则返回默认值
    if isfield(struct_obj, field_name) && ~isempty(struct_obj.(field_name))
        value = struct_obj.(field_name);
    else
        value = default_value;
    end
end