% filepath: d:\VScodeprojects\overseas_warehouse_optimization\src\problems\problem2_varmap.m
function [x,y,z] = problem2_varmap(vec, I, G, K_total)
% problem2_varmap 将一维决策向量映射为矩阵变量 x,y,z
%  输入:
%    vec      - 列向量，顺序为 [vec_x; vec_y; vec_z]
%    I        - 商品数
%    G        - 大组数 (期望6)
%    K_total  - 小组总数 (期望18)
%  输出:
%    x (I x G), y (I x K_total), z (G x K_total)
if nargin < 4, error('需要 vec, I, G, K_total'); end
len_x = I * G;
len_y = I * K_total;
len_z = G * K_total;
if numel(vec) ~= (len_x + len_y + len_z)
    error('vec 长度与 I,G,K_total 不匹配：期望 %d，实际 %d', len_x+len_y+len_z, numel(vec));
end

p = 1;
vx = reshape(vec(p:p+len_x-1), [I, G]); p = p + len_x;
vy = reshape(vec(p:p+len_y-1), [I, K_total]); p = p + len_y;
vz = reshape(vec(p:p+len_z-1), [G, K_total]);

x = double(vx);
y = double(vy);
z = double(vz);
end