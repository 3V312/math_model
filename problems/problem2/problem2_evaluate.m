


% filepath: d:\VScodeprojects\overseas_warehouse_optimization\src\problems\problem2_evaluate.m
function [Q, comps] = problem2_evaluate(x,y,z,data,params)
% problem2_evaluate 计算综合目标 Q 及所有分项指标
%  x: I x G, y: I x K, z: G x K
%  data: struct from load_data (weights, volumes, fragile_level, material, time_requirement, N)
%  params: 可选参数结构体（lambda1,lambda2,rho1..rho6, target counts）
if nargin < 5, params = struct(); end
I = size(x,1);
G = size(x,2);
K = size(y,2);

w = data.weights(:);
v = data.volumes(:);
f = data.fragile_level(:);
m = data.material(:);
t = data.time_requirement(:);

% 默认参数
lambda1 = getfieldwithdefault(params,'lambda1',0.6);
lambda2 = getfieldwithdefault(params,'lambda2',0.4);
rho1 = getfieldwithdefault(params,'rho1',0);  % 商品选择惩罚
rho2 = getfieldwithdefault(params,'rho2',0);  % 大组规模惩罚  
rho3 = getfieldwithdefault(params,'rho3',300);  % 时效一致性惩罚
rho4 = getfieldwithdefault(params,'rho4',170);   % 易碎品体积约束惩罚
rho5 = getfieldwithdefault(params,'rho5',300);   % 材质多样性惩罚
rho6 = getfieldwithdefault(params,'rho6',0);  % 小组规模惩罚
target_total = getfieldwithdefault(params,'target_total',72);
target_per_group = getfieldwithdefault(params,'target_per_group',12);
target_per_sub = getfieldwithdefault(params,'target_per_sub',4);

% 辅助变量   
W = sum( x .* repmat(w,1,G), 1 ); % 1 x G
V = sum( y .* repmat(v,1,K), 1 ); % 1 x K

% 主目标项
maxW = max(W); minW = min(W);
termW = (maxW - minW);

% 每大组内部小组索引假设：小组按顺序分配到大组，或由 z 给出归属
% 计算每大组的内部小组体积极差：对每 g 找到 k s.t. z(g,k)==1
Vdiff_sum = 0;
for g = 1:G
    ks = find(z(g,:) > 0.5);
    if isempty(ks)
        % 若没有映射，则认为差为0并在惩罚项体现
        local_diff = 0;
    else
        localV = V(ks);
        local_diff = max(localV) - min(localV);
    end
    Vdiff_sum = Vdiff_sum + local_diff;
end

% 归一化因子
deltaW_norm = max(w) * target_per_group * 0.5; % max_i w_i *12*0.5 (target_per_group default 12)
DeltaV_norm = max(v) * target_per_sub * 2 * G; % max_i v_i *4*2*6 -> generalized

% 惩罚项计算
% P_selection
sum_x = sum(x,'all');
P_selection = (sum_x - target_total)^2 + sum( (sum(x,2) - 1).^2 );

% P_grouping
group_counts = sum(x,1);
P_grouping = sum( (group_counts - target_per_group).^2 );

% P_timeliness
P_timeliness = 0;
unique_t = unique(t);
for g = 1:G
    for tt = unique_t'
        idx = (t == tt);
        c = sum( x(idx,g) );
        P_timeliness = P_timeliness + (min( c, target_per_group - c )^2);
    end
end

% P_fragile
P_fragile = 0;
for g = 1:G
    ks = find(z(g,:) > 0.5);
    for k = ks
        idx_y = (y(:,k) > 0.5);
        denom = sum( v(idx_y) );
        if denom <= 0
            ratio = 0;
        else
            ratio = sum( v(idx_y & (f==3)) ) / denom;
        end
        excess = max(0, ratio - 0.40);%修改成0.35看看结果
        P_fragile = P_fragile + excess^2;
    end
end

% P_material
P_material = 0;
materials = unique(m);
for g = 1:G
    u_gm = zeros(numel(materials),1);
    for mi = 1:numel(materials)
        idxm = (m == materials(mi));
        if any( x(idxm,g) > 0.5 )
            u_gm(mi) = 1;
        end
    end
    P_material = P_material + max(0, sum(u_gm) - 2)^4;%材质约束不好
end

% P_subgroup
sub_counts = sum(y,1); % 1 x K
P_sub1 = sum( (sub_counts - target_per_sub).^2 );
P_sub2 = sum( (sum(y,2) - sum(x,2)).^2 );
P_subgroup = P_sub1 + P_sub2;

% 组合 Q
Q = lambda1 * (termW / max(deltaW_norm,eps)) + lambda2 * (Vdiff_sum / max(DeltaV_norm,eps)) + ...
    rho1*P_selection + rho2*P_grouping + rho3*P_timeliness + rho4*P_fragile + rho5*P_material + rho6*P_subgroup;

% 可行性粗判（所有一级惩罚为0）
feasible = all(P_selection == 0) && all(P_grouping == 0) && all(P_subgroup == 0) && all(sum(z,1) == 1) && all(sum(z,2) == 3);

% 输出 components
comps = struct();
comps.W = W;
comps.V = V;
comps.termW = termW;
comps.Vdiff_sum = Vdiff_sum;
comps.deltaW_norm = deltaW_norm;
comps.DeltaV_norm = DeltaV_norm;
comps.P_selection = P_selection;
comps.P_grouping = P_grouping;
comps.P_timeliness = P_timeliness;
comps.P_fragile = P_fragile;
comps.P_material = P_material;
comps.P_subgroup = P_subgroup;
comps.Q = Q;
comps.feasible = feasible;
end

% function v = getfieldwithdefault(s,name,def)
% if isfield(s,name)
%     v = s.(name);
% else 
%     v = def; 
% end
% end