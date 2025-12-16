function [processed_items, processed_attrs] = process_new_items(new_items_data, params)
% process_new_items - 处理新增商品数据，进行格式转换和属性初始化
% 输入:
%   new_items_data - 新增商品原始数据（结构体或表格）
%   params - 处理参数
% 输出:
%   processed_items - 处理后的商品列表
%   processed_attrs - 处理后的商品属性结构体数组

    % 默认参数
    if nargin < 2
        params = struct();
    end
    
    % 参数解析
    verbose = getfieldwithdefault(params, 'verbose', false);
    
    % 初始化输出
    processed_items = [];
    processed_attrs = struct();
    
    % 检查输入数据
    if isempty(new_items_data)
        warning('process_new_items:EmptyData', '输入数据为空');
        return;
    end
    
    % 确定数据格式并处理
    if isstruct(new_items_data)
        % 处理结构体格式
        item_count = numel(new_items_data);
        processed_items = cell(item_count, 1);
        processed_attrs = repmat(struct(), item_count, 1);
        
        for i = 1:item_count
            item = new_items_data(i);
            
            % 处理基本信息
            processed_items{i} = ['item_', num2str(i)];
            
            % 初始化属性结构体
            attrs = struct();
            
            % 处理易碎级别
            if isfield(item, 'fragile_level') && ~isempty(item.fragile_level)
                frag_level = item.fragile_level;
                % 确保易碎级别为数值
                if ischar(frag_level) || isstring(frag_level)
                    frag_level = str2double(frag_level);
                end
                if isnumeric(frag_level)
                    attrs.fragile_level = frag_level;
                else
                    attrs.fragile_level = 0;  % 默认为非易碎
                end
            else
                attrs.fragile_level = 0;
            end
            
            % 处理报关类型
            if isfield(item, 'customs_type') && ~isempty(item.customs_type)
                customs_type = item.customs_type;
                % 确保报关类型统一为数值
                if ischar(customs_type) || isstring(customs_type)
                    str_type = char(customs_type);
                    if strcmpi(str_type, 'A')
                        customs_type = 1;
                    elseif strcmpi(str_type, 'B')
                        customs_type = 2;
                    elseif strcmpi(str_type, 'C')
                        customs_type = 3;
                    else
                        customs_type = 0;  % 未知类型
                    end
                end
                attrs.customs_type = customs_type;
            else
                attrs.customs_type = 0;
            end
            
            % 处理体积
            if isfield(item, 'volume') && ~isempty(item.volume)
                volume = item.volume;
                if isnumeric(volume)
                    attrs.volume = volume;
                else
                    attrs.volume = 0;
                end
            else
                attrs.volume = 0;
            end
            
            % 处理重量
            if isfield(item, 'weight') && ~isempty(item.weight)
                weight = item.weight;
                if isnumeric(weight)
                    attrs.weight = weight;
                else
                    attrs.weight = 0;
                end
            else
                attrs.weight = 0;
            end
            
            % 处理时效需求
            if isfield(item, 'time_requirement') && ~isempty(item.time_requirement)
                time_req = item.time_requirement;
                % 确保时效需求为数值
                if ischar(time_req) || isstring(time_req)
                    time_req = str2double(time_req);
                end
                if isnumeric(time_req)
                    attrs.time_requirement = time_req;
                else
                    attrs.time_requirement = 0;
                end
            else
                attrs.time_requirement = 0;
            end
            
            % 处理商品ID
            if isfield(item, 'item_id') && ~isempty(item.item_id)
                attrs.item_id = item.item_id;
            else
                attrs.item_id = ['item_', num2str(i)];
            end
            
            processed_attrs(i) = attrs;
        end
    elseif istable(new_items_data)
        % 处理表格格式
        item_count = height(new_items_data);
        processed_items = cell(item_count, 1);
        processed_attrs = repmat(struct(), item_count, 1);
        
        for i = 1:item_count
            processed_items{i} = ['item_', num2str(i)];
            attrs = struct();
            
            % 获取表格中的字段名
            var_names = new_items_data.Properties.VariableNames;
            
            % 处理易碎级别
            if any(strcmpi(var_names, 'fragile_level'))
                frag_level = new_items_data{i, 'fragile_level'};
                if ischar(frag_level) || isstring(frag_level)
                    frag_level = str2double(frag_level);
                end
                if isnumeric(frag_level)
                    attrs.fragile_level = frag_level;
                else
                    attrs.fragile_level = 0;
                end
            else
                attrs.fragile_level = 0;
            end
            
            % 处理报关类型
            if any(strcmpi(var_names, 'customs_type'))
                customs_type = new_items_data{i, 'customs_type'};
                if ischar(customs_type) || isstring(customs_type)
                    str_type = char(customs_type);
                    if strcmpi(str_type, 'A')
                        customs_type = 1;
                    elseif strcmpi(str_type, 'B')
                        customs_type = 2;
                    elseif strcmpi(str_type, 'C')
                        customs_type = 3;
                    else
                        customs_type = 0;
                    end
                end
                attrs.customs_type = customs_type;
            else
                attrs.customs_type = 0;
            end
            
            % 处理体积
            if any(strcmpi(var_names, 'volume'))
                volume = new_items_data{i, 'volume'};
                if isnumeric(volume)
                    attrs.volume = volume;
                else
                    attrs.volume = 0;
                end
            else
                attrs.volume = 0;
            end
            
            % 处理重量
            if any(strcmpi(var_names, 'weight'))
                weight = new_items_data{i, 'weight'};
                if isnumeric(weight)
                    attrs.weight = weight;
                else
                    attrs.weight = 0;
                end
            else
                attrs.weight = 0;
            end
            
            % 处理时效需求
            if any(strcmpi(var_names, 'time_requirement'))
                time_req = new_items_data{i, 'time_requirement'};
                if ischar(time_req) || isstring(time_req)
                    time_req = str2double(time_req);
                end
                if isnumeric(time_req)
                    attrs.time_requirement = time_req;
                else
                    attrs.time_requirement = 0;
                end
            else
                attrs.time_requirement = 0;
            end
            
            % 处理商品ID
            if any(strcmpi(var_names, 'item_id'))
                attrs.item_id = new_items_data{i, 'item_id'};
            else
                attrs.item_id = ['item_', num2str(i)];
            end
            
            processed_attrs(i) = attrs;
        end
    else
        error('process_new_items:InvalidDataType', '输入数据类型不支持，仅支持结构体或表格');
    end
    
    % 日志输出
    if verbose
        fprintf('处理完成 %d 个新增商品\n', length(processed_items));
    end
end