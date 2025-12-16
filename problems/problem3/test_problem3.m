% 测试脚本：验证problem3_sover修复是否成功
fprintf('开始测试problem3_sover脚本...\n');
try
    % 确保项目路径在搜索路径中
    project_root = fullfile('d:', 'MATLAB', 'projects', '海外仓多约束规划_problem1');
    if ~exist(project_root, 'dir')
        error('项目路径不存在: %s', project_root);
    end
    
    % 添加项目路径
    addpath(genpath(project_root));
    fprintf('已添加项目路径到MATLAB搜索路径\n');
    
    % 直接运行问题三求解器，指定阶段1
    fprintf('执行problem3_sover脚本，求解阶段1...\n');
    problem3_sover(1);  % 传入1表示执行阶段1
    
    fprintf('\n测试成功！problem3_sover脚本执行完成\n');
catch ME
    fprintf('\n测试失败！错误信息：\n');
    fprintf('%s\n', ME.message);
    fprintf('错误堆栈：\n');
    fprintf('%s\n', ME.stack);
end

% 清理搜索路径
rmpath(genpath(project_root));
fprintf('\n已清理添加的搜索路径\n');