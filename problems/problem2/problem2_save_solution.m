% filepath: d:\VScodeprojects\overseas_warehouse_optimization\src\problems\problem2_save_solution.m
function problem2_save_solution(solution, filename)
% problem2_save_solution 保存求解结果（默认路径 output/solutions/solution_problem2.mat）
if nargin < 2 || isempty(filename)
   filename = 'D:\MATLAB\projects\海外仓多约束规划_problem1\output\solutions\solution_problem2.mat';
end
% 确保目录存在
d = fileparts(filename);
if ~exist(d,'dir'), mkdir(d); end
save(filename, '-struct', 'solution');
fprintf('已保存解到 %s\n', filename);
end