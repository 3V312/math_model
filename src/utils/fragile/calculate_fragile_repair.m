


function ratio = calculate_fragile_repair(items, v, f)
% 计算小组中易碎品体积比例
%有问题
%出现在：
    if isempty(items)
        ratio = 0;
        return;
    end
    
    total_volume = sum(v(items));
    if total_volume == 0
        ratio = 0;
        return;
    end
    
    fragile_volume = sum(v(items(f(items) == 3)));
    ratio = fragile_volume / total_volume;
end

% function ratios = calculate_all_ratios(sub_items, v, f)
% % 计算所有小组的易碎品比例
%     K = length(sub_items);
%     ratios = zeros(1, K);
% 
%     for k = 1:K
%         ratios(k) = calculate_fragile_ratio(sub_items{k}, v, f);
%     end
% end
