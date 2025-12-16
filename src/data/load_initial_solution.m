function [assign, packages] = load_initial_solution(solution_file, params)
% load_initial_solution - 加载初始解决方案
% 输入:
%   solution_file - 解决方案文件路径 (字符串) 或 直接传递的解决方案结构体
%   params - 参数字符串或结构体
% 输出:
%   assign - 包分配向量 (P x 1)
%   packages - 包结构体，包含list和attrs字段

    % 参数解析
    if nargin < 2 || isempty(params)
        params = struct();
    elseif ischar(params) || isstring(params)
        params = struct('verbose', strcmpi(params, 'verbose'));
    end
    
    % 设置默认参数
    if ~isfield(params, 'verbose'), params.verbose = false; end
    if ~isfield(params, 'assign_var_name'), params.assign_var_name = 'assign'; end
    if ~isfield(params, 'packages_var_name'), params.packages_var_name = 'packages'; end
    
    % 初始化返回值
    assign = [];
    packages = struct();
    
    try
        if isstruct(solution_file)
            % 直接处理结构体输入
            if params.verbose
                fprintf('从结构体加载解决方案...\n');
            end
            
            % 检查结构体字段
            if isfield(solution_file, params.assign_var_name)
                assign = solution_file.(params.assign_var_name);
            else
                warning('结构体中未找到分配变量: %s', params.assign_var_name);
            end
            
            if isfield(solution_file, params.packages_var_name)
                packages = solution_file.(params.packages_var_name);
            else
                warning('结构体中未找到包变量: %s', params.packages_var_name);
            end
        else
            % 从文件加载
            if ~exist(solution_file, 'file')
                error('解决方案文件不存在: %s', solution_file);
            end
            
            if params.verbose
                fprintf('从文件加载解决方案: %s\n', solution_file);
            end
            
            % 加载MAT文件
            mat_content = load(solution_file, params.assign_var_name, params.packages_var_name);
            
            % 提取变量
            if isfield(mat_content, params.assign_var_name)
                assign = mat_content.(params.assign_var_name);
            else
                warning('文件中未找到分配变量: %s', params.assign_var_name);
            end
            
            if isfield(mat_content, params.packages_var_name)
                packages = mat_content.(params.packages_var_name);
            else
                warning('文件中未找到包变量: %s', params.packages_var_name);
            end
        end
        
        % 验证加载的数据
        validate_solution(assign, packages, params.verbose);
        
    catch ME
        error('加载初始解决方案失败: %s', ME.message);
    end
    
    if params.verbose
        fprintf('成功加载解决方案，包含 %d 个包\n', length(assign));
    end
end

function validate_solution(assign, packages, verbose)
% 验证解决方案数据的有效性
    if isempty(assign)
        if verbose, warning('分配向量为空'); end
        return;
    end
    
    if ~isstruct(packages) || ~isfield(packages, 'list') || ~isfield(packages, 'attrs')
        warning('包结构体格式不正确，缺少必要字段');
        return;
    end
    
    % 检查分配向量和包数量是否匹配
    if length(assign) ~= length(packages.list)
        warning('分配向量长度 (%d) 与包数量 (%d) 不匹配', length(assign), length(packages.list));
    end
    
    % 确保包结构体的attrs字段是正确的大小
    if length(packages.attrs) ~= length(packages.list)
        warning('包属性数量 (%d) 与包列表数量 (%d) 不匹配', length(packages.attrs), length(packages.list));
    end
end