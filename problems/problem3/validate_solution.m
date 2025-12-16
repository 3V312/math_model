function [is_valid, info] = validate_solution(solution, data, params)
% validate_solution 解决方案验证函数包装器
% 自动根据参数选择合适的验证函数
% 输入:
%   solution - 解决方案结构体
%   data - 数据结构体
%   params - 参数结构体（可选，如果包含current_stage则使用对应的验证函数）
% 输出:
%   is_valid - 验证是否通过
%   info - 验证详细信息
    
    try
        % 检查是否有阶段信息
        stage = 1; % 默认使用阶段1
        if nargin >= 3 && isstruct(params) && isfield(params, 'current_stage')
            stage = params.current_stage;
        end
        
        % 根据阶段选择验证函数
        switch stage
            case 1
                % 使用阶段1的验证函数
                [is_valid, info] = validate_solution_stage1(solution, data, params);
                
            case 2
                % 使用阶段2的验证函数（需要new_items_data参数）
                if isfield(solution, 'new_items_data')
                    [is_valid, info] = validate_solution(solution, data, solution.new_items_data, params);
                else
                    warning('验证警告: 阶段2验证需要new_items_data，但未提供');
                    [is_valid, info] = validate_solution_stage1(solution, data, params);
                end
                
            otherwise
                % 默认使用阶段1验证
                warning('验证警告: 未知阶段 %d，默认使用阶段1验证', stage);
                [is_valid, info] = validate_solution_stage1(solution, data, params);
        end
        
    catch ME
        % 错误处理
        is_valid = false;
        info = struct();
        info.error = ME.message;
        info.stack = ME.stack;
        warning('验证函数执行出错: %s', ME.message);
    end
end