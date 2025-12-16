function fragile_items = get_fragile_items(items, data)
% 获取3级易碎品的索引
% 出现在：local_search_optimization.m (perform_smart_swap, perform_smart_shift)
    fragile_items = [];
    
    % 安全检查：确保items和data有效
    if isempty(items) | ~isfield(data, 'fragile_level')
        return;
    end
    
    for i = 1:length(items)
        item_idx = items(i);
        if item_idx < 1 || item_idx > length(data)
            %fprintf('警告：无效商品索引 %d，跳过\n', item_idx);
            continue;
        end
        if isfield(data(item_idx), 'fragile_level') & data(item_idx).fragile_level == 3
            fragile_items = [fragile_items, i];
        end
    end
end