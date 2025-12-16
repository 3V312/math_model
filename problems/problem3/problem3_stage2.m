function [solution, params] = problem3_stage2(params, initial_solution)
% PROBLEM3_STAGE2 问题三第二阶段求解
%   功能：执行问题三第二阶段求解（包含新增商品）
%   
%   输入参数：
%   - params: 参数结构体，包含求解所需的各种参数
%   - initial_solution: 第一阶段的初始解决方案（可选）
%   
%   输出参数：
%   - solution: 求解结果结构体
%   - params: 更新后的参数结构体

    % 初始化解决方案结构体
    solution = struct();
    solution.stage = 2;
    solution.timestamp = datestr(now);
    solution.name = 'Problem3_Stage2';
    
    % 如果未提供参数，使用默认参数
    if nargin < 1 || isempty(params)
        params = struct();
        params.verbose = true;
        params.G = 6;
        params.K = 18;
        params.target_per_group = 12;
        params.target_per_sub = 4;
        params.package_strategy = struct('problem_type', 3, 'enable_pairing', true);
        params.rho8 = 500;  % 新增商品数量惩罚系数
        params.initial_solution_file = 'd:\\MATLAB\\projects\\海外仓多约束规划_problem1\\output\\solutions\\problem2_solutions\\analysis_report_001';
    end
    
    % 确保initial_solution_file字段存在
    if ~isfield(params, 'initial_solution_file')
        params.initial_solution_file = 'd:\\MATLAB\\projects\\海外仓多约束规划_problem1\\output\\solutions\\problem2_solutions\\analysis_report_001';
    end
    
    % 确保verbose字段存在
    if ~isfield(params, 'verbose')
        params.verbose = true;
    end
    
    % 确保rho8字段存在（新增商品数量惩罚）
    if ~isfield(params, 'rho8')
        params.rho8 = 500;
    end
    
    % 输出开始信息
    if params.verbose
        fprintf('\n------------------------------\n');
        fprintf('问题三第二阶段求解开始\n');
        fprintf('------------------------------\n');
        fprintf('打包策略: 问题三模式（易碎品配对）\n');
        fprintf('大组数量: %d\n', params.G);
        fprintf('小组数量: %d\n', params.K);
        fprintf('新增商品数量惩罚系数: %.1f\n', params.rho8);
        fprintf('------------------------------\n\n');
    end
    
    try
        % 1. 加载数据（包含新增商品）
        if params.verbose
            fprintf('加载数据（包含新增商品）...\n');
        end
        [data, new_items_data] = load_problem3_data_with_new_items();
        
        % 2. 检查并使用初始解
        if nargin < 2 || isempty(initial_solution)
            % 尝试从文件加载初始解
            try
                if params.verbose
                    fprintf('未提供初始解，尝试从文件加载: %s\n', params.initial_solution_file);
                end
                solution = load_initial_solution_from_problem2(params.initial_solution_file, data, params);
            catch ME
                % 如果从文件加载失败，使用默认初始解
                warning('从文件加载初始解失败: %s，使用默认初始解', ME.message);
                if params.verbose
                    fprintf('使用默认初始解...\n');
                end
                solution = create_default_initial_solution(data, params);
            end
        else
            if params.verbose
                fprintf('使用提供的初始解...\n');
            end
            solution = initial_solution;
        end
        
        % 3. 处理新增商品
        if params.verbose
            fprintf('处理新增商品...\n');
        end
        solution = process_new_items(solution, data, new_items_data, params);
        
        % 4. 执行求解算法（此处为框架，需根据具体算法实现）
        if params.verbose
            fprintf('执行求解算法...\n');
        end
        solution = run_solver_algorithm_stage2(solution, data, new_items_data, params);
        
        % 5. 验证结果
        if params.verbose
            fprintf('验证求解结果...\n');
        end
        [is_valid, validation_info] = validate_solution(solution, data, new_items_data, params);
        solution.is_valid = is_valid;
        solution.validation_info = validation_info;
        
        % 6. 记录参数
        solution.params = params;
        
        % 7. 确保新增商品分配字段存在
        if ~isfield(solution, 'new_items_assign')
            solution.new_items_assign = zeros(new_items_data.N, 1);
        end
        
        % 8. 更新状态
        solution.status = 'completed';
        solution.completion_time = datestr(now);
        solution.problem_type = 3;  % 标识为问题三的解决方案
        
        % 输出完成信息
        if params.verbose
            fprintf('\n------------------------------\n');
            % 使用条件赋值代替三元运算符（MATLAB不支持三元运算符）
            status_text = '无效';
            if is_valid
                status_text = '有效';
            end
            fprintf('验证状态: %s\n', status_text);
            fprintf('------------------------------\n');
        end
        
    catch ME
        % 错误处理
        solution.status = 'error';
        solution.error_message = ME.message;
        solution.error_stack = ME.stack;
        solution.problem_type = 3;  % 标识为问题三的解决方案
        
        if params.verbose
            fprintf('\n错误: %s\n', ME.message);
            fprintf('堆栈: %s\n', getReport(ME, 'extended'));
        end
        
        warning('第二阶段求解遇到错误: %s', ME.message);
    end
end

function [data, new_items_data] = load_problem3_data_with_new_items()
% 加载问题三数据（包含新增商品）
    try
        % 1. 加载原有基础数据（调用第一阶段的数据加载函数）
        if exist('load_problem3_data', 'file') == 2
            data = load_problem3_data();
        else
            error('load_problem3_data函数不存在，请先确保problem3_stage1.m已正确实现');
        end
        
        % 2. 动态确定新增商品数量（基于原有商品数量的一定比例）
        % 使用原有商品数量的20-30%作为新增商品数量
        base_percentage = 0.2;  % 基础比例
        variance_percentage = 0.1;  % 随机变化比例
        new_N = round(data.N * (base_percentage + variance_percentage * rand()));
        
        % 确保新增商品数量在合理范围内（至少5个，最多50个）
        new_N = max(5, min(50, new_N));
        
        % 3. 生成新增商品数据
        new_items_data = struct();
        new_items_data.N = new_N;
        
        % 重量范围：与原始数据一致 (15-25kg)
        % 取原始数据的实际范围或使用固定范围
        if ~isempty(data.weights)
            min_weight = min(data.weights);
            max_weight = max(data.weights);
            new_items_data.weights = min_weight + (max_weight - min_weight) * rand(new_N, 1);
        else
            % 如果原始数据为空，使用默认范围
            new_items_data.weights = 15.31 + (24.71 - 15.31) * rand(new_N, 1);
        end
        
        % 体积范围：与原始数据一致 (100-200 dm³)
        % 确保使用dm³单位，与原始数据保持一致
        if ~isempty(data.volumes)
            min_volume = min(data.volumes);
            max_volume = max(data.volumes);
            new_items_data.volumes = min_volume + (max_volume - min_volume) * rand(new_N, 1);
        else
            % 如果原始数据为空，使用默认范围
            new_items_data.volumes = 100 + 100 * rand(new_N, 1);
        end
        
        % 材质：1, 2, 3（与原始数据一致的随机分布）
        new_items_data.material = randi([1, 3], new_N, 1);
        
        % 易碎等级：确保只有1-3级
        new_items_data.fragile_level = randi([1, 3], new_N, 1);
        
        % 时效需求：随机分配T1(1)和T2(2)
        new_items_data.time_requirement = randi([1, 2], new_N, 1);
        
        % 报关类别：随机分配A, B, C
        customs_types = {'A', 'B', 'C'};
        new_items_data.customs_type = cell(new_N, 1);
        for i = 1:new_N
            new_items_data.customs_type{i} = customs_types{randi([1, 3])};
        end
        
        fprintf('成功生成 %d 个新增商品数据\n', new_N);
        
    catch ME
        error('数据加载失败: %s', ME.message);
    end
end

function solution = create_default_initial_solution(data, params)
% 创建默认初始解
    solution = struct();
    solution.stage = 1;  % 标记为第一阶段解
    solution.package_assign = zeros(params.G, 1);  % 简化的包分配
    solution.group_assign = {};  % 简化的小组分配
    solution.evaluation = struct();  % 评估结果
    
    warning('create_default_initial_solution: 待实现初始解创建逻辑');
    
    return solution;
end

function solution = process_new_items(solution, data, new_items_data, params)
% 处理新增商品
    % 初始化新增商品分配
    solution.new_items_assign = zeros(new_items_data.N, 1);  % 新增商品分配到大组
    
    % 实际实现中，应调用problem3_add_items.m中的函数
    % 这里可以根据参数rho8来控制新增商品数量最小化
    if params.verbose && params.rho8 > 0
        fprintf('启用新增商品数量最小化策略 (rho8=%.1f)\n', params.rho8);
    end
    
    warning('process_new_items: 待实现新增商品处理逻辑');
    
    return solution;
end

function solution = run_solver_algorithm_stage2(solution, data, new_items_data, params)
% 执行求解算法
    % 这里应实现实际的求解算法
    % 可以是遗传算法、局部搜索等
    
    % 设置默认算法参数
    max_iterations = getfieldwithdefault(params, 'max_iterations', 1000);
    tol = getfieldwithdefault(params, 'tol', 1e-6);
    
    % 算法框架
    for iter = 1:max_iterations
        % 实现具体的算法迭代逻辑
        % ...
        
        % 检查收敛条件
        % if convergence_criteria_met, break; end
        
        % 记录历史
        % solution.history.iteration(iter) = ...;
        
        % 进度输出
        if params.verbose && mod(iter, 100) == 0
            fprintf('迭代 %d/%d\n', iter, max_iterations);
        end
    end
    
    solution.iterations = max_iterations;
    
    % 实际实现中，应替换为完整的算法
    warning('run_solver_algorithm_stage2: 待实现求解算法');
    
    return solution;
end

function [is_valid, info] = validate_solution(solution, data, new_items_data, params)
% 验证解决方案的有效性
    is_valid = true;
    info = struct();
    
    % 检查必要字段
    required_fields = {'package_assign', 'group_assign', 'new_items_assign'};
    for field = required_fields
        if ~isfield(solution, field{1})
            is_valid = false;
            info.missing_fields{end+1} = field{1};  %#ok<AGROW>
        end
    end
    
    % 验证新增商品数量约束（如果有）
    if is_valid && isfield(solution, 'new_items_assign')
        new_items_count = sum(solution.new_items_assign > 0);
        info.selected_new_items_count = new_items_count;
        
        if params.verbose
            fprintf('已选择的新增商品数量: %d\n', new_items_count);
        end
    end
    
    % 实际实现中，应添加更多的验证逻辑
    warning('validate_solution: 待实现完整的验证逻辑');
    
    return is_valid, info;
end

function value = getfieldwithdefault(struct_obj, field_name, default_value)
% 获取结构体字段值，如果不存在则返回默认值
    if isfield(struct_obj, field_name) && ~isempty(struct_obj.(field_name))
        value = struct_obj.(field_name);
    else
        value = default_value;
    end
end

function solution = load_initial_solution_from_problem2(file_base_path, data, params)
% 从problem2的解决方案文件加载初始解
%   功能：加载.mat和.txt文件，解析问题二的解决方案，并转换为问题三可用的格式
%   
%   输入参数：
%   - file_base_path: 文件基础路径（不包含扩展名）
%   - data: 当前问题的数据
%   - params: 参数结构体
%   
%   输出参数：
%   - solution: 转换后的解决方案结构体，与problem3_save_solution.m兼容
    
    solution = struct();
    solution.stage = 1;  % 初始解来自问题二，标记为第一阶段
    solution.problem_type = 3;  % 标识为问题三的解决方案，确保与保存机制兼容
    
    % 1. 尝试加载.mat文件
    mat_file_path = [file_base_path, '.mat'];
    txt_file_path = [file_base_path, '.txt'];
    
    % 检查文件是否存在
    if ~exist(mat_file_path, 'file') && ~exist(txt_file_path, 'file')
        error('初始解文件不存在: %s.mat 或 %s.txt', file_base_path, file_base_path);
    end
    
    % 优先从.mat文件加载
    if exist(mat_file_path, 'file')
        if params.verbose
            fprintf('从.mat文件加载初始解: %s\n', mat_file_path);
        end
        
        try
            loaded_data = load(mat_file_path);
            
            % 检查必要的字段并提取数据
            if isfield(loaded_data, 'solution')
                problem2_solution = loaded_data.solution;
                
                % 提取关键信息
                if isfield(problem2_solution, 'package_assign')
                    solution.package_assign = problem2_solution.package_assign;
                end
                
                if isfield(problem2_solution, 'group_assign')
                    solution.group_assign = problem2_solution.group_assign;
                end
                
                if isfield(problem2_solution, 'evaluation')
                    solution.evaluation = problem2_solution.evaluation;
                end
                
                % 复制其他有用的字段（如果存在）
                if isfield(problem2_solution, 'timestamp')
                    solution.original_timestamp = problem2_solution.timestamp;
                end
                
                if isfield(problem2_solution, 'solution_number')
                    solution.original_solution_number = problem2_solution.solution_number;
                end
                
                % 添加原始解决方案的引用
                solution.problem2_solution = problem2_solution;
                
                if params.verbose
                    fprintf('成功从.mat文件加载初始解\n');
                end
            else
                warning('加载的.mat文件中不包含solution字段');
                
                % 如果没有solution字段，尝试直接读取变量
                for var_name = fieldnames(loaded_data)'
                    if contains(lower(var_name{1}), 'assign') || contains(lower(var_name{1}), 'group')
                        solution.(var_name{1}) = loaded_data.(var_name{1});
                    end
                end
            end
        catch ME
            warning('加载.mat文件时出错: %s，尝试从.txt文件加载', ME.message);
            % 继续尝试从.txt文件加载
        end
    end
    
    % 如果.mat文件加载失败或没有关键数据，尝试从.txt文件加载
    if ~isfield(solution, 'package_assign') || ~isfield(solution, 'group_assign')
        if exist(txt_file_path, 'file')
            if params.verbose
                fprintf('从.txt文件加载初始解: %s\n', txt_file_path);
            end
            
            try
                % 读取.txt文件内容
                fid = fopen(txt_file_path, 'r');
                if fid == -1
                    error('无法打开.txt文件: %s', txt_file_path);
                end
                
                file_content = textscan(fid, '%s', 'Delimiter', '\n');
                fclose(fid);
                
                file_content = file_content{1};
                
                % 解析文件内容，提取分组和分配信息
                % 这里需要根据实际的.txt文件格式进行调整
                solution = parse_text_solution(file_content, data, params);
                solution.problem_type = 3;  % 确保设置问题类型
                
                if params.verbose
                    fprintf('成功从.txt文件加载初始解\n');
                end
            catch ME
                error('从.txt文件加载初始解失败: %s', ME.message);
            end
        else
            error('无法加载初始解，.mat和.txt文件都不可用或格式不正确');
        end
    end
    
    % 3. 确保解决方案兼容问题三的结构和保存机制
    % 根据problem3_save_solution.m的要求，确保包含所有必要字段
    
    % 确保new_items_assign字段存在（空数组，与problem3_save_solution.m兼容）
    solution.new_items_assign = [];
    
    % 确保必要的字段存在
    if ~isfield(solution, 'timestamp')
        solution.timestamp = datestr(now);
    end
    
    if ~isfield(solution, 'name')
        solution.name = 'Problem3_Stage1_FromProblem2';
    end
    
    if ~isfield(solution, 'status')
        solution.status = 'loaded_from_problem2';
    end
    
    % 验证加载的解决方案
    if ~isfield(solution, 'package_assign') || ~isfield(solution, 'group_assign')
        error('加载的初始解缺少必要字段');
    end
    
    if params.verbose
        fprintf('初始解加载完成，准备用于问题三求解\n');
    end
    
    return solution;
end

function solution = parse_text_solution(file_content, data, params)
% 解析文本格式的解决方案文件
%   功能：从.txt文件内容中提取分组和分配信息
    
    solution = struct();
    solution.package_assign = zeros(data.N, 1);
    solution.group_assign = cell(params.G, 1);
    
    % 简单的解析逻辑示例，需要根据实际文件格式调整
    for i = 1:length(file_content)
        line = file_content{i};
        
        % 查找包含分组信息的行
        if contains(lower(line), 'group') || contains(lower(line), '组')
            % 提取组号和商品列表
            % 这里的解析逻辑需要根据实际文件格式定制
            % 示例："Group 1: [1, 3, 5, 7]"
            
            % 简化实现，实际需要更复杂的解析逻辑
            group_match = regexp(line, '组(\d+)', 'tokens');
            if ~isempty(group_match)
                group_idx = str2double(group_match{1}{1});
                if group_idx >= 1 && group_idx <= params.G
                    % 提取商品列表
                    items_match = regexp(line, '\[([^\]]+)\]', 'tokens');
                    if ~isempty(items_match)
                        items_str = items_match{1}{1};
                        items = str2double(strsplit(items_str, ', '));
                        solution.group_assign{group_idx} = items;
                        
                        % 更新package_assign
                        for item_idx = items
                            if item_idx >= 1 && item_idx <= data.N
                                solution.package_assign(item_idx) = group_idx;
                            end
                        end
                    end
                end
            end
        end
    end
    
    % 添加默认评估信息
    solution.evaluation = struct('total_cost', 0, 'group_count', params.G);
    
    return solution;
end