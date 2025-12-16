% 海外仓多约束商品分组优化问题求解代码 

%% 运行模式选择 
run_mode = input('请选择运行模式 (1: 小规模验证, 2: 大规模问题): '); 

%% 数据准备
% 读取Excel数据文件 
file_path = 'D:\MATLAB\projects\海外仓多约束规划_problem1\data\raw\附件1：商品属性数据.xlsx'; 
data_table = readtable(file_path, 'Range', 'A2:G81'); 

% 获取商品总数 
N_total = height(data_table); 
fprintf('成功读取 %d 件商品数据\n', N_total); 

% 提取商品属性 
w_data = data_table{:, 2}; % 商品重量数据 
f_data = data_table{:, 5}; % 易碎等级数据 
material_data = data_table{:, 4}; % 材质数据 

%% 根据运行模式设置参数 
if run_mode == 1 
    % 小规模验证：随机选择12个商品 
    selected_indices = randperm(N_total, 12); 
    w = w_data(selected_indices); 
    f = f_data(selected_indices); 
    material = material_data(selected_indices); 
    N = 12; 
    % 小规模参数 
    K = 3; % 3个小组 
    group_size = 4; 
    total_selected = K * group_size; 
    fprintf('小规模验证模式：%d个商品分成%d个小组\n', N, K); 
else 
    % 大规模问题：使用所有80个商品进行筛选 
    w = w_data; 
    f = f_data; 
    material = material_data; 
    N = N_total; 
    % 大规模参数 
    K = 6; % 6个小组 
    group_size = 4; 
    total_selected = K * group_size; 
    fprintf('大规模问题模式：从%d个商品中筛选%d件，分成%d个小组\n', N, total_selected, K); 
end 

%% 创建优化问题 
prob = optimproblem('ObjectiveSense', 'minimize'); 

% 决策变量：x(i,k)表示商品i是否分配到小组k 
x = optimvar('x', N, K, 'Type', 'integer', 'LowerBound', 0, 'UpperBound', 1); 

% 材质种类数量 - 动态计算实际材质种类数
unique_materials = unique(material);
M = length(unique_materials);
fprintf('检测到 %d 种不同的材质\n', M);

% 材质指示变量u(k,m)，表示小组k中是否使用了材质m 
u = optimvar('u', K, M, 'Type', 'integer', 'LowerBound', 0, 'UpperBound', 1); 

%% 辅助变量 
% 小组k的总重量 
group_weights = optimvar('group_weights', K, 'LowerBound', 0); 

% 小组最大最小重量变量
W_max = optimvar('W_max', 'LowerBound', 0);
W_min = optimvar('W_min', 'LowerBound', 0);

% 约束违反变量 
xi = optimvar('xi', K, 'LowerBound', 0); % 易碎品约束违反变量
eta = optimvar('eta', K, 'LowerBound', 0); % 材质种类约束违反变量

%% 约束条件 
% 1. 商品分配约束：每件商品最多被分配到一个小组
prob.Constraints.each_item_one_group = sum(x, 2) <= 1; 

% 2. 总商品数量约束：确保恰好选出total_selected件商品
prob.Constraints.total_selected_items = sum(x(:)) == total_selected; 

% 3. 小组容量约束：每个小组必须恰好包含group_size件商品
for k = 1:K 
    prob.Constraints.(sprintf('group_size_%d', k)) = sum(x(:,k)) == group_size; 
end 

% 4. 小组重量计算约束
for k = 1:K 
    prob.Constraints.(sprintf('group_weight_%d', k)) = sum(w .* x(:,k)) == group_weights(k); 
end 

% 5. W_max和W_min约束
for k = 1:K
    prob.Constraints.(sprintf('weight_leq_Wmax_%d', k)) = group_weights(k) <= W_max;
    prob.Constraints.(sprintf('weight_geq_Wmin_%d', k)) = group_weights(k) >= W_min;
end

% 6. 易碎品数量约束（带惩罚）
for k = 1:K 
    fragile_count = sum(x(:,k) .* (f == 3)); % 3级易碎品
    prob.Constraints.(sprintf('fragile_limit_%d', k)) = fragile_count <= 2 + xi(k); 
end 

% 7. 材质种类约束

for k = 1:K 
    for mat_idx = 1:M
        material_value = unique_materials(mat_idx);
        material_mask = (material == material_value);
        
        % 正向约束：确保如果有材质m的商品，则u必须为1
        prob.Constraints.(sprintf('material_presence_%d_%d', k, mat_idx)) = ...
            sum(x(:,k) .* material_mask) <= group_size * u(k, mat_idx);
        
        % 反向约束：确保如果u=1，则至少有一个材质m的商品
        % 使用一个小的正数epsilon来确保约束的正确实现
        epsilon = 0.1; % 一个小的正数，确保u=1时至少有一个商品
        prob.Constraints.(sprintf('material_absence_%d_%d', k, mat_idx)) = ...
            u(k, mat_idx) <= sum(x(:,k) .* material_mask) + epsilon;
    end
    % 材质种类数量约束（带惩罚）
    prob.Constraints.(sprintf('material_type_limit_%d', k)) = sum(u(k, :)) <= 2 + eta(k);
end

%% 目标函数参数设置
% 根据建模设置正确的系数
lambda1 = 0.80; % 首要目标权重
lambda2 = 0.20; % 次要目标权重
rho1 = 100;    % 易碎品约束惩罚系数
rho2 = 150;   % 材质约束惩罚系数

% 计算归一化因子delta_norm
max_weight = max(w);
delta_norm = max_weight * group_size * 0.5;

% 计算W_max理论值（前total_selected个最大重量之和）？？？
sorted_weights = sort(w, 'descend');
theoretical_W_max = sum(sorted_weights(1:total_selected));

% 目标函数
% 首要目标：最小化组间重量差 (W_max - W_min)/delta_norm
% 次要目标：最大化总重量 -sum(group_weights)/theoretical_W_max（注意前面有负号）
% 惩罚项：易碎品约束违反和材质约束违反
obj_term1 = lambda1 * (W_max - W_min) / delta_norm;
obj_term2 = -lambda2 * sum(group_weights) / theoretical_W_max;
penalty_term = rho1 * sum(xi) + rho2 * sum(eta);

prob.Objective = obj_term1 + obj_term2 + penalty_term;

%% 定义OutputFcn回调函数
function stop = convergenceOutputFcn(optimValues, state, convergence_data)
    stop = false;
    
    % 检查输入参数
    if ~isstruct(optimValues) || ~ischar(state) || ~isstruct(convergence_data)
        return;
    end
    
    % 只在迭代状态和结束状态记录数据
    if strcmp(state, 'iter') || strcmp(state, 'done')
        % 计算已用时间
        time_elapsed = toc(convergence_data.start_time);
        
        % 记录迭代次数
        if isfield(optimValues, 'iterations')
            iteration_num = optimValues.iterations;
        else
            iteration_num = length(convergence_data.objective_values) + 1;
        end
        
        % 记录目标函数值
        if isfield(optimValues, 'fval')
            objective_val = optimValues.fval;
        else
            objective_val = NaN;
        end
        
        % 记录GAP值（转换为百分比）
        if isfield(optimValues, 'relativegap')
            gap_val = optimValues.relativegap * 100;
        else
            gap_val = NaN;
        end
        
        % 记录是否找到可行解
        feasible = isfield(optimValues, 'feasible') && optimValues.feasible;
        
        % 存储数据
        convergence_data.objective_values(end+1) = objective_val;
        convergence_data.gap_values(end+1) = gap_val;
        convergence_data.iterations(end+1) = iteration_num;
        convergence_data.time_elapsed(end+1) = time_elapsed;
        convergence_data.feasible_status(end+1) = feasible;
        
        % 初始时xi_total和eta_total设为0，后续会在求解完成后更新
        convergence_data.xi_total(end+1) = 0;
        convergence_data.eta_total(end+1) = 0;
    end
end

%% 初始化收敛性追踪数据结构
convergence_data = struct();
convergence_data.objective_values = [];  % 目标函数值
convergence_data.gap_values = [];       % GAP百分比
convergence_data.xi_total = [];         % 易碎品约束违反总量
convergence_data.eta_total = [];        % 材质约束违反总量
convergence_data.iterations = [];       % 迭代次数
convergence_data.time_elapsed = [];     % 求解时间
convergence_data.feasible_status = [];  % 可行解状态
convergence_data.start_time = tic;      % 开始计时

% 创建函数句柄（现在指向外部函数文件）
outputFcn = @(optimValues, state) convergenceOutputFcn(optimValues, state, convergence_data);

% 设置求解选项
options = optimoptions('intlinprog', ...
    'Display', 'iter', ...
    'RelativeGapTolerance', 1e-6, ...
    'MaxTime', 110, ...
    'OutputFcn', outputFcn);

fprintf('开始求解...\n');
fprintf('当GAP达到1e-6后，求解器将自动控制收敛标准\n');
fprintf('目标函数系数: lambda1=%.2f, lambda2=%.2f\n', lambda1, lambda2);
fprintf('惩罚系数: rho1=%d, rho2=%d\n', rho1, rho2);

% 直接使用solve函数
[sol, fval, exitflag, output] = solve(prob, 'Options', options);

fprintf('求解完成！退出标志: %d, 目标值: %.4f\n', exitflag, fval);
%% 结果分析
if exist('sol', 'var') && ~isempty(sol) && isfield(sol, 'x')
    % 计算实际约束违反量
    actual_xi = zeros(1, K);  % 每个小组的易碎品约束违反量
    actual_eta = zeros(1, K); % 每个小组的材质约束违反量
    
    for k = 1:K
        % 找出分配到该小组的商品
        group_items = find(sol.x(:,k) > 0.5);
        
        % 计算易碎品约束违反量（3级易碎品数量超过2的部分）
        fragile_count = sum(f(group_items) == 3);
        actual_xi(k) = max(0, fragile_count - 2);
        
        % 计算材质约束违反量（材质种类超过2的部分）
        material_count = length(unique(material(group_items)));
        actual_eta(k) = max(0, material_count - 2);
    end
    
    % 计算总违反量
    total_xi = sum(actual_xi);
    total_eta = sum(actual_eta);
    
    % 更新convergence_data中的最后一个记录
    if ~isempty(convergence_data.objective_values)
        convergence_data.xi_total(end) = total_xi;
        convergence_data.eta_total(end) = total_eta;
    end
    
    % 验证是否是有效解（每个小组都有正确数量的商品）
    valid_solution = true;
    for k = 1:K
        assigned_count = sum(sol.x(:,k) > 0.5);
        if assigned_count ~= group_size
            valid_solution = false;
            break;
        end
    end
    
    if valid_solution || (exitflag > 0)
        % 显示分组结果
        fprintf('\n========== 分组结果 ==========\n');
        
        total_selected_weight = 0;
        group_weights_values = zeros(1, K);
        
        for k = 1:K
            % 找出分配到该小组的商品
            group_items = find(sol.x(:,k) > 0.5);
            group_weight = sum(w(group_items));
            group_weights_values(k) = group_weight;
            total_selected_weight = total_selected_weight + group_weight;
            
            fprintf('\n小组 %d:\n', k);
            fprintf('  商品索引: ');
            for i = 1:length(group_items)
                fprintf('%d ', group_items(i));
            end
            fprintf('\n  小组重量: %.2f\n', group_weight);
            
            % 计算易碎品数量
            fragile_count = sum(f(group_items) == 3);
            fprintf('  易碎品数量(3级): %d\n', fragile_count);
            
            % 计算材质种类
            group_materials = unique(material(group_items));
            fprintf('  材质种类: ');
            for i = 1:length(group_materials)
                fprintf('%d ', group_materials(i));
            end
            fprintf('\n  材质种类数量: %d\n', length(group_materials));
        end
        
        % 计算组间重量差异
        actual_W_max = max(group_weights_values);
        actual_W_min = min(group_weights_values);
        weight_diff = actual_W_max - actual_W_min;
        
        fprintf('\n========== 整体统计 ==========\n');
        fprintf('总选中商品重量: %.2f\n', total_selected_weight);
        fprintf('最大小组重量: %.2f\n', actual_W_max);
        fprintf('最小小组重量: %.2f\n', actual_W_min);
        fprintf('组间重量差: %.2f\n', weight_diff);
        fprintf('重量差/归一化因子: %.6f\n', weight_diff/delta_norm);
        
        % 检查约束违反情况
        if isfield(sol, 'xi') && isfield(sol, 'eta')
            total_xi = sum(sol.xi);
            total_eta = sum(sol.eta);
            fprintf('易碎品约束总违反量: %.2f\n', total_xi);
            fprintf('材质约束总违反量: %.2f\n', total_eta);
        end
        
        % 修复三元运算符语法错误
        if exitflag > 0
            fprintf('求解状态: 成功\n');
        else
            fprintf('求解状态: 未完全收敛\n');
        end
        if isfield(output, 'relativeGap')
            fprintf('最终GAP值: %.6f%%\n', output.relativeGap * 100);
        end
    else
        fprintf('\n警告: 未得到有效解！请检查模型设置或增加求解时间。\n');
    end
else
        fprintf('\n错误: 求解失败或未得到解！\n');
    end

%% 实现文件自动编号和保存路径管理功能
if exist('convergence_data', 'var') && isstruct(convergence_data) && ~isempty(convergence_data.objective_values)
    % 定义基础保存路径
    base_output_path = 'D:\\MATLAB\\projects\\海外仓多约束规划_problem1\\output\\solutions\\';
    
    % 检查并创建保存目录（如果不存在）
    if ~exist(base_output_path, 'dir')
        [status, message] = mkdir(base_output_path);
        if status
            fprintf('创建输出目录: %s\n', base_output_path);
        else
            warning('无法创建输出目录: %s\n', message);
            % 如果无法创建目录，使用当前目录作为备选
            solution_path = pwd;
            fprintf('将使用当前目录保存结果: %s\n', solution_path);
        end
    end
    
    % 查找当前最大的编号X
    current_max_num = 0;
    
    % 获取目录中所有符合命名规则的文件夹
    dir_pattern = fullfile(base_output_path, 'problem1_solution_*');
    existing_dirs = dir(dir_pattern);
    
    % 遍历现有文件夹，提取最大编号
    for i = 1:length(existing_dirs)
        if isdir(fullfile(base_output_path, existing_dirs(i).name))
            % 提取编号部分
            folder_name = existing_dirs(i).name;
            num_str = folder_name(length('problem1_solution_')+1:end);
            num = str2double(num_str);
            if ~isnan(num) && num > current_max_num
                current_max_num = num;
            end
        end
    end
    
    % 计算新的编号
    new_num = current_max_num + 1;
    
    % 创建新的解决方案文件夹
    if ~exist('solution_path', 'var') || ~strcmp(solution_path, pwd)
        solution_folder = sprintf('problem1_solution_%d', new_num);
        solution_path = fullfile(base_output_path, solution_folder);
        [status, message] = mkdir(solution_path);
        if status
            fprintf('创建解决方案文件夹: %s\n', solution_path);
        else
            warning('无法创建解决方案文件夹: %s\n', message);
            % 如果无法创建子文件夹，使用基础路径
            solution_path = base_output_path;
            fprintf('将使用基础路径保存结果: %s\n', solution_path);
        end
    end
    % 生成收敛曲线可视化
    figure('Position', [100, 100, 1200, 800]);
    
    % 子图1：目标函数值 vs 时间
    subplot(2, 2, 1);
    plot(convergence_data.time_elapsed, convergence_data.objective_values, 'b-o', 'LineWidth', 1.5);
    xlabel('时间 (秒)');
    ylabel('目标函数值');
    title('目标函数值随时间的变化');
    grid on;
    
    % 子图2：目标函数值 vs 迭代次数（对数坐标）
    subplot(2, 2, 2);
    semilogy(convergence_data.iterations, convergence_data.objective_values, 'r-s', 'LineWidth', 1.5);
    xlabel('迭代次数');
    ylabel('目标函数值 (对数坐标)');
    title('目标函数值随迭代次数的变化');
    grid on;
    
    % 子图3：GAP收敛曲线
    subplot(2, 2, 3);
    plot(convergence_data.time_elapsed, convergence_data.gap_values, 'g-^', 'LineWidth', 1.5);
    xlabel('时间 (秒)');
    ylabel('GAP (%)');
    title('GAP收敛曲线');
    grid on;
    
    % 子图4：约束违反量变化
    subplot(2, 2, 4);
    hold on;
    plot(convergence_data.time_elapsed, convergence_data.xi_total, 'm-d', 'LineWidth', 1.5);
    plot(convergence_data.time_elapsed, convergence_data.eta_total, 'c-x', 'LineWidth', 1.5);
    hold off;
    xlabel('时间 (秒)');
    ylabel('约束违反量');
    title('约束违反量变化');
    legend('易碎品约束违反量', '材质约束违反量');
    grid on;
    
    % 设置整体标题
    sgtitle('优化求解收敛性分析');
    
    % 调整布局
    tightfig;
    
    try
        % 保存图像到解决方案文件夹
        figure_filename = fullfile(solution_path, sprintf('convergence_plot_%d.png', new_num));
        saveas(gcf, figure_filename);
        fprintf('收敛曲线已保存为: %s\n', figure_filename);
        
        % 保存FIG格式文件以便后续编辑
        fig_filename = fullfile(solution_path, sprintf('convergence_plot_%d.fig', new_num));
        saveas(gcf, fig_filename);
        fprintf('FIG格式文件已保存为: %s\n', fig_filename);
    
    end
    
    %% 实现CSV格式收敛数据表格输出
    csv_filename = fullfile(solution_path, sprintf('convergence_data_%d.csv', new_num));
    
    % 创建表格数据
    data_table = table(convergence_data.iterations', convergence_data.time_elapsed', convergence_data.objective_values', convergence_data.gap_values', convergence_data.xi_total', convergence_data.eta_total', convergence_data.feasible_status', 'VariableNames', {'Iteration', 'Time', 'ObjectiveValue', 'GAP_Percentage', 'Fragile_Violation', 'Material_Violation', 'Feasible'});
        
    
    
   
        % 写入CSV文件
        writetable(data_table, csv_filename);
        fprintf('收敛数据表格已保存为: %s\n', csv_filename);
     
     
    
    %% 实现TXT格式求解摘要报告生成
    txt_filename = fullfile(solution_path, sprintf('solution_summary_%d.txt', new_num));
    
    % 打开文件进行写入
    fileID = fopen(txt_filename, 'w');
    
    % 写入摘要报告标题
    fprintf(fileID, '=============================================================\n');
    fprintf(fileID, '            海外仓多约束商品分组优化求解摘要报告           \n');
    fprintf(fileID, '=============================================================\n\n');
    
    % 写入基本信息
    fprintf(fileID, '求解时间: %s\n', datestr(now));
    if run_mode == 1
    mode_str = '小规模验证';
    else
    mode_str = '大规模问题';
    end
    fprintf(fileID, '商品数量: %d\n', N);
    fprintf(fileID, '小组数量: %d\n', K);
    fprintf(fileID, '每个小组商品数: %d\n\n', group_size);
    
    % 写入求解性能信息
    fprintf(fileID, '【求解性能指标】\n');
    fprintf(fileID, '- 总求解时间: %.2f 秒\n', convergence_data.time_elapsed(end));
    fprintf(fileID, '- 总迭代次数: %d\n', convergence_data.iterations(end));
    
    % 写入收敛情况
    fprintf(fileID, '\n【收敛情况】\n');
    if ~isempty(convergence_data.objective_values)
        fprintf(fileID, '- 初始目标函数值: %.6f\n', convergence_data.objective_values(1));
        fprintf(fileID, '- 最终目标函数值: %.6f\n', convergence_data.objective_values(end));
        fprintf(fileID, '- 目标函数改进: %.2f%%\n', ...
            (convergence_data.objective_values(1) - convergence_data.objective_values(end)) / abs(convergence_data.objective_values(1)) * 100);
    end
    
    if ~isempty(convergence_data.gap_values)
        fprintf(fileID, '- 最终GAP值: %.6f%%\n', convergence_data.gap_values(end));
    end
    
    % 写入约束违反情况
    fprintf(fileID, '\n【约束违反情况】\n');
    fprintf(fileID, '- 易碎品约束总违反量: %.2f\n', convergence_data.xi_total(end));
    fprintf(fileID, '- 材质约束总违反量: %.2f\n', convergence_data.eta_total(end));
    
    % 如果有求解器输出信息
    if exist('output', 'var')
        fprintf(fileID, '\n【求解器信息】\n');
        if isfield(output, 'solver')
            fprintf(fileID, '- 求解器: %s\n', output.solver);
        end
        if isfield(output, 'exitflag')
            fprintf(fileID, '- 退出标志: %d\n', output.exitflag);
        end
        if isfield(output, 'message')
            fprintf(fileID, '- 求解消息: %s\n', output.message);
        end
    end
    
    % 写入文件信息
    fprintf(fileID, '\n【输出文件信息】\n');
    fprintf(fileID, '- 收敛曲线图像: %s\n', figure_filename);
    fprintf(fileID, '- 收敛数据表格: %s\n', csv_filename);
    fprintf(fileID, '- 求解摘要报告: %s\n\n', txt_filename);
    
    fprintf(fileID, '=============================================================\n');
    
    % 写入文件
    if fileID > 0
        fclose(fileID);
        fprintf('求解摘要报告已保存为: %s\n', txt_filename);
    else
        warning('无法创建求解摘要报告文件: %s', txt_filename);
    end
end
