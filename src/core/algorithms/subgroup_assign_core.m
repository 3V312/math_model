% 文件路径: d:\VScodeprojects\overseas_warehouse_optimization\src\core\algorithms\subgroup_assign_core.m
function [y,z] = subgroup_assign_core(x, data, params)
% 子组分配核心 将每个大组的商品细分为 3 个小组
% 输入:
%  x: 商品数量 x 大组数量 二进制分组 (商品->大组)
%  data: 加载数据输出
%  params: 包含 每组小组数 (默认 3)
% 输出:
%  y: 商品数量 x 总小组数 二进制 (商品->小组)
%  z: 大组数量 x 总小组数 二进制 (小组->大组)

    if nargin < 3
        params = struct(); 
    end
    I = size(x,1);
    G = size(x,2);
    K_per_group = getfieldwithdefault(params,'K_per_group',3);
    K_total = G * K_per_group;
    y = zeros(I, K_total);
    z = zeros(G, K_total);

    v = data.volumes(:);
    f = data.fragile_level(:);

    for g = 1:G
        kidx = (g-1)*K_per_group + (1:K_per_group);
        z(g,kidx) = 1;
        items = find(x(:,g) > 0.5);
        if isempty(items)
            continue; 
        end
      % 更智能的体积分配策略
        sub_v = zeros(1, K_per_group);
        sub_items = cell(1, K_per_group);
        [volumes_sorted, order] = sort(v(items), 'descend');
        ordered = items(order);

        % 先分配大体积商品，使用轮询方式确保初始均衡
        for i = 1:min(K_per_group, length(ordered))
            it = ordered(i);
            sj = mod(i-1, K_per_group) + 1;  % 轮询分配
            sub_items{sj}(end+1) = it;
            sub_v(sj) = sub_v(sj) + v(it);
        end

        % 后续商品使用预测性分配
        for i = K_per_group+1:length(ordered)
         it = ordered(i);
            current_volume = v(it);
    
            % 计算分配到每个小组后的体积差异
            volume_diffs = zeros(1, K_per_group);
            for k = 1:K_per_group
                new_volume = sub_v(k) + current_volume;
                % 计算分配后的总体积标准差（简化为与平均值的差异）
                avg_volume = (sum(sub_v) + current_volume) / K_per_group;
                volume_diffs(k) = abs(new_volume - avg_volume);
            end
    
            % 选择使体积差异最小的小组
            [~, sj] = min(volume_diffs);
            sub_items{sj}(end+1) = it;
            sub_v(sj) = sub_v(sj) + current_volume;
        end

        % 确保大致相等的容量（目标4个）
        % 如果某个子组商品过多，将最后一个移动到最不满的子组
        for sj = 1:K_per_group
            while numel(sub_items{sj}) > 6 % 硬限制以避免无限循环
                % 将额外的商品移动到商品数量最少的子组
                [~, tgt] = min(cellfun(@numel, sub_items));
                if tgt==sj
                    break; 
                end
                mv = sub_items{sj}(end);
                sub_items{sj}(end) = [];
                sub_items{tgt}(end+1) = mv;
            end
        end
        
        max_outer_iterations = 10;
for outer_iter = 1:max_outer_iterations
    % 实时计算比例
    ratios = calculate_all_ratios(sub_items, v, f);
    
    if all(ratios <= 0.4)
        break;
    end
    
    improved_this_round = false;
    violating_groups = find(ratios > 0.4);
    
    % 按比例从高到低排序，优先修复最严重的小组
    [~, order] = sort(ratios(violating_groups), 'descend');
    violating_groups_ordered = violating_groups(order);
    
    for i = 1:length(violating_groups_ordered)
        violating_group = violating_groups_ordered(i);
        
        % 实时获取最新比例
        current_ratios = calculate_all_ratios(sub_items, v, f);
        
        [sub_items, repaired] = repair_violating_group(sub_items, v, f, violating_group, current_ratios, 5);
        
        if repaired
            improved_this_round = true;
           
        end
    end
    
    if ~improved_this_round
        break;
    end
end

       
        
        % 分配到 y
        for j = 1:K_per_group
            for it = sub_items{j}
                y(it, kidx(j)) = 1;
            end
        end
    end
end



% function v = getfieldwithdefault(s,name,def)
% 
% %有问题
% 
%     if isfield(s,name)
%         v = s.(name); 
%     else 
%         v = def; 
%     end
% end

