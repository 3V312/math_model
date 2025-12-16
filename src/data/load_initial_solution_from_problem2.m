function [assign, packages] = load_initial_solution_from_problem2(solution_file, params)
% load_initial_solution_from_problem2 - 从问题2的解决方案加载并转换数据
% 输入:
%   solution_file - 问题2的解决方案文件路径 (字符串)
%   params - 参数字符串或结构体
% 输出:
%   assign - 转换后的包分配向量 (P x 1)
%   packages - 转换后的包结构体，包含list和attrs字段

    % 参数解析
    if nargin < 2 || isempty(params)
        params = struct();
    elseif ischar(params) || isstring(params)
        params = struct('verbose', strcmpi(params, 'verbose'));
    end
    
    % 设置默认参数
    if ~isfield(params, 'verbose'), params.verbose = false; end
    if ~isfield(params, 'problem2_data_dir'), params.problem2_data_dir = 'd:\MATLAB\projects\海外仓多约束规划_problem1\output\solutions\problem2_solutions'; end
    
    % 如果solution_file是相对路径或文件名，尝试在问题2目录中查找
    if ~isempty(solution_file) && ~exist(solution_file, 'file')
        potential_path = fullfile(params.problem2_data_dir, solution_file);
        if exist(potential_path, 'file')
            solution_file = potential_path;
            if params.verbose
                fprintf('在问题2目录中找到文件: %s\n', solution_file);
            end
        else
            error('找不到问题2的解决方案文件: %s', solution_file);
        end
    end
    
    try
        if params.verbose
            fprintf('从问题2的解决方案加载数据: %s\n', solution_file);
        end
        
        % 加载问题2的解决方案
        mat_content = load(solution_file);
        
        % 提取必要的数据
        if isfield(mat_content, 'assign')
            assign = mat_content.assign;
        else
            error('解决方案文件中缺少分配变量');
        end
        
        if isfield(mat_content, 'packages')
            packages = mat_content.packages;
        else
            error('解决方案文件中缺少包数据');
        end
        
        % 转换和增强数据以满足问题3的需求
        [assign, packages] = convert_to_problem3_format(assign, packages, params);
        
        % 验证转换后的数据
        validate_converted_solution(assign, packages, params.verbose);
        
    catch ME
        error('从问题2加载解决方案失败: %s', ME.message);
    end
    
    if params.verbose
        fprintf('成功加载并转换问题2的解决方案，包含 %d 个包\n', length(assign));
    end
end

function [assign, packages] = convert_to_problem3_format(assign, packages, params)
% 转换数据格式以适应问题3
    % 确保包结构体具有必要的字段
    if ~isfield(packages, 'list') || ~isfield(packages, 'attrs')
        error('包结构体格式不正确，缺少必要字段');
    end
    
    P = length(packages.list);
    
    % 为问题3添加必要的属性（如果不存在）
    for i = 1:P
        % 确保有包ID
        if ~isfield(packages.attrs(i), 'pkg_id')
            packages.attrs(i).pkg_id = i;
        end
        
        % 确保易碎级别属性（默认为1 - 普通）
        if ~isfield(packages.attrs(i), 'fragile_level')
            packages.attrs(i).fragile_level = 1;
        end
        
        % 确保报关类型属性（默认为1 - A）
        if ~isfield(packages.attrs(i), 'customs_type')
            packages.attrs(i).customs_type = 1;
        elseif ischar(packages.attrs(i).customs_type) || isstring(packages.attrs(i).customs_type)
            % 转换报关类型为数值
            str_type = char(packages.attrs(i).customs_type);
            if strcmpi(str_type, 'A'), packages.attrs(i).customs_type = 1;
            elseif strcmpi(str_type, 'B'), packages.attrs(i).customs_type = 2;
            elseif strcmpi(str_type, 'C'), packages.attrs(i).customs_type = 3;
            else, packages.attrs(i).customs_type = 1; % 默认
            end
        end
        
        % 确保时效需求属性（默认为1 - 标准）
        if ~isfield(packages.attrs(i), 'timeliness')
            packages.attrs(i).timeliness = 1;
        end
    end
    
    % 确保分配向量是列向量
    if isrow(assign)
        assign = assign';
    end
    
    % 确保分配向量的长度与包数量匹配
    if length(assign) ~= P
        warning('分配向量长度 (%d) 与包数量 (%d) 不匹配，进行调整', length(assign), P);
        if length(assign) < P
            % 延长分配向量，新包分配到第一个组
            assign = [assign; ones(P - length(assign), 1)];
        else
            % 截断分配向量
            assign = assign(1:P);
        end
    end
end

function validate_converted_solution(assign, packages, verbose)
% 验证转换后的解决方案数据
    if isempty(assign)
        if verbose, warning('转换后的分配向量为空'); end
        return;
    end
    
    if ~isstruct(packages) || ~isfield(packages, 'list') || ~isfield(packages, 'attrs')
        error('转换后的包结构体格式不正确');
    end
    
    P = length(packages.list);
    
    if length(assign) ~= P
        error('转换后的分配向量长度 (%d) 与包数量 (%d) 不匹配', length(assign), P);
    end
    
    if length(packages.attrs) ~= P
        error('转换后的包属性数量 (%d) 与包列表数量 (%d) 不匹配', length(packages.attrs), P);
    end
    
    if verbose
        % 统计一些基本信息
        G = max(assign);
        fprintf('转换后的解决方案包含 %d 个包，分配到 %d 个大组\n', P, G);
    end
end