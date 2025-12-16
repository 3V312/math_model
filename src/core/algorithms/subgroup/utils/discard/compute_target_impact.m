


function target_scores = compute_target_impact(items, data, params)
% COMPUTE_TARGET_IMPACT 计算丢弃每个商品对目标函数的影响
% 分数越高表示丢弃对目标函数影响越小（更优）
% 输入:
%   items - 商品索引列表
%   data - 数据结构体，包含商品属性
%   params - 算法参数
%   target_scores - 每个商品对目标函数的影响分数（分数越高越应该丢弃）

    n_items = length(items);
    target_scores = zeros(n_items, 1);
    
    % 获取当前小组的重量和体积
    current_weights = data.weights(items);
    current_volumes = data.volumes(items);
    
    % 计算当前小组的总重量和总体积
    current_total_weight = sum(current_weights);
    current_total_volume = sum(current_volumes);
    
    for i = 1:n_items
        item_idx = items(i);
        item_weight = data.weights(item_idx);
        item_volume = data.volumes(item_idx);
        
        % === 1. 重量影响评分 ===
        if current_total_weight > 0
            % 商品重量占比越大，丢弃后对重量均衡影响越大 → 应该保留（低分）
            weight_ratio = item_weight / current_total_weight;
            weight_score = 1.0 - weight_ratio;  % 重量越小分数越高
        else
            weight_score = 0.5;
        end
        
        % === 2. 体积影响评分 ===
        if current_total_volume > 0
            % 商品体积占比越大，丢弃后对体积均衡影响越大 → 应该保留（低分）
            volume_ratio = item_volume / current_total_volume;
            volume_score = 1.0 - volume_ratio;  % 体积越小分数越高
        else
            volume_score = 0.5;
        end
        
        % === 3. 极端值惩罚 ===
        % 特别重或特别大的商品应该尽量避免丢弃
        extreme_penalty = 0;
        if item_weight > mean(data.weights) * 1.5
            extreme_penalty = extreme_penalty - 0.3;  % 特别重的商品应该保留
        end
        if item_volume > mean(data.volumes) * 1.5
            extreme_penalty = extreme_penalty - 0.3;  % 特别大的商品应该保留
        end
        
        % === 4. 综合目标影响 ===
        % 正分表示丢弃对目标函数影响小（应该丢弃）
        % 重量和体积各占50%权重
        target_scores(i) = (weight_score * 0.5 + volume_score * 0.5) + extreme_penalty;
    end
end