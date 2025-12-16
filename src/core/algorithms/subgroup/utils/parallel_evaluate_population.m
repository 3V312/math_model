function fitness = parallel_evaluate_population(population, eval_func, popsize)
    % PARALLEL_EVALUATE_POPULATION 并行评估种群中所有个体
    % 输入:
    %   population - 种群矩阵
    %   eval_func - 评估函数句柄
    %   popsize - 种群大小
    % 输出:
    %   fitness - 适应度值向量
    
    fitness = zeros(popsize, 1);
    
    % 检查是否可以使用并行计算
    try
        % 检查并行池是否已启动
        if isempty(gcp('nocreate')) == 0
            % 使用并行计算
            parfor i = 1:popsize
                fitness(i) = eval_func(population(i, :));
            end
        else
            % 串行计算
            for i = 1:popsize
                fitness(i) = eval_func(population(i, :));
            end
        end
    catch
        % 如果并行计算失败，回退到串行计算
        for i = 1:popsize
            fitness(i) = eval_func(population(i, :));
        end
    end
end
