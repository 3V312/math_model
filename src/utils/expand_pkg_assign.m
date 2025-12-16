function [x,y,z] = expand_pkg_assign(pkg_assign, packages, data, params, G, P)
    % 展开函数：package assignment -> item-level x,y,z
    I = data.N;
    K_per_group = getfieldwithdefault(params,'K_per_group',3);
    K_total = G * K_per_group;
    x = zeros(I, G);
    
    % assign items by package
    for p_idx = 1:P
        g_val = pkg_assign(p_idx);
        items = packages.list{p_idx};
        x(items,g_val) = 1;
    end
    
    % initial z: per group consecutive K_per_group
    z = zeros(G, K_total);
    for g_idx = 1:G
        kidx = (g_idx-1)*K_per_group + (1:K_per_group);
        z(g_idx,kidx) = 1;
    end
    
    % y: simple round-robin into group's subgroups (4 items each if possible)
    y = zeros(I, K_total);
    for g_idx = 1:G
        items = find(x(:,g_idx)>0.5);
        kidx = (g_idx-1)*K_per_group + (1:K_per_group);
        for j = 1:numel(items)
            sub_rel = min(ceil(j / max(1,ceil(numel(items)/K_per_group))), K_per_group);
            y(items(j), kidx(sub_rel)) = 1;
        end
    end
end