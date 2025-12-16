function data = load_problem3_data()
% 加载问题三数据
    try
        % 定义数据文件路径
        data_path = 'd:\MATLAB\projects\海外仓多约束规划_problem1\data\raw\附件1：商品属性数据.xlsx';
        
        % 检查文件是否存在
        if ~exist(data_path, 'file')
            error('数据文件不存在: %s', data_path);
        end
        
        % 读取Excel数据（A2:G81范围）
        [~, ~, raw_data] = xlsread(data_path, 'A2:G81');
        
        % 初始化数据结构
        data = struct();
        data.N = size(raw_data, 1);  % 商品数量
        
        % 提取数据
        data.weights = cell2mat(raw_data(:, 2));  % 重量 (kg)
        data.volumes = cell2mat(raw_data(:, 3));   % 体积 (dm³)
        data.material = cell2mat(raw_data(:, 4));  % 材质 (1, 2, 3)
        data.fragile_level = cell2mat(raw_data(:, 5));  % 易碎等级 (确保1-3级)
        
        % 过滤易碎等级，确保只有1-3级
        invalid_fragile = data.fragile_level < 1 | data.fragile_level > 3;
        if any(invalid_fragile)
            warning('检测到无效的易碎等级，已过滤为有效值');
            data.fragile_level(invalid_fragile) = 1;  % 将无效值设为1级
        end
        
        % 创建易碎品标志向量（易碎等级为3的商品）
        data.fragile = data.fragile_level == 3;
        
        % 处理时效需求（T1->1, T2->2）
        time_req_cell = raw_data(:, 6);
        data.time_requirement = zeros(data.N, 1);
        for i = 1:data.N
            if ischar(time_req_cell{i}) || isstring(time_req_cell{i})
                time_str = lower(char(time_req_cell{i}));
                if contains(time_str, 't1')
                    data.time_requirement(i) = 1;
                elseif contains(time_str, 't2')
                    data.time_requirement(i) = 2;
                else
                    data.time_requirement(i) = 2;  % 默认T2
                end
            else
                data.time_requirement(i) = 2;  % 默认T2
            end
        end
        
        % 处理报关类别
        data.customs_type = raw_data(:, 7);  % 保留原始报关类别 (A, B, C)
        
        fprintf('成功加载 %d 个商品的实际数据\n', data.N);
        
    catch ME
        error('load_problem3_data: LoadFailed', '数据加载失败: %s', ME.message);
    end
end