% filepath: d:\VScodeprojects\overseas_warehouse_optimization\tests\test_problem2_functions.m
% 简单功能测试：构造一个可行解并调用 evaluate + save

% 路径配置 
project_root = 'D:\MATLAB\projects\海外仓多约束规划_problem1';

addpath(fullfile(project_root, 'problems'));      % 问题求解函数
addpath(fullfile(project_root, 'src', 'data'));   % 数据加载函数  
addpath(fullfile(project_root, 'tests'));         % 测试文件


% 加载数据
data = load_data();   % 使用你已有的 load_data

% 参数
I = data.N;
G = 6;
K_per_group = 3;
K_total = G * K_per_group;

% 构造可行 x (I x G)：选72个商品，每组12个
x = zeros(I, G);
sel_idx = 1:min(I,72); % 若 I>=72，取前72；否则取所有（仅作测试）
for g = 1:G
    start_i = (g-1)*12 + 1;
    end_i = min(g*12, numel(sel_idx));
    if start_i <= numel(sel_idx)
        ids = sel_idx(start_i:end_i);
        x(ids,g) = 1;
    end
end

% 构造 z (G x K_total)：每个大组对应连续的3个小组
z = zeros(G, K_total);
for g = 1:G
    kidx = (g-1)*K_per_group + (1:K_per_group);
    z(g, kidx) = 1;
end

% 构造 y (I x K_total)：每个大组的12件商品均匀分配到该组的3个小组（每小组4件）
y = zeros(I, K_total);
for g = 1:G
    kidx = (g-1)*K_per_group + (1:K_per_group);
    items = find(x(:,g) > 0.5);
    % 分配：每4个放到一个子组
    for j = 1:numel(items)
        sub_rel = ceil(j / 4);
        sub_rel = min(sub_rel, K_per_group);
        k = kidx(sub_rel);
        y(items(j), k) = 1;
    end
end

% 调用评估器
[Q, comps] = problem2_evaluate(x,y,z,data,struct('G',G,'K_per_group',K_per_group));

% 打印关键结果
fprintf('Q = %.6f\n', Q);
fprintf('feasible (粗判) = %d\n', comps.feasible);
fprintf('P_selection=%.3f, P_grouping=%.3f, P_subgroup=%.3f\n', comps.P_selection, comps.P_grouping, comps.P_subgroup);
fprintf('W (per group): %s\n', mat2str(comps.W,4));
fprintf('V (per sub): first 6 subgroups: %s\n', mat2str(comps.V(1:6),4));

% 保存结果
solution = struct('x',x,'y',y,'z',z,'Q',Q,'comps',comps);
problem2_save_solution(solution); 
