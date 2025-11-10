% 测试优化后的可视化函数
% 生成模拟数据用于测试

function test_visualization()
    % 生成模拟参数
    params = struct();
    params.M = 1000;                    % 分子数量
    params.D = 2.5;                      % 扩散系数 (μm²/s)
    params.T_total = 10.0;               % 仿真时间 (s)
    params.dt = 0.01;                    % 时间步长 (s)
    params.rx_radius = 50.0;             % RX半径 (μm)
    params.eve_radius = 5.0;             % EVE半径 (μm)
    params.test_samples = 200;           % 测试样本数
    
    % 设置位置参数
    params.tx_pos = [0, 0];              % TX位置
    params.rx_pos = [100, 100];          % RX位置
    params.x_range = [-50, 150];         % X范围
    params.y_range = [-50, 150];         % Y范围
    
    % 生成模拟测试数据
    [y_test, detection_results, coarse_loc, fine_loc, loc_errors] = generateSimulatedData(params);
    
    % 测试优化后的可视化函数
    try
        fprintf('开始测试优化后的可视化函数...\n');
        visualize_results_optimized(detection_results, y_test, coarse_loc, fine_loc, loc_errors, params);
        fprintf('可视化函数测试成功！\n');
    catch ME
        fprintf('测试失败：%s\n', ME.message);
        fprintf('错误位置：%s (第%d行)\n', ME.stack(1).name, ME.stack(1).line);
    end
end

function [y_test, detection_results, coarse_loc, fine_loc, loc_errors] = generateSimulatedData(params)
    % 生成模拟的测试数据
    
    n_samples = params.test_samples;
    
    % 生成真实标签 (1表示有EVE，0表示无EVE)
    % 假设70%的样本有EVE
    y_test = zeros(n_samples, 3);
    y_test(:,1) = rand(n_samples,1) < 0.7;  % 第一列：是否有EVE
    
    % 为有EVE的样本生成真实位置
    eve_indices = find(y_test(:,1) == 1);
    n_eve = length(eve_indices);
    
    if n_eve > 0
        % 在RX周围生成随机位置
        angles = rand(n_eve, 1) * 2 * pi;
        distances = rand(n_eve, 1) * params.rx_radius * 0.8;  % 在RX半径80%范围内
        
        y_test(eve_indices, 2) = params.rx_pos(1) + distances .* cos(angles);
        y_test(eve_indices, 3) = params.rx_pos(2) + distances .* sin(angles);
    end
    
    % 生成检测结果（添加一些检测错误）
    detection_results = y_test(:,1);
    
    % 添加10%的误报和漏报
    error_rate = 0.1;
    n_errors = round(n_samples * error_rate);
    
    % 随机选择一些样本进行错误检测
    error_indices = randperm(n_samples, min(n_errors, n_samples));
    detection_results(error_indices) = ~detection_results(error_indices);
    
    % 生成定位结果
    coarse_loc = zeros(n_samples, 2);
    fine_loc = zeros(n_samples, 2);
    loc_errors = zeros(n_samples, 1);
    
    if n_eve > 0
        % 为正确检测的EVE样本生成定位结果
        correctly_detected = eve_indices(detection_results(eve_indices) == 1);
        n_correct = length(correctly_detected);
        
        if n_correct > 0
            % 粗定位：添加较大误差
            coarse_error_std = 20;  % μm
            coarse_loc(correctly_detected, :) = y_test(correctly_detected, 2:3) + ...
                randn(n_correct, 2) * coarse_error_std;
            
            % 精定位：添加较小误差
            fine_error_std = 5;     % μm
            fine_loc(correctly_detected, :) = y_test(correctly_detected, 2:3) + ...
                randn(n_correct, 2) * fine_error_std;
            
            % 计算定位误差
            loc_errors(correctly_detected) = sqrt(sum((fine_loc(correctly_detected, :) - ...
                y_test(correctly_detected, 2:3)).^2, 2));
        end
    end
    
    % 为没有EVE或检测错误的样本设置默认值
    no_eve_indices = setdiff(1:n_samples, eve_indices);
    false_positives = setdiff(eve_indices(detection_results(eve_indices) == 1), correctly_detected);
    
    all_invalid = [no_eve_indices; false_positives];
    if ~isempty(all_invalid)
        coarse_loc(all_invalid, :) = NaN;
        fine_loc(all_invalid, :) = NaN;
        loc_errors(all_invalid) = NaN;
    end
end

% 运行测试
if ~exist('OCTAVE_VERSION', 'builtin')  % MATLAB环境
    test_visualization();
else
    fprintf('请在MATLAB环境中运行此测试脚本\n');
end
