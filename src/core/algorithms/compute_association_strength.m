

% filepath: d:\VScodeprojects\overseas_warehouse_optimization\src\core\algorithms\compute_association_strength.m
function A = compute_association_strength(data, packages, params)
% compute_association_strength 计算 package 级别的关联强度矩阵（只处理 package-level）
% 输入:
%   data     - 原始数据结构（用于访问商品级属性，如 customs_category）
%   packages - create_packages 输出的 packages 结构体（必须包含 .list 与 .attrs）
%   params   - 可选参数（w_customs, w_material, w_time）
% 输出:
%   A - P x P 的关联强度矩阵（包级别）
%
% 说明：本函数期望以 package 为基本单元进行计算（不再支持直接传入 item-level 矩阵）。
if nargin < 3, params = struct(); end
w_declare = getfieldwithdefault(params,'w_customs',10);
w_mat = getfieldwithdefault(params,'w_material',5);
w_time = getfieldwithdefault(params,'w_time',3);

if ~isfield(packages,'list')
    error('packages 必须包含字段 list');
end

P = numel(packages.list);
A = zeros(P,P);

    % 双重循环实现（若 P 很大可改为向量化实现以提高性能）
for p1 = 1:P
    items1 = packages.list{p1}(:);
    for p2 = p1+1:P
        items2 = packages.list{p2}(:);
        score = 0;
        % 报关类别比较：只要两个包有任意相同的报关类别则加分
        if isfield(data,'customs_category') && ~isempty(items1) && ~isempty(items2)
            cs1 = data.customs_category(items1);
            cs2 = data.customs_category(items2);
            if ~isempty(intersect(cs1,cs2))
                score = score + w_declare;
            end
        end
        % 材质相同
        if ~isempty(intersect(packages.attrs(p1).material, packages.attrs(p2).material))
            score = score + w_mat;
        end
        % 时效相同
        if ~isempty(intersect(packages.attrs(p1).time, packages.attrs(p2).time))
            score = score + w_time;
        end
        A(p1,p2) = score;
        A(p2,p1) = score;
    end
end

A = A + eye(P) * (max([w_declare, w_mat, w_time]) * 2);

end



% function v = getfieldwithdefault(s,name,def)
% %也有问题
% if isfield(s,name), v = s.(name);
% else 
%     v = def; 
% end
% end