function [updated_assign, updated_packages] = problem3_add_items(assign, packages, new_items_data, params)
% problem3_add_items - 将新商品添加到现有分配中
% 输入:
%   assign - 当前分配向量 (P x 1)
%   packages - 现有包结构体
%   new_items_data - 新商品数据（结构体或表格）
%   params - 参数字符串或结构体
% 输出:
%   updated_assign - 更新后的分配向量
%   updated_packages - 更新后的包结构体

    % 参数解析
    if nargin < 4 || isempty(params)
        params = struct();
    elseif ischar(params) || isstring(params)
        params = struct('verbose', strcmpi(params, 'verbose'));
    end
    
    % 设置默认参数
    if ~isfield(params, 'verbose'), params.verbose = false; end
    
    % 确保packages是正确的结构体格式
    if ~isstruct(packages) || ~isfield(packages, 'list') || ~isfield(packages, 'attrs')
        error('packages参数必须是包含list和attrs字段的结构体');
    end
    
    % 获取现有包数量
    P = length(packages.list);
    
    % 处理新商品数据
    [processed_items, processed_attrs] = process_new_items(new_items_data, params);
    
    % 计算新商品数量
    num_new_items = length(processed_items);
    
    % 初始化更新后的分配向量（新商品初始分配到组1）
    updated_assign = [assign; ones(num_new_items, 1)];
    
    % 初始化更新后的包结构体
    updated_packages = packages;
    updated_packages.list = [packages.list; processed_items];
    updated_packages.attrs = [packages.attrs; processed_attrs];
    
    % 更新商品ID
    for i = 1:num_new_items
        pkg_idx = P + i;
        if ~isfield(updated_packages.attrs(pkg_idx), 'pkg_id')
            updated_packages.attrs(pkg_idx).pkg_id = pkg_idx;
        end
        if isfield(updated_packages.attrs(pkg_idx), 'customs_type') && ...
           (ischar(updated_packages.attrs(pkg_idx).customs_type) || isstring(updated_packages.attrs(pkg_idx).customs_type))
            % 确保报关类型为数值
            str_type = char(updated_packages.attrs(pkg_idx).customs_type);
            if strcmpi(str_type, 'A'), updated_packages.attrs(pkg_idx).customs_type = 1;
            elseif strcmpi(str_type, 'B'), updated_packages.attrs(pkg_idx).customs_type = 2;
            elseif strcmpi(str_type, 'C'), updated_packages.attrs(pkg_idx).customs_type = 3;
            end
        end
    end
    
    if params.verbose
        fprintf('成功添加 %d 个新商品到现有分配中\n', num_new_items);
    end
end