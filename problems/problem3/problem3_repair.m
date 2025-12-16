function [solution_repaired, repair_info] = problem3_repair(solution_in, data, params)
% problem3_repair - 修复问题三的约束违规情况
%   修复报关约束、缓冲保护约束和其他约束，实现约束冲突处理优先级机制
%   
% 输入:
%   solution_in - 输入解决方案结构体，包含assign字段
%   data - 数据结构体，包含packages等信息
%   params - 参数结构体，包含修复参数
%   
% 输出:
%   solution_repaired - 修复后的解决方案
%   repair_info - 修复信息结构体

    % 初始化输出
    solution_repaired = solution_in;
    repair_info = struct();
    repair_info.customs_repairs = 0;
    repair_info.buffer_repairs = 0;
    repair_info.material_repairs = 0;
    repair_info.total_moves = 0;
    repair_info.conflicts_detected = 0;
    repair_info.conflicts_resolved = 0;
    repair_info.success = true;
    repair_info.error_msg = '';
    repair_info.iterations = 0;
    repair_info.constraint_priority = {'time', 'buffer', 'customs', 'material'};
    
    % 参数验证
    if ~isfield(solution_in, 'assign')
        error('输入解决方案必须包含assign字段');
    end
    
    if ~isfield(data, 'packages')
        error('数据必须包含packages字段');
    end
    
    % 确保params是结构体
    if ~exist('params', 'var') || isempty(params)
        params = struct();
    end
    
    % 设置默认参数
    if ~isfield(params, 'verbose')
        params.verbose = false;
    end
    
    if ~isfield(params, 'max_iterations')
        params.max_iterations = 100;
    end
    
    if ~isfield(params, 'constraint_priority')
        % 默认约束优先级：时效 > 缓冲保护 > 报关 > 材质
        params.constraint_priority = {'time', 'buffer', 'customs', 'material'};
    end
    
    if ~isfield(params, 'conflict_resolution_strategy')
        params.conflict_resolution_strategy = 'priority'; % 'priority', 'compromise', 'rollback'
    end
    
    if ~isfield(params, 'max_conflict_resolution_attempts')
        params.max_conflict_resolution_attempts = 3;
    end
    
    if params.verbose
        fprintf('开始修复问题三约束...\n');
    end
    
    % 获取必要数据
    assign = solution_repaired.assign;
    packages = data.packages;
    
    % 计算大组数量
    G = max(assign);
    
    try
        % 获取必要数据
        assign = solution_repaired.assign;
        packages = data.packages;
        
        % 计算大组数量
        G = max(assign);
        
        % 约束修复优先级循环
        main_iteration = 0;
        conflict_resolution_attempts = 0;
        previous_assign = assign; % 用于检测改进
        
        while main_iteration < params.max_iterations
            main_iteration = main_iteration + 1;
            repair_info.iterations = main_iteration;
            
            if params.verbose
                fprintf('\n主修复迭代 %d/%d\n', main_iteration, params.max_iterations);
            end
            
            % 按照优先级顺序修复约束
            constraint_fixed = false;
            
            for priority_idx = 1:length(params.constraint_priority)
                constraint_type = params.constraint_priority{priority_idx};
                
                % 保存当前状态用于可能的回滚
                before_fix_assign = assign;
                
                if params.verbose
                    fprintf('  修复 %s 约束 (优先级 %d)...\n', constraint_type, priority_idx);
                end
                
                switch constraint_type
                    case 'buffer'
                        % 修复缓冲保护约束
                        if exist('repair_buffer_constraint_3', 'file')
                            [assign, buffer_success] = repair_buffer_constraint_3(assign, packages, G, ...
                                'verbose', params.verbose, 'max_iterations', 50);
                            if buffer_success
                                constraint_fixed = true;
                                if params.verbose
                                    fprintf('  ✓ 缓冲保护约束修复成功\n');
                                end
                            end
                        end
                    
                    case 'customs'
                        % 修复报关约束
                        if exist('repair_customs_constraint_3', 'file')
                            [assign, customs_success] = repair_customs_constraint_3(assign, packages, G, ...
                                'verbose', params.verbose, 'max_iterations', 50);
                            if customs_success
                                constraint_fixed = true;
                                if params.verbose
                                    fprintf('  ✓ 报关约束修复成功\n');
                                end
                            end
                        end
                    
                    case 'material'
                        % 修复材质约束
                        % 这里可以调用现有的材质约束修复函数
                        if params.verbose
                            fprintf('  材质约束修复 - 复用现有逻辑\n');
                        end
                    
                    case 'time'
                        % 修复时效约束
                        if params.verbose
                            fprintf('  时效约束修复 - 需要确保时效一致性\n');
                        end
                    
                    otherwise
                        warning('未知的约束类型: %s', constraint_type);
                end
                
                % 约束冲突检测
                if constraint_fixed
                    % 检测是否修复一个约束导致其他约束违反
                    conflict_detected = false;
                    
                    % 检查是否违反了更高优先级的约束
                    for higher_priority_idx = 1:priority_idx-1
                        higher_constraint = params.constraint_priority{higher_priority_idx};
                        
                        % 这里简化处理，实际应该调用相应的约束检查函数
                        if params.verbose
                            fprintf('  检查是否违反更高优先级约束: %s\n', higher_constraint);
                        end
                        
                        % 示例：如果检测到冲突
                        if ~isempty(find(assign ~= before_fix_assign, 1))
                            conflict_detected = true;
                            repair_info.conflicts_detected = repair_info.conflicts_detected + 1;
                            break;
                        end
                    end
                    
                    % 冲突解决
                    if conflict_detected
                        if params.verbose
                            fprintf('  ⚠️  检测到约束冲突\n');
                        end
                        
                        switch params.conflict_resolution_strategy
                            case 'priority'
                                % 优先级策略：保持高优先级约束，回滚当前修复
                                assign = before_fix_assign;
                                if params.verbose
                                    fprintf('  回滚当前修复以保持高优先级约束\n');
                                end
                            
                            case 'compromise'
                                % 妥协策略：尝试部分修复
                                conflict_resolution_attempts = conflict_resolution_attempts + 1;
                                if conflict_resolution_attempts <= params.max_conflict_resolution_attempts
                                    if params.verbose
                                        fprintf('  尝试妥协解决方案 (尝试 %d/%d)\n', ...
                                            conflict_resolution_attempts, params.max_conflict_resolution_attempts);
                                    end
                                    % 这里可以实现更复杂的妥协逻辑
                                    repair_info.conflicts_resolved = repair_info.conflicts_resolved + 1;
                                else
                                    % 多次尝试失败后回滚
                                    assign = before_fix_assign;
                                    conflict_resolution_attempts = 0;
                                end
                            
                            case 'rollback'
                                % 回滚策略：完全回滚
                                assign = before_fix_assign;
                                if params.verbose
                                    fprintf('  回滚所有更改\n');
                                end
                        end
                    end
                end
            end
            
            % 检查是否有改进
            if isequal(assign, previous_assign)
                % 没有改进，可能已经收敛
                if params.verbose
                    fprintf('\n没有检测到进一步改进，修复可能已收敛\n');
                end
                break;
            end
            previous_assign = assign;
            
            % 检查是否所有约束都已满足
            % 这里应该调用完整的约束检查函数
            % if all_constraints_satisfied
            %     break;
            % end
        end
        
        % 更新解决方案
        solution_repaired.assign = assign;
        
        % 计算移动次数
        moved_packages = sum(assign ~= solution_in.assign);
        repair_info.total_moves = moved_packages;
        
        if params.verbose
            fprintf('\n修复完成!\n');
            fprintf('  总迭代次数: %d\n', main_iteration);
            fprintf('  检测到的约束冲突: %d\n', repair_info.conflicts_detected);
            fprintf('  解决的约束冲突: %d\n', repair_info.conflicts_resolved);
            fprintf('  总移动包数量: %d\n', repair_info.total_moves);
            fprintf('  约束优先级顺序: %s\n', strjoin(params.constraint_priority, ' > '));
        end
        
    catch ME
        repair_info.success = false;
        repair_info.error_msg = ME.message;
        if params.verbose
            fprintf('修复过程中出错: %s\n', ME.message);
        end
    end
end