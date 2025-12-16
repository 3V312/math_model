function [time_viol, material_viol, fragile_viol, customs_viol, buffer_viol] = check_group_constraints_3(items, data, params)
% CHECK_GROUP_CONSTRAINTS_3 检查小组的约束违反状态（支持问题三）
% 输入:
%   items - 商品索引列表
%   data - 数据结构体，包含商品属性
%   params - 算法参数，可包含customs_map和buffer_groups字段
% 输出:
%   time_viol - 时效违反程度
%   material_viol - 材质违反程度  
%   fragile_viol - 易碎品违反程度
%   customs_viol - 报关约束违反程度
%   buffer_viol - 缓冲保护约束违反程度

    % 初始化所有违反程度
    time_viol = 0;
    material_viol = 0;
    fragile_viol = 0;
    customs_viol = 0;
    buffer_viol = 0;
    
    % === 1. 时效约束检查 ===
    % 要求每个大组内所有商品的时效需求保持完全一致
    if isfield(data, 'time_requirement') && ~isempty(data.time_requirement)
        unique_times = unique(data.time_requirement(items));
        if length(unique_times) > 1
            % 时效种类数超过1种即违反约束，违反程度为超岀的种类数
            time_viol = length(unique_times) - 1;
        end
    end
    
    % === 2. 材质约束检查 ===
    % 每个大组内商品的材质种类不得超过2种
    if isfield(data, 'material') && ~isempty(data.material)
        unique_materials = unique(data.material(items));
        if length(unique_materials) > 2
            % 材质种类超过2种即违反约束，违反程度为超出的数量
            material_viol = length(unique_materials) - 2;
        end
    end
    
    % === 3. 易碎品约束检查 ===
    % 每个小组中3级易碎品体积占比不得超过40%
    if isfield(data, 'fragile_level') && isfield(data, 'volumes') && ...
       ~isempty(data.fragile_level) && ~isempty(data.volumes)
        fragile_3_items = items(data.fragile_level(items) == 3);
        if ~isempty(fragile_3_items)
            fragile_volume = sum(data.volumes(fragile_3_items));
            total_volume = sum(data.volumes(items));
            if total_volume > 0
                fragile_ratio = fragile_volume / total_volume;
                if fragile_ratio > 0.4
                    % 易碎品比例超过40%即违反约束，违反程度为超出的比例
                    fragile_viol = fragile_ratio - 0.4;
                end
            end
        end
    end
    
    % === 4. 报关约束检查 ===
    % 检查报关类型混合情况
    if isfield(data, 'customs_type') && ~isempty(data.customs_type)
        % 获取组内所有不同的报关类型，并统一转换为数值类型
        unique_customs_types = {};
        for k = 1:length(items)
            item_idx = items(k);
            if isfield(data.customs_type, num2str(item_idx)) && ~isempty(data.customs_type{item_idx})
                c_type = data.customs_type{item_idx};
                % 转换为数值类型
                if ischar(c_type) || isstring(c_type)
                    str_type = char(c_type);
                    if strcmpi(str_type, 'A')
                        c_type = 1;
                    elseif strcmpi(str_type, 'B')
                        c_type = 2;
                    elseif strcmpi(str_type, 'C')
                        c_type = 3;
                    else
                        warning('未知的报关类型: %s', str_type);
                        continue; % 跳过无效类型
                    end
                end
                if isnumeric(c_type) && c_type >= 1 && c_type <= 3
                    unique_customs_types{end+1} = c_type; %#ok<AGROW>
                end
            end
        end
        unique_customs_types = unique(cell2mat(unique_customs_types));
        
        % 检查报关约束：每组最多2种报关类型
        if length(unique_customs_types) > 2
            violation_found = true;
            % 违反程度为超出的报关类型数
            customs_viol = length(unique_customs_types) - 2;
        else
            % 如果有2种报关类型，检查是否允许混合
            if length(unique_customs_types) == 2
                violation_found = false;
                
                % 获取报关映射（允许的混合规则）
                customs_map = struct();
                % 默认混合规则：所有类型都可以混合（根据问题需求可调整）
                customs_map.(num2str(1)) = {2, 3};
                customs_map.(num2str(2)) = {1, 3};
                customs_map.(num2str(3)) = {1, 2};
                
                % 如果提供了自定义映射，则覆盖默认映射
                if isfield(params, 'customs_map') && ~isempty(params.customs_map)
                    provided_map = params.customs_map;
                    % 合并提供的映射到默认映射
                    fields = fieldnames(provided_map);
                    for f = 1:length(fields)
                        field_name = fields{f};
                        customs_map.(field_name) = provided_map.(field_name);
                    end
                end
                
                % 检查是否允许混合这两种类型
                type1 = unique_customs_types(1);
                type2 = unique_customs_types(2);
                allowed = false;
                
                % 检查type1是否允许与type2混合
                if isfield(customs_map, num2str(type1)) && iscell(customs_map.(num2str(type1)))
                    allowed = any(cell2mat(customs_map.(num2str(type1))) == type2);
                end
                
                % 如果type1不允许与type2混合，检查type2是否允许与type1混合
                if ~allowed && isfield(customs_map, num2str(type2)) && iscell(customs_map.(num2str(type2)))
                    allowed = any(cell2mat(customs_map.(num2str(type2))) == type1);
                end
                
                % 如果不允许混合，增加违反程度
                if ~allowed
                    violation_found = true;
                    customs_viol = 1; % 不允许混合的类型组合
                end
            end
        end
    end
    
    % === 5. 缓冲保护约束检查 ===
    % 检查缓冲保护约束（此处为简化实现，实际需根据具体要求调整）
    if isfield(params, 'buffer_groups') && ~isempty(params.buffer_groups) && isfield(params, 'current_group')
        current_group = params.current_group;
        buffer_groups = params.buffer_groups;
        
        % 如果当前组是缓冲组，检查是否有需要特殊处理的情况
        if ismember(current_group, buffer_groups)
            % 这里可以根据具体的缓冲保护约束要求进行检查
            % 例如：检查缓冲组中是否包含了不应该包含的特殊物品类型
            % 或者检查缓冲组的大小是否符合要求
            
            % 此处为示例，具体实现需根据问题三的详细要求调整
            % 例如：如果缓冲组内商品数量超过某个阈值，增加违反程度
            if length(items) > 100 % 示例阈值
                buffer_viol = length(items) - 100;
            end
        end
    end
end