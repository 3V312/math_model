



function ratio = compute_fragile_ratio(sub_items, data)
% 计算小组中3级易碎品的体积占比
% 输入：
%   sub_items - 小组商品索引
%   data - 商品数据结构体
% 输出：
%   ratio - 3级易碎品体积占比（标量）
    
    % 安全检查
    if isempty(sub_items) || ~isfield(data, 'fragile_level') || ~isfield(data, 'volumes')
        ratio = 0;
        return;
    end
    
    % 确保sub_items是有效的索引
    valid_indices = sub_items(sub_items >= 1 & sub_items <= length(data));
    if isempty(valid_indices)
        ratio = 0;
        return;
    end
    
    % 安全地获取易碎品
    try
        fragile_mask = zeros(size(valid_indices));
        for i = 1:length(valid_indices)
            idx = valid_indices(i);
            if isfield(data(idx), 'fragile_level') && data(idx).fragile_level == 3
                fragile_mask(i) = 1;
            end
        end
        fragile_items = valid_indices(fragile_mask == 1);
        
        % 计算体积
        total_volume = 0;
        fragile_volume = 0;
        
        % 计算总体积
        for i = 1:length(valid_indices)
            idx = valid_indices(i);
            if isfield(data(idx), 'volumes') && isnumeric(data(idx).volumes) && data(idx).volumes >= 0
                total_volume = total_volume + data(idx).volumes;
            end
        end
        
        % 计算易碎品体积（修复变量作用域错误）
        for i = 1:length(fragile_items)
            frag_idx = fragile_items(i);
            if isfield(data(frag_idx), 'volumes') && isnumeric(data(frag_idx).volumes) && data(frag_idx).volumes >= 0
                fragile_volume = fragile_volume + data(frag_idx).volumes;
            end
        end
        
        % 计算比例（避免除零错误）
        if total_volume > 0
            ratio = fragile_volume / total_volume;
            % 确保比例是有效的数值
            if ~isnumeric(ratio) || isnan(ratio) || isinf(ratio)
                ratio = 0;
            end
        else
            ratio = 0;
        end
    catch ME
        % 出错时返回安全的默认值
        fprintf('计算易碎品比例时出错: %s\n', ME.message);
        ratio = 0;
    end
end
