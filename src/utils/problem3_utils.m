function [result, additional_result] = problem3_utils(func_name, varargin)
% problem3_utils - 问题三函数索引和工具集合
% 此函数作为问题三所有相关函数的统一入口点和索引
% 输入:
%   func_name - 要调用的函数名称 (字符串)
%   varargin - 传递给目标函数的参数
% 输出:
%   result - 主要返回结果
%   additional_result - 额外返回结果（如果有）

    % 函数路径和依赖关系索引
    problem3_functions = struct(
        'repair', struct(
            'customs', 'repair_customs_constraint_3',
            'buffer', 'repair_buffer_constraint_3'
        ),
        'move', struct(
            'find_best_candidate', 'find_best_forced_move_candidate_3',
            'find_best_target', 'find_best_target_group_3'
        ),
        'add', struct(
            'items', 'problem3_add_items'
        ),
        'process', struct(
            'new_items', 'process_new_items'
        )
    );
    
    % 处理func_name，支持点表示法访问嵌套函数
    if contains(func_name, '.')
        parts = strsplit(func_name, '.');
        current = problem3_functions;
        
        for i = 1:length(parts)-1
            if isfield(current, parts{i})
                current = current.(parts{i});
            else
                error('未知的函数分类: %s', parts{i});
            end
        end
        
        if isfield(current, parts{end})
            actual_func_name = current.(parts{end});
        else
            error('未知的函数名: %s', func_name);
        end
    else
        % 直接映射常用函数名
        switch lower(func_name)
            case {'repair_customs', 'customs_repair', 'repaircustoms'}
                actual_func_name = 'repair_customs_constraint_3';
            case {'repair_buffer', 'buffer_repair', 'repairbuffer'}
                actual_func_name = 'repair_buffer_constraint_3';
            case {'find_move_candidate', 'findbestcandidate'}
                actual_func_name = 'find_best_forced_move_candidate_3';
            case {'find_target_group', 'findbesttarget'}
                actual_func_name = 'find_best_target_group_3';
            case {'add_items', 'additems'}
                actual_func_name = 'problem3_add_items';
            case {'process_items', 'processnewitems'}
                actual_func_name = 'process_new_items';
            case 'list_functions'
                % 返回所有可用函数列表
                result = list_available_functions(problem3_functions);
                additional_result = [];
                return;
            otherwise
                actual_func_name = func_name;
        end
    end
    
    % 检查函数是否存在
    if ~exist(actual_func_name, 'file') && ~exist(actual_func_name, 'builtin')
        error('函数 %s 不存在', actual_func_name);
    end
    
    % 调用目标函数并返回结果
    [result, additional_result] = feval(actual_func_name, varargin{:});
end

function func_list = list_available_functions(func_struct)
% 列出所有可用的函数
    func_list = {};
    list_nested_functions('', func_struct, func_list);
end

function list_nested_functions(prefix, struct_data, func_list)
% 递归列出嵌套函数
    fields = fieldnames(struct_data);
    for i = 1:length(fields)
        field = fields{i};
        value = struct_data.(field);
        
        if isstruct(value)
            % 递归处理嵌套结构体
            if isempty(prefix)
                new_prefix = field;
            else
                new_prefix = [prefix, '.', field];
            end
            list_nested_functions(new_prefix, value, func_list);
        else
            % 添加函数名
            if isempty(prefix)
                func_path = field;
            else
                func_path = [prefix, '.', field];
            end
            func_list{end+1} = struct('path', func_path, 'actual_name', value);
        end
    end
end