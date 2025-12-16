function [solution, params] = problem3_stage1(params)
% PROBLEM3_STAGE1 问题三第一阶段求解
%   功能：执行问题三第一阶段求解（不包含新增商品）
%   
%   输入参数：
%   - params: 参数结构体，包含求解所需的各种参数
%   
%   输出参数：
%   - solution: 求解结果结构体
%   - params: 更新后的参数结构体

    % 初始化解决方案结构体
    solution = struct();
    solution.stage = 1;
    solution.timestamp = datestr(now);
    solution.name = 'Problem3_Stage1';
    
    % 如果未提供参数，使用默认参数
    if nargin < 1 || isempty(params)
        params = struct();
        params.verbose = true;
        params.G = 6;
        params.K = 18;
        params.target_per_group = 12;
        params.target_per_sub = 4;
        params.package_strategy = struct('problem_type', 3, 'enable_pairing', true);
    end
    
    % 确保verbose字段存在
    if ~isfield(params, 'verbose')
        params.verbose = true;
    end
    
    % 输出开始信息
    if params.verbose
        fprintf('\n------------------------------\n');
        fprintf('问题三第一阶段求解开始\n');
        fprintf('------------------------------\n');
        fprintf('打包策略: 问题三模式（易碎品配对）\n');
        fprintf('大组数量: %d\n', params.G);
        fprintf('小组数量: %d\n', params.K);
        fprintf('------------------------------\n\n');
    end
    
    try
        % 1. 加载数据
        if params.verbose
            fprintf('加载数据...\n');
        end
        data = load_problem3_data();
        
        % 2. 创建包（使用易碎品配对策略）
        if params.verbose
            fprintf('创建商品包（易碎品配对）...\n');
        end
        % 修复参数顺序：data, params, problem_type
        packages = create_packages(data, params, 3);  % 显式指定问题3类型
        
        % 3. 初始化解决方案
        if params.verbose
            fprintf('初始化解决方案...\n');
        end
        solution = initialize_solution_stage1(data, packages, params);
        
        % 4. 执行求解算法（此处为框架，需根据具体算法实现）
        if params.verbose
            fprintf('执行求解算法...\n');
        end
        solution = run_solver_algorithm_stage1(solution, data, packages, params);
        
        % 5. 验证结果
        if params.verbose
            fprintf('验证求解结果...\n');
        end
        [is_valid, validation_info] = validate_solution(solution, data, params);
        solution.is_valid = is_valid;
        solution.validation_info = validation_info;
        
        % 6. 记录参数
        solution.params = params;
        
        % 7. 更新状态
        solution.status = 'completed';
        solution.completion_time = datestr(now);
        
        % 输出完成信息
        if params.verbose
            fprintf('\n------------------------------\n');
            if is_valid
                status_text = '有效';
            else
                status_text = '无效';
            end
            fprintf('验证状态: %s\n', status_text);
            fprintf('------------------------------\n');
        end
        
    catch ME
        % 错误处理
        solution.status = 'error';
        solution.error_message = ME.message;
        solution.error_stack = ME.stack;
        
        if params.verbose
            fprintf('\n错误: %s\n', ME.message);
            fprintf('堆栈: %s\n', getReport(ME, 'extended'));
        end
        
    end
end

% 添加缺失的 create_packages 函数
function packages = create_packages(data, params, problem_type)
% 创建商品包 - 简化版本
    packages = struct();
    packages.list = {};
    
    % 根据问题类型采用不同的打包策略
    switch problem_type
        case 3
            % 问题三：易碎品配对策略
            packages = create_fragile_pairing_packages(data, params);
        otherwise
            % 默认策略：每个商品单独成包
            for i = 1:data.N
                package = struct();
                package.index = i;
                package.items = i;
                package.volume = data.volumes(i);
                package.weight = data.weights(i);
                package.material = data.material(i);
                package.fragile_level = data.fragile_level(i);
                package.time_requirement = data.time_requirement(i);
                package.customs_type = data.customs_type{i};
                packages.list{end+1} = package;
            end
    end
end

function packages = create_fragile_pairing_packages(data, params)
% 易碎品配对打包策略
    packages = struct();
    packages.list = {};
    
    % 分离易碎品和非易碎品
    fragile_indices = find(data.fragile_level >= 2);  % 2-3级为易碎品
    non_fragile_indices = find(data.fragile_level == 1);
    
    % 易碎品配对（两个易碎品一包）
    for i = 1:2:length(fragile_indices)
        if i+1 <= length(fragile_indices)
            % 配对两个易碎品
            package = create_combined_package(data, [fragile_indices(i), fragile_indices(i+1)]);
            packages.list{end+1} = package;
        else
            % 单个易碎品单独成包
            package = create_single_package(data, fragile_indices(i));
            packages.list{end+1} = package;
        end
    end
    
    % 非易碎品单独成包
    for i = 1:length(non_fragile_indices)
        package = create_single_package(data, non_fragile_indices(i));
        packages.list{end+1} = package;
    end
end

function package = create_single_package(data, item_index)
% 创建单个商品包
    package = struct();
    package.index = item_index;
    package.items = item_index;
    package.volume = data.volumes(item_index);
    package.weight = data.weights(item_index);
    package.material = data.material(item_index);
    package.fragile_level = data.fragile_level(item_index);
    package.time_requirement = data.time_requirement(item_index);
    package.customs_type = data.customs_type{item_index};
end

function package = create_combined_package(data, item_indices)
% 创建组合商品包
    package = struct();
    package.index = min(item_indices);  % 使用最小索引作为包标识
    package.items = item_indices;
    package.volume = sum(data.volumes(item_indices));
    package.weight = sum(data.weights(item_indices));
    package.material = mode(data.material(item_indices));  % 使用众数作为材质
    package.fragile_level = max(data.fragile_level(item_indices));  % 使用最高易碎等级
    package.time_requirement = mode(data.time_requirement(item_indices));  % 使用众数作为时间要求
    package.customs_type = data.customs_type{item_indices(1)};  % 使用第一个商品的报关类别
end

% 实现缺失的 load_problem3_data 函数
function data = load_problem3_data()
% 加载问题三数据
    try
        % 定义数据文件路径
        data_path = 'd:\\MATLAB\\projects\\海外仓多约束规划_problem1\\data\\raw\\附件1：商品属性数据.xlsx';
        
        % 检查文件是否存在
        if ~exist(data_path, 'file')
            error('数据文件不存在: %s', data_path);
        end
        
        % 读取Excel数据（A2:G81范围）
        [~, ~, raw_data] = xlsread(data_path, 'A2:G81');
        
        % 初始化数据结构
        data = struct();
        data.N = size(raw_data, 1);  % 商品数量
        
        % 提取数据
        data.weights = cell2mat(raw_data(:, 2));  % 重量 (kg)
        data.volumes = cell2mat(raw_data(:, 3));   % 体积 (dm³)
        data.material = cell2mat(raw_data(:, 4));  % 材质 (1, 2, 3)
        data.fragile_level = cell2mat(raw_data(:, 5));  % 易碎等级 (确保1-3级)
        
        % 过滤易碎等级，确保只有1-3级
        invalid_fragile = data.fragile_level < 1 | data.fragile_level > 3;
        if any(invalid_fragile)
            warning('检测到无效的易碎等级，已过滤为有效值');
            data.fragile_level(invalid_fragile) = 1;  % 将无效值设为1级
        end
        
        % 处理时效需求（T1->1, T2->2）
        time_req_cell = raw_data(:, 6);
        data.time_requirement = zeros(data.N, 1);
        for i = 1:data.N
            if ischar(time_req_cell{i}) || isstring(time_req_cell{i})
                time_str = lower(char(time_req_cell{i}));
                if contains(time_str, 't1')
                    data.time_requirement(i) = 1;
                elseif contains(time_str, 't2')
                    data.time_requirement(i) = 2;
                else
                    data.time_requirement(i) = 2;  % 默认T2
                end
            else
                data.time_requirement(i) = 2;  % 默认T2
            end
        end
        
        % 处理报关类别
        data.customs_type = raw_data(:, 7);  % 保留原始报关类别 (A, B, C)
        
        fprintf('成功加载 %d 个商品的实际数据\n', data.N);
        
    catch ME
        error('load_problem3_data: LoadFailed', '数据加载失败: %s', ME.message);
    end
end