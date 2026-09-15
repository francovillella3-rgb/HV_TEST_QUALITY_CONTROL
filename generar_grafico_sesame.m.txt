function generar_grafico_sesame(f, HV, HVmin, HVmax, f0, A0, veredicto, claridad, nombre, carp)
% VERSION MEJORADA DEL GRAFICO HVSR - MISMA INTERFAZ

    f = f(:);
    HV = HV(:);
    HVmin = HVmin(:);
    HVmax = HVmax(:);

    valido = isfinite(f) & isfinite(HV) & isfinite(HVmin) & isfinite(HVmax) & (f > 0);
    f = f(valido);
    HV = HV(valido);
    HVmin = HVmin(valido);
    HVmax = HVmax(valido);

    if isempty(f)
        error('No hay datos validos para generar el grafico de %s.', nombre);
    end

    [f, ind] = sort(f);
    HV = HV(ind);
    HVmin = HVmin(ind);
    HVmax = HVmax(ind);

    f_inf = 0.5 * f0;
    f_sup = 2.0 * f0;

    ymax_datos = max([HVmax(:); HV(:); HVmin(:); A0]);
    if ~isfinite(ymax_datos) || ymax_datos <= 0
        ymax_datos = 1;
    end

    y_top = ymax_datos * 1.20;
    y_limits = [0 y_top];

    fig = figure('visible', 'off', ...
                 'Color', 'w', ...
                 'Position', [100 100 1400 850]);

    ax = axes('Parent', fig, ...
              'Position', [0.105 0.145 0.79 0.68]);

    hold(ax, 'on');
    grid(ax, 'on');
    box(ax, 'on');

    % La banda se dibuja primero: queda detras de las curvas.
    if f_inf < max(f) && f_sup > min(f)
        patch(ax, ...
              [max(f_inf,min(f)) max(f_inf,min(f)) min(f_sup,max(f)) min(f_sup,max(f))], ...
              [y_limits(1) y_limits(2) y_limits(2) y_limits(1)], ...
              'w', 'FaceAlpha', 0.08, 'EdgeColor', 'none');
    end

    h1 = plot(ax, [f_inf f_inf], y_limits, '--', 'LineWidth', 1.2);
    h2 = plot(ax, [f_sup f_sup], y_limits, '--', 'LineWidth', 1.2);

    h3 = plot(ax, f, HVmin, '--', 'LineWidth', 1.0);
    h4 = plot(ax, f, HVmax, '--', 'LineWidth', 1.0);
    h5 = plot(ax, f, HV, '-', 'LineWidth', 2.0);

    h6 = plot(ax, [f0 f0], [0 A0], '-', 'LineWidth', 1.5);
    plot(ax, f0, A0, 'o', 'MarkerSize', 6, 'LineWidth', 1.2);

    set(ax, 'XScale', 'log');
    xlim(ax, [min(f) max(f)]);
    ylim(ax, y_limits);

    xlabel(ax, 'Frecuencia (Hz)', 'FontWeight', 'bold');
    ylabel(ax, 'Amplitud H/V', 'FontWeight', 'bold');

    titulo = sprintf('Curva HVSR: %s | f_0 = %.2f Hz | A_0 = %.2f | %s | Claridad: %d/6', ...
                     nombre, f0, A0, veredicto, claridad);
    title(ax, titulo, 'FontWeight', 'bold');

    legend(ax, [h1 h2 h3 h4 h5 h6], ...
           {'0.5f_0', '2f_0', 'H/V Min', 'H/V Max', 'H/V Promedio', ...
            ['f_0 = ' num2str(f0, '%.2f') ' Hz']}, ...
           'Location', 'northoutside', ...
           'Orientation', 'horizontal', ...
           'Box', 'on');

    try
        ti = get(ax, 'TightInset');
        set(ax, 'LooseInset', max(ti, [0.02 0.02 0.02 0.02]));
    catch
    end

    nombre_img = strrep(nombre, '.hv', '_SESAME.png');
    ruta_guardado = fullfile(carp, nombre_img);

    set(fig, 'PaperPositionMode', 'auto');
    drawnow;
    print(fig, ruta_guardado, '-dpng', '-r180');

    close(fig);
    clear fig;
end
