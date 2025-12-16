% filepath: d:\MATLAB\projects\海外仓多约束规划_problem1\src\core\algorithms\create_packages.m
function packages = create_packages(data, params, problem_type)
% create_packages 基于规则把商品打包（粗化）
% 规则:
% - 问题2: 所有商品单个打包，保持包的数据结构
% - 问题3: 实现易碎品配对打包逻辑（f3与f2配对）
% 输入:
%  data: load_data 返回的结构体
%  params: 可选参数结构体，包含打包策略和其他配置
%  problem_type: 问题类型（2或3，默认为2）
% 输出 packages 结构体:
%  .list: cell array of item index vectors（每个cell包含包中的商品索引）
%  .map: item->package id 映射数组
%  .weights: 每个包的总重量
%  .volumes: 每个包的总体积
%  .attrs: 每个包的属性信息（材质、易碎等级、时效需求）

% 参数验证与初始化
if nargin < 1 || ~isstruct(data)
    error('create_packages: 必须提供有效的数据结构体');
end

if nargin < 2 || isempty(params)
    params = struct();
end

if nargin < 3 || ~ismember(problem_type, [2, 3])
    problem_type = 2; % 默认问题类型为2
    fprintf('未指定问题类型，默认使用问题2模式\n');
end

% 提取必要的数据
w = data.weights(:);
v = data.volumes(:);
f = data.fragile_level(:);
N = data.N;

% 初始化packages结构体
packages = struct();
packages.list = {};

% 根据问题类型选择打包策略
fprintf('创建包 - 问题%d模式\n', problem_type);

if problem_type == 2
    % 问题2：所有商品单个打包
    % 保持单个商品作为一个包的结构，确保与现有代码兼容
    fprintf('问题2模式：创建 %d 个单商品包\n', N);
    
    for i = 1:N
        packages.list{end+1} = i;
    end
    
elseif problem_type == 3
    % 问题3：易碎品配对打包逻辑（f3与f2配对）
    fprintf('问题3模式：使用易碎品配对打包逻辑\n');
    paired = false(N,1);
    
    % 找到所有易碎品商品
    idx3 = find(f==3); % 3级易碎品
    idx2 = find(f==2); % 2级易碎品

    % 优化配对策略：优先处理大体积的f3商品
    if ~isempty(idx3)
        [~, idx3_sorted] = sort(v(idx3), 'descend');
        idx3 = idx3(idx3_sorted);
    end

    % 贪心配对算法：将f3与体积最大的可用f2配对
    for i = 1:numel(idx3)
        ii = idx3(i);
        if paired(ii), continue; end % 跳过已配对的商品
        
        candidates = idx2(~paired(idx2));
        if isempty(candidates), continue; end
        
        % 体积互补逻辑：优先选择体积较大的f2作为更好的缓冲
        [~, idmax] = max(v(candidates));
        jj = candidates(idmax);
        
        % 创建配对包 [f3, f2]
        packages.list{end+1} = [ii; jj];
        paired(ii) = true;
        paired(jj) = true;
        
        % 移除已配对的f2，避免被其他f3重复选择
        idx2(idx2 == jj) = [];
    end

    % 其余未配对的商品作为单包
    for i = 1:N
        if ~paired(i)
            packages.list{end+1} = i;
        end
    end
end

% 创建包属性信息
P = numel(packages.list);
packages.map = zeros(N, 1);         % 商品到包的映射
packages.weights = zeros(P, 1);      % 每个包的总重量
packages.volumes = zeros(P, 1);      % 每个包的总体积
packages.attrs = struct('material', [], 'fragile', [], 'time', []);

% 预分配attrs数组以提高效率
packages.attrs(P) = struct('material', [], 'fragile', [], 'time', []);

% 填充包的属性信息
for p = 1:P
    items = packages.list{p}(:);
    packages.map(items) = p;
    packages.weights(p) = sum(w(items));
    packages.volumes(p) = sum(v(items));
    
    % 安全地获取包的属性信息
    if isfield(data, 'material')
        packages.attrs(p).material = unique(data.material(items));
    end
    if isfield(data, 'fragile_level')
        packages.attrs(p).fragile = unique(data.fragile_level(items));
    end
    if isfield(data, 'time_requirement')
        packages.attrs(p).time = unique(data.time_requirement(items));
    end
end

fprintf('打包完成，共创建 %d 个包\n', P);
end