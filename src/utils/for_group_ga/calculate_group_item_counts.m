function counts = calculate_group_item_counts(assign, packages, G)
% 出现在：group_ga.m
% 计算每个组的商品数量
    counts = zeros(1, G);
    for g = 1:G
        packages_in_group = find(assign == g);
        for p = 1:length(packages_in_group)
            pkg_id = packages_in_group(p);
            counts(g) = counts(g) + length(packages.list{pkg_id});
        end
    end
end