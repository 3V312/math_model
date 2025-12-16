function problem3_save_solution(solution, filename, stage)
% problem3_save_solution 保存问题三求解结果（带自动编号功能）
% 输入:
%   solution - 解决方案结构体
%   filename - 保存路径（可选，如不提供则自动生成带编号的路径）
%   stage - 当前阶段（1或2，可选）
% 
% 功能:
%   - 兼容问题二的结果作为初始解（无新增商品矩阵）
%   - 第一阶段自动添加空的新增商品矩阵
%   - 第二阶段保存包含新增商品的完整结果
%   - 自动为解决方案编号，确保不重复

    % 确保solution是结构体
    if ~isstruct(solution)
        error('solution必须是结构体');
    end
    
    % 创建副本以避免修改原始数据
    solution_copy = solution;
    
    % 检查是否需要添加新增商品矩阵（针对第一阶段或问题二结果）
    % 处理传入params结构体的情况
    stage_value = 0;
    if nargin >= 3
        if isstruct(stage) && isfield(stage, 'current_stage')
            stage_value = stage.current_stage;
        elseif isnumeric(stage)
            stage_value = stage;
        end
    end
    
    if (stage_value == 1) || ~isfield(solution_copy, 'new_items_assign')
        % 添加空的新增商品矩阵字段
        solution_copy.new_items_assign = [];
    end
    
    % 生成或处理文件名
    if nargin < 2 || isempty(filename)
        % 设置基本路径和前缀
        base_dir = 'D:\MATLAB\projects\海外仓多约束规划_problem1\output\solutions';
        stage_suffix = '';
        if stage_value > 0
            stage_suffix = ['_stage' num2str(stage_value)];
        end
        
        % 获取下一个可用编号
        next_number = get_next_solution_number(base_dir, ['solution_problem3' stage_suffix]);
        
        % 构建完整文件名
        filename = fullfile(base_dir, ['solution_problem3' stage_suffix '_' sprintf('%03d', next_number) '.mat']);
    end
    
    % 确保目录存在
    d = fileparts(filename);
    if ~exist(d,'dir'), mkdir(d); end
    
    % 添加编号信息到solution结构体
    if ~isfield(solution_copy, 'solution_number')
        % 从文件名提取编号
        [~, name, ~] = fileparts(filename);
        number_match = regexp(name, '_([0-9]+)$', 'tokens');
        if ~isempty(number_match)
            solution_copy.solution_number = str2double(number_match{1}{1});
        else
            solution_copy.solution_number = 1; % 默认编号
        end
    end
    
    % 保存结果
    save(filename, '-struct', 'solution_copy');
    fprintf('已保存解到 %s (编号: %d)\n', filename, solution_copy.solution_number);
end

function next_number = get_next_solution_number(base_dir, prefix)
% 获取下一个可用的解决方案编号
    % 确保目录存在
    if ~exist(base_dir, 'dir'), mkdir(base_dir); end
    
    % 查找所有匹配的文件
    pattern = fullfile(base_dir, [prefix '_*.mat']);
    existing_files = dir(pattern);
    
    % 如果没有现有文件，从1开始
    if isempty(existing_files)
        next_number = 1;
        return;
    end
    
    % 提取所有现有编号
    numbers = zeros(length(existing_files), 1);
    for i = 1:length(existing_files)
        file_name = existing_files(i).name;
        number_match = regexp(file_name, [prefix '_([0-9]+)\.mat'], 'tokens');
        if ~isempty(number_match)
            numbers(i) = str2double(number_match{1}{1});
        end
    end
    
    % 找到最大编号并加1
    next_number = max(numbers) + 1;
    
    % 检查是否有缺失的编号（可选）
    % 这里可以添加逻辑来查找缺失的编号，以便重用编号
    % 例如：如果有编号1和3，但没有2，可以返回2
end