function is_fragile = is_item_fragile(item_idx, data)
% 判断商品是否为3级易碎品
% 出现在：local_search_optimization.m
    is_fragile = false;
    
    % 安全检查
    if item_idx < 1 || item_idx > length(data) || ~isfield(data, 'fragile_level')
        return;
    end
    
    if isfield(data(item_idx), 'fragile_level')
        is_fragile = (data(item_idx).fragile_level == 3);
    end
end