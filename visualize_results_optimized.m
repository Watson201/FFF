function visualize_results_optimized(detection_results, y_test, coarse_loc, fine_loc, loc_errors, params)
    % 优化后的分子定位系统可视化函数
    % 输入参数验证
    validateInputs(detection_results, y_test, coarse_loc, fine_loc, loc_errors, params);
    
    % 创建图形窗口
    fig = createFigure();
    
    % 计算检测性能指标
    [metrics, confusion_matrix] = calculateDetectionMetrics(detection_results, y_test);
    
    % 处理有效定位样本
    [valid_idx, localization_data] = processValidLocalizationData(y_test, detection_results, ...
        coarse_loc, fine_loc, loc_errors);
    
    % 绘制各个子图
    plotConfusionMatrix(confusion_matrix);
    plotPerformanceMetrics(metrics);
    plotLocalizationComparison(localization_data);
    plotTrueVsEstimatedPositions(localization_data, params);
    plotErrorDistribution(localization_data);
    plotSystemInformation(metrics, localization_data, params);
    
    % 添加总标题
    sgtitle('2D分子扩散沉默实体定位系统(优化版)', ...
        'FontSize', 18, 'FontWeight', 'bold');
end

function validateInputs(detection_results, y_test, coarse_loc, fine_loc, loc_errors, params)
    % 输入参数验证
    required_fields = {'M', 'D', 'T_total', 'dt', 'rx_radius', 'eve_radius', 'test_samples'};
    for i = 1:length(required_fields)
        if ~isfield(params, required_fields{i})
            error('参数结构体缺少必需字段: %s', required_fields{i});
        end
    end
    
    % 检查数据维度一致性
    if length(detection_results) ~= size(y_test, 1)
        error('检测结果和测试标签长度不一致');
    end
    
    if size(coarse_loc, 1) ~= size(fine_loc, 1)
        error('粗定位和精定位数据长度不一致');
    end
end

function fig = createFigure()
    % 创建标准化的图形窗口
    fig = figure('Position', [50, 50, 1600, 1000], ...
        'Name', '分子扩散EVE定位系统(优化版)', ...
        'NumberTitle', 'off', ...
        'Color', 'white');
    set(fig, 'Units', 'normalized');
end

function [metrics, confusion_matrix] = calculateDetectionMetrics(detection_results, y_test)
    % 计算检测性能指标
    true_det = (y_test(:, 1) == 1);
    pred_det = detection_results;
    
    % 计算混淆矩阵元素
    TN = sum(~true_det & ~pred_det);
    FP = sum(~true_det & pred_det);
    FN = sum(true_det & ~pred_det);
    TP = sum(true_det & pred_det);
    
    % 存储混淆矩阵
    confusion_matrix = struct('TN', TN, 'FP', FP, 'FN', FN, 'TP', TP);
    
    % 计算性能指标
    total_samples = length(true_det);
    metrics = struct();
    metrics.accuracy = (TP + TN) / total_samples;
    metrics.precision = TP / max(TP + FP, 1);
    metrics.recall = TP / max(TP + FN, 1);
    metrics.f1 = 2 * metrics.precision * metrics.recall / max(metrics.precision + metrics.recall, eps);
    metrics.TP = TP; metrics.TN = TN; metrics.FP = FP; metrics.FN = FN;
end

function [valid_idx, localization_data] = processValidLocalizationData(y_test, detection_results, ...
    coarse_loc, fine_loc, loc_errors)
    % 处理有效定位数据
    true_det = (y_test(:, 1) == 1);
    pred_det = detection_results;
    valid_idx = true_det & pred_det;
    
    localization_data = struct();
    localization_data.has_valid_data = sum(valid_idx) > 0;
    
    if localization_data.has_valid_data
        % 计算粗定位误差
        localization_data.coarse_err = sqrt(sum((coarse_loc(valid_idx, :) - y_test(valid_idx, 2:3)).^2, 2));
        localization_data.fine_err = loc_errors(valid_idx);
        
        % 过滤有效数据
        valid_mask = localization_data.fine_err > 0 & ~isnan(localization_data.fine_err) & ...
                    localization_data.coarse_err > 0 & ~isnan(localization_data.coarse_err);
        
        localization_data.valid_mask = valid_mask;
        localization_data.coarse_err_filtered = localization_data.coarse_err(valid_mask);
        localization_data.fine_err_filtered = localization_data.fine_err(valid_mask);
        
        % 真实位置和估计位置
        localization_data.true_pos = y_test(valid_idx, 2:3);
        localization_data.fine_pos = fine_loc(valid_idx, :);
    else
        localization_data.coarse_err = [];
        localization_data.fine_err = [];
        localization_data.valid_mask = [];
        localization_data.coarse_err_filtered = [];
        localization_data.fine_err_filtered = [];
        localization_data.true_pos = [];
        localization_data.fine_pos = [];
    end
end

function plotConfusionMatrix(confusion_matrix)
    % 绘制混淆矩阵
    subplot(2, 3, 1);
    cm = [confusion_matrix.TN, confusion_matrix.FP; 
          confusion_matrix.FN, confusion_matrix.TP];
    
    imagesc(cm);
    colormap(gca, parula);
    
    % 添加数值标签
    for i = 1:2
        for j = 1:2
            text(j, i, num2str(cm(i,j)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', 16, 'FontWeight', 'bold', ...
                'Color', 'white');
        end
    end
    
    title('检测混淆矩阵', 'FontSize', 14, 'FontWeight', 'bold');
    xlabel('预测类别');
    ylabel('真实类别');
    set(gca, 'XTick', [1, 2], 'XTickLabel', {'无EVE', '有EVE'});
    set(gca, 'YTick', [1, 2], 'YTickLabel', {'无EVE', '有EVE'});
    axis equal; axis tight;
    colorbar;
end

function plotPerformanceMetrics(metrics)
    % 绘制性能指标
    subplot(2, 3, 2);
    values = [metrics.accuracy, metrics.precision, metrics.recall, metrics.f1];
    labels = {'准确率', '精确率', '召回率', 'F1分数'};
    
    % 使用更现代的颜色方案
    bar_colors = lines(4);
    h = bar(values);
    h.FaceColor = 'flat';
    h.CData = bar_colors;
    
    set(gca, 'XTickLabel', labels);
    ylabel('分数');
    title('检测性能指标', 'FontSize', 14, 'FontWeight', 'bold');
    ylim([0, 1]);
    grid on;
    
    % 添加数值标签
    for i = 1:length(values)
        text(i, values(i) + 0.02, sprintf('%.3f', values(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
    end
end

function plotLocalizationComparison(localization_data)
    % 绘制定位误差对比
    subplot(2, 3, 3);
    
    if localization_data.has_valid_data && ~isempty(localization_data.coarse_err_filtered) && ...
       ~isempty(localization_data.fine_err_filtered)
        
        min_len = min(length(localization_data.coarse_err_filtered), ...
                     length(localization_data.fine_err_filtered));
        data = [localization_data.coarse_err_filtered(1:min_len), ...
                localization_data.fine_err_filtered(1:min_len)];
        
        boxplot(data, 'Labels', {'粗定位', '精定位'}, 'Colors', [0.8 0.2 0.2; 0.2 0.2 0.8]);
        title('定位误差对比', 'FontSize', 14, 'FontWeight', 'bold');
        ylabel('误差 (μm)');
        grid on;
    else
        text(0.5, 0.5, '无足够数据进行误差对比', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'Units', 'normalized', 'FontSize', 12);
        title('定位误差对比', 'FontSize', 14, 'FontWeight', 'bold');
    end
end

function plotTrueVsEstimatedPositions(localization_data, params)
    % 绘制真实位置vs估计位置
    subplot(2, 3, 4);
    
    if localization_data.has_valid_data
        % 绘制真实位置
        scatter(localization_data.true_pos(:,1), localization_data.true_pos(:,2), ...
            100, 'ro', 'filled', 'DisplayName', '真实位置', ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
        hold on;
        
        % 绘制估计位置
        scatter(localization_data.fine_pos(:,1), localization_data.fine_pos(:,2), ...
            80, 'bx', 'LineWidth', 3, 'DisplayName', '精定位位置');
        
        % 绘制连接线
        for i = 1:size(localization_data.true_pos, 1)
            plot([localization_data.true_pos(i,1), localization_data.fine_pos(i,1)], ...
                 [localization_data.true_pos(i,2), localization_data.fine_pos(i,2)], ...
                 'k--', 'LineWidth', 1, 'Alpha', 0.6);
        end
        
        % 绘制TX和RX位置
        if isfield(params, 'tx_pos') && isfield(params, 'rx_pos')
            plot(params.tx_pos(1), params.tx_pos(2), 'ks', 'MarkerSize', 15, ...
                'MarkerFaceColor', 'k', 'DisplayName', 'TX');
            
            % 绘制RX圆圈
            theta_circle = linspace(0, 2*pi, 100);
            if isfield(params, 'rx_radius')
                rx_x = params.rx_pos(1) + params.rx_radius * cos(theta_circle);
                rx_y = params.rx_pos(2) + params.rx_radius * sin(theta_circle);
                plot(rx_x, rx_y, 'g-', 'LineWidth', 2);
            end
            
            plot(params.rx_pos(1), params.rx_pos(2), 'gs', 'MarkerSize', 15, ...
                'MarkerFaceColor', 'g', 'DisplayName', 'RX');
        end
        
        xlabel('X (μm)');
        ylabel('Y (μm)');
        title('真实位置 vs 精定位位置', 'FontSize', 14, 'FontWeight', 'bold');
        legend('Location', 'best');
        axis equal;
        grid on;
        
        % 设置坐标轴范围
        if isfield(params, 'x_range') && isfield(params, 'y_range')
            xlim([params.x_range(1)-1, params.x_range(2)+1]);
            ylim([params.y_range(1)-1, params.y_range(2)+1]);
        end
    else
        text(0.5, 0.5, '无有效定位样本', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'Units', 'normalized', 'FontSize', 12);
        title('真实位置 vs 精定位位置', 'FontSize', 14, 'FontWeight', 'bold');
    end
end

function plotErrorDistribution(localization_data)
    % 绘制误差分布直方图
    subplot(2, 3, 5);
    
    if localization_data.has_valid_data && ~isempty(localization_data.fine_err_filtered)
        histogram(localization_data.fine_err_filtered, 'BinMethod', 'auto', ...
            'FaceColor', [0.3 0.7 0.9], 'EdgeColor', 'k', 'FaceAlpha', 0.7);
        xlabel('定位误差 (μm)');
        ylabel('频次');
        title('精定位误差分布', 'FontSize', 14, 'FontWeight', 'bold');
        grid on;
        
        % 添加统计信息
        mean_err = mean(localization_data.fine_err_filtered);
        std_err = std(localization_data.fine_err_filtered);
        
        text(0.7, 0.8, sprintf('均值: %.2f μm\n标准差: %.2f μm', mean_err, std_err), ...
            'Units', 'normalized', 'FontSize', 10, ...
            'BackgroundColor', 'white', 'EdgeColor', 'k', ...
            'VerticalAlignment', 'middle');
    else
        text(0.5, 0.5, '无有效定位误差数据', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'Units', 'normalized', 'FontSize', 12);
        title('精定位误差分布', 'FontSize', 14, 'FontWeight', 'bold');
    end
end

function plotSystemInformation(metrics, localization_data, params)
    % 绘制系统参数信息
    subplot(2, 3, 6);
    axis off;
    
    % 构建参数信息文本
    param_text = buildParameterText(params, metrics, localization_data);
    
    text(0.05, 0.95, param_text, 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'FontSize', 9, ...
        'FontName', 'FixedWidth');
end

function param_text = buildParameterText(params, metrics, localization_data)
    % 构建参数信息文本
    param_text = sprintf('系统参数(优化版)\n\n');
    param_text = [param_text sprintf('分子数量: %d\n', params.M)];
    param_text = [param_text sprintf('扩散系数: %.1f μm²/s\n', params.D)];
    param_text = [param_text sprintf('仿真时间: %.1f s\n', params.T_total)];
    param_text = [param_text sprintf('时间步长: %.0e s\n', params.dt)];
    param_text = [param_text sprintf('RX半径: %.1f μm\n', params.rx_radius)];
    param_text = [param_text sprintf('EVE半径: %.1f μm\n', params.eve_radius)];
    param_text = [param_text sprintf('测试样本数: %d\n', params.test_samples)];
    
    % 添加检测结果
    param_text = [param_text sprintf('\n检测结果\n')];
    param_text = [param_text sprintf('正确检测: %d/%d\n', metrics.TP+metrics.TN, metrics.TP+metrics.TN+metrics.FP+metrics.FN)];
    param_text = [param_text sprintf('误报: %d\n', metrics.FP)];
    param_text = [param_text sprintf('漏报: %d\n', metrics.FN)];
    
    % 添加定位性能
    if localization_data.has_valid_data && ~isempty(localization_data.fine_err_filtered)
        param_text = [param_text sprintf('\n定位性能\n')];
        param_text = [param_text sprintf('平均误差: %.2f μm\n', mean(localization_data.fine_err_filtered))];
        param_text = [param_text sprintf('误差标准差: %.2f μm\n', std(localization_data.fine_err_filtered))];
        param_text = [param_text sprintf('最小误差: %.2f μm\n', min(localization_data.fine_err_filtered))];
        param_text = [param_text sprintf('最大误差: %.2f μm\n', max(localization_data.fine_err_filtered))];
    end
end
