% analysis.m 跨境电商海外仓分组方案综合分析脚本
% 读取solution_problem2.mat并生成详细分析报告

clear; clc;

% 定义文件路径
solution_path = 'D:\MATLAB\projects\海外仓多约束规划_problem1\output\solutions\solution_problem2.mat';
output_dir = 'D:\MATLAB\projects\海外仓多约束规划_problem1\output\solutions';

% 检查解决方案文件是否存在
if ~exist(solution_path, 'file')
    error('解决方案文件不存在: %s', solution_path);
end

% 加载解决方案数据
load(solution_path);

% 读取原始商品数据
data = load_data();

% 显示基本信息
fprintf('=====================================\n');
fprintf('跨境电商海外仓分组方案综合分析\n');
fprintf('=====================================\n');
fprintf('Q值: %.6f\n', Q);
fprintf('商品总数: %d\n', data.N);
fprintf('\n');

% 1. 大组-小组-商品结构分析
fprintf('1. 大组-小组-商品结构分析\n');
fprintf('=====================================\n');
analyze_group_structure(x, y, z, data);
fprintf('\n');

% 2. 约束满足情况分析
fprintf('2. 约束满足情况分析\n');
fprintf('=====================================\n');
analyze_constraints(x, y, z, data);
fprintf('\n');

% 3. 优化目标达成度分析
fprintf('3. 优化目标达成度分析\n');
fprintf('=====================================\n');
analyze_objectives(x, y, z, data);
fprintf('\n');

% 保存分析结果
save_analysis_report(x, y, z, data, Q, output_dir);

fprintf('分析完成，报告已保存到: %s\n', output_dir);

% ==================== 辅助函数 ====================

function analyze_group_structure(x, y, z, data)
    % 分析大组-小组-商品的层级结构
    G = size(x, 2);
    K = size(y, 2);
    
    for g = 1:G
        fprintf('大组 %d:\n', g);
        
        % 获取属于该大组的商品
        items_in_group = find(x(:, g) > 0.5);
        fprintf('  商品数量: %d\n', length(items_in_group));
        
        % 获取该大组的小组
        subgroups = find(z(g, :) > 0.5);
        fprintf('  小组索引: ');
        fprintf('%6d', subgroups);
        fprintf('\n\n');
        
        % 分析每个小组
        for k_idx = 1:length(subgroups)
            k = subgroups(k_idx);
            items_in_subgroup = find(y(:, k) > 0.5);
            fprintf('    小组 %d: %d 件商品\n', k, length(items_in_subgroup));
            
            % 显示小组内商品详情
            if ~isempty(items_in_subgroup)
                fprintf('      商品编号: ');
                for item_idx = 1:length(items_in_subgroup)
                    fprintf('%6d', items_in_subgroup(item_idx));
                end
                fprintf('\n');
            end
        end
        fprintf('\n');
    end
end

function analyze_constraints(x, y, z, data)
    % 分析约束满足情况
    % 时效一致性检查
    fprintf('时效一致性检查:\n');
    timing_violations = check_timing_consistency(x, data);
    
    % 材质多样性检查
    fprintf('材质多样性检查:\n');
    material_violations = check_material_diversity(x, data);
    
    % 易碎品约束检查
    fprintf('易碎品约束检查:\n');
    fragile_violations = check_fragile_violations_per_subgroup(y, z, data);
end

function analyze_objectives(x, y, z, data)
    % 分析优化目标达成度
    % 大组间重量差
    [weight_diff, avg_volume_diff] = calculate_weight_and_volume_differences(x, y, z, data);
    fprintf('大组间重量差: %.2f\n', weight_diff);
    fprintf('平均小组间体积差: %.2f\n', avg_volume_diff);
end

function timing_violations = check_timing_consistency(x, data)
    % 时效一致性检查
    timing_violations = [];
    G = size(x, 2);
    t = data.time_requirement(:);
    
    for g = 1:G
        items_in_group = find(x(:, g) > 0.5);
        if ~isempty(items_in_group)
            group_times = t(items_in_group);
            unique_times = unique(group_times);
            if length(unique_times) > 1
                timing_violations(end+1) = g;
                fprintf('  大组%d: 不满足 (有 %d 种时效)\n', g, length(unique_times));
            else
                fprintf('  大组%d: 满足 (只有1种时效)\n', g);
            end
        end
    end
end

function material_violations = check_material_diversity(x, data)
    % 材质多样性检查
    material_violations = [];
    G = size(x, 2);
    m = data.material(:);
    
    for g = 1:G
        items_in_group = find(x(:, g) > 0.5);
        if ~isempty(items_in_group)
            group_materials = m(items_in_group);
            unique_materials = unique(group_materials);
            if length(unique_materials) > 2
                material_violations(end+1) = g;
                fprintf('  大组%d: 不满足 (%d 种材质，超过2种)\n', g, length(unique_materials));
            else
                fprintf('  大组%d: 满足 (%d 种材质)\n', g, length(unique_materials));
            end
        end
    end
end

function fragile_violations = check_fragile_violations_per_subgroup(y, z, data)
    % 检查每个小组的易碎品约束违反情况
    fragile_violations = [];
    G = size(z, 1);
    K = size(z, 2);
    v = data.volumes(:);
    f = data.fragile_level(:);
    
    for g = 1:G
        subgroups = find(z(g, :) > 0.5);
        for k = subgroups
            items_in_subgroup = find(y(:, k) > 0.5);
            if ~isempty(items_in_subgroup) && length(items_in_subgroup) == 4
                % 计算3级易碎品体积占比
                fragile_3_items = items_in_subgroup(f(items_in_subgroup) == 3);
                if ~isempty(fragile_3_items)
                    fragile_volume = sum(v(fragile_3_items));
                    total_volume = sum(v(items_in_subgroup));
                    if total_volume > 0
                        ratio = fragile_volume / total_volume;
                        if ratio > 0.4
                            fragile_violations(end+1) = k;
                            fprintf('  大组%d-小组%d: 易碎品占比 %.2f%% (违反约束)\n', g, k, ratio*100);
                        else
                            fprintf('  大组%d-小组%d: 易碎品占比 %.2f%% (符合约束)\n', g, k, ratio*100);
                        end
                    end
                else
                    fprintf('  大组%d-小组%d: 无3级易碎品\n', g, k);
                end
            end
        end
    end
end

function [weight_diff, avg_volume_diff] = calculate_weight_and_volume_differences(x, y, z, data)
    % 计算大组间重量差和小组间体积差
    w = data.weights(:);
    v = data.volumes(:);
    
    % 计算大组总重量
    G = size(x, 2);
    group_weights = zeros(1, G);
    for g = 1:G
        items_in_group = find(x(:, g) > 0.5);
        if ~isempty(items_in_group)
            group_weights(g) = sum(w(items_in_group));
        end
    end
    
    weight_diff = max(group_weights) - min(group_weights);
    
    % 计算小组总体积
    K = size(y, 2);
    subgroup_volumes = zeros(1, K);
    for k = 1:K
        items_in_subgroup = find(y(:, k) > 0.5);
        if ~isempty(items_in_subgroup)
            subgroup_volumes(k) = sum(v(items_in_subgroup));
        end
    end
    
    % 按大组计算小组间体积差
    total_volume_diff = 0;
    valid_groups = 0;
    for g = 1:G
        subgroups = find(z(g, :) > 0.5);
        if length(subgroups) >= 2
            subgroup_vols = subgroup_volumes(subgroups);
            group_volume_diff = max(subgroup_vols) - min(subgroup_vols);
            total_volume_diff = total_volume_diff + group_volume_diff;
            valid_groups = valid_groups + 1;
        end
    end
    
    if valid_groups > 0
        avg_volume_diff = total_volume_diff / valid_groups;
    else
        avg_volume_diff = 0;
    end
end

function save_analysis_report(x, y, z, data, Q, output_dir)
    % 保存分析报告到文件
    report = struct();
    report.timestamp = datetime('now');
    report.Q = Q;
    report.total_items = data.N;
    
    % 保存约束检查结果
    report.constraints.timing = check_timing_consistency(x, data);
    report.constraints.material = check_material_diversity(x, data);
    report.constraints.fragile = check_fragile_violations_per_subgroup(y, z, data);
    
    % 保存目标函数结果
    [weight_diff, avg_volume_diff] = calculate_weight_and_volume_differences(x, y, z, data);
    report.objectives.weight_difference = weight_diff;
    report.objectives.avg_volume_difference = avg_volume_diff;
    
    % 生成唯一的报告编号
    report_number = generate_unique_report_number(output_dir);
    report.report_number = report_number;
    
    % 保存到文件
    report_filename = sprintf('analysis_report_%03d.mat', report_number);
    report_file = fullfile(output_dir, report_filename);
    save(report_file, 'report');
    
    % 保存为文本报告
    txt_filename = sprintf('analysis_report_%03d.txt', report_number);
    txt_file = fullfile(output_dir, txt_filename);
    fid = fopen(txt_file, 'w');
    if fid ~= -1
        fprintf(fid, '分组方案分析报告 #%d\n', report_number);
        fprintf(fid, '生成时间: %s\n', char(report.timestamp));
        fprintf(fid, 'Q值: %.6f\n', Q);
        fprintf(fid, '商品总数: %d\n', data.N);
        fprintf(fid, '大组间重量差: %.2f\n', weight_diff);
        fprintf(fid, '平均小组间体积差: %.2f\n', avg_volume_diff);
        fclose(fid);
    end
    
    fprintf('分析报告已保存为 #%d\n', report_number);
end

function report_number = generate_unique_report_number(output_dir)
    % 生成唯一的报告编号
    report_files = dir(fullfile(output_dir, 'analysis_report_*.mat'));
    if isempty(report_files)
        report_number = 1;
    else
        max_number = 0;
        for i = 1:length(report_files)
            % 提取文件名中的数字
            parts = regexp(report_files(i).name, 'analysis_report_(\d+)\.mat', 'once', 'tokens');
            if ~isempty(parts) && ~isempty(parts{1})
                current_number = str2double(parts{1});
                if current_number > max_number
                    max_number = current_number;
                end
            end
        end
        report_number = max_number + 1;
    end
end
