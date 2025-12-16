% filepath: d:\VScodeprojects\overseas_warehouse_optimization\tests\test_load_data.m
classdef test_load_data < matlab.unittest.TestCase
    methods(Test)
        function testPrintSample(testCase)
            % 确保函数文件所在路径可用
            addpath(fullfile(pwd,'src','utils'));
            
            % 调用被测函数（使用默认路径）
            data = load_data();
            
            % 基本断言：数量与字段类型
            testCase.verifyGreaterThan(data.N, 0, '应读取到至少一条商品数据');
            testCase.verifyEqual(numel(data.weights), data.N);
            testCase.verifyTrue(isnumeric(data.weights));
            testCase.verifyTrue(isnumeric(data.volumes));
            testCase.verifyTrue(isnumeric(data.material));
            testCase.verifyTrue(isnumeric(data.fragile_level));
            testCase.verifyTrue(isnumeric(data.customs_category));
            testCase.verifyTrue(isnumeric(data.time_requirement));
            
            % 打印第一个商品的信息（可根据需要改为其他索引）
            idx = 1;
            fprintf('商品 %d 信息：重量=%.3f，体积=%.3f，材质=%d，易碎=%d，报关=%d，时效=%d\n', ...
                idx, data.weights(idx), data.volumes(idx), data.material(idx), ...
                data.fragile_level(idx), data.customs_category(idx), data.time_requirement(idx));
        end
    end
end