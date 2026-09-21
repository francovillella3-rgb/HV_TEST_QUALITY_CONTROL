function SESAME_TESTHV()
%% ================================================================
%  EVALUACION AUTOMATICA DE CRITERIOS SESAME - HVSR / GEOPSY
%  VERSION CON DETECCION AUTOMATICA DE PICOS MULTIPLES
% ================================================================
clc;
close all force;
graphics_toolkit('gnuplot');

fprintf('\n============================================================\n');
fprintf('   SESAME - EVALUACION AUTOMATICA + DETECCION MULTI-PICO\n');
fprintf('============================================================\n');

carpeta = 'D:\Users\Datos\Datos frecuencia\Datos Procesados';
LW_SECONDS = 50;
archivo_salida = fullfile(carpeta, 'Resultados_SESAME.csv');
carpeta_graficos = fullfile(carpeta, 'Graficos_SESAME');

% --- Parametros de deteccion de picos candidatos ---
MIN_AMPLITUD       = 1.2;   % amplitud H/V minima para considerar un pico
MIN_PROMINENCIA    = 0.10;  % el pico debe superar en 10% al valle mas cercano
MIN_SEPARACION_OCT = 0.25;  % separacion minima entre picos, en octavas (log2)

addpath(carpeta);
if ~exist(carpeta_graficos, 'dir'), mkdir(carpeta_graficos); end
fprintf('\nLongitud de ventana utilizada: %.2f s\n', LW_SECONDS);

archivos = dir(fullfile(carpeta, '*.hv'));
if isempty(archivos), error('No se encontraron archivos .hv.'); end
fprintf('Archivos .hv encontrados: %d\n\n', length(archivos));
resultados = {};

for i = 1:length(archivos)
    nombre_hv = archivos(i).name;
    ruta_hv = fullfile(carpeta, nombre_hv);
    fprintf('------------------------------------------------------------\n');
    fprintf('Procesando %d/%d : %s\n', i, length(archivos), nombre_hv);
    fprintf('------------------------------------------------------------\n');

    try
        datos = leer_HV(nombre_hv, ruta_hv);
        f0_geopsy = datos.f0; A0_geopsy = datos.A0; Nw = datos.Nw;
        sigma_f = datos.sigma_f;
        frecuencia = datos.frecuencia; HV = datos.HV; HVmin = datos.HVmin; HVmax = datos.HVmax;

        if isnan(f0_geopsy) || isnan(A0_geopsy) || isnan(Nw) || isempty(frecuencia)
            error('Datos basicos incompletos en el archivo .hv.');
        end

        % --- Deteccion de todos los picos candidatos en la curva promedio ---
        candidatos = detectar_picos(frecuencia, HV, MIN_AMPLITUD, MIN_PROMINENCIA, MIN_SEPARACION_OCT);

        % Asegurar que el pico picado manualmente en Geopsy siempre este incluido,
        % aunque el filtro automatico no lo hubiera detectado como "prominente".
        idx_principal = find(abs([candidatos.f0] - f0_geopsy) / f0_geopsy < 0.03, 1);
        if isempty(idx_principal)
            candidatos(end+1).f0 = f0_geopsy;
            candidatos(end).A0   = A0_geopsy;
            idx_principal = numel(candidatos);
        end

        fprintf('Picos candidatos detectados: %d\n', numel(candidatos));

        for c = 1:numel(candidatos)
            f0 = candidatos(c).f0;
            A0 = candidatos(c).A0;
            es_principal = (c == idx_principal);

            limite_frecuencia = 10 / LW_SECONDS;
            C1 = f0 > limite_frecuencia;
            nc = LW_SECONDS * Nw * f0;
            C2 = nc > 200;

            [C3, estado_C3, sigmaA_max] = criterio_estabilidad(frecuencia, HV, HVmin, HVmax, f0);
            curva_confiable = C1 && C2 && C3;

            claridad = false(1,6);
            [claridad(1), estado1] = criterio_existencia(frecuencia, HV, f0/4, f0, A0/2);
            [claridad(2), estado2] = criterio_existencia(frecuencia, HV, f0, 4*f0, A0/2);
            claridad(3) = A0 > 2;
            [claridad(4), fpeak_min, fpeak_max] = criterio_fpeak(frecuencia, HVmin, HVmax, f0);

            % CL5 (estabilidad temporal): SOLO disponible para el pico principal,
            % porque es el unico que tiene datos "f0 from windows" en el .hv.
            if es_principal && ~isnan(sigma_f)
                epsilon = obtener_epsilon(f0);
                claridad(5) = sigma_f < epsilon;
                cl5_evaluable = true;
            else
                epsilon = NaN;
                claridad(5) = false;
                cl5_evaluable = false;
            end

            [sigmaA_f0, theta] = sigmaA_en_f0(frecuencia, HV, HVmin, HVmax, f0);
            if isnan(sigmaA_f0)
                claridad(6) = false;
            else
                claridad(6) = sigmaA_f0 < theta;
            end

            % Numero de criterios realmente evaluables (5 si CL5 no aplica, 6 si aplica)
            criterios_evaluables = 5 + double(cl5_evaluable);
            cantidad_claridad = sum(claridad(1:6)) - double(~cl5_evaluable && claridad(5)==0)*0; % claridad(5) ya es 0 si no evaluable, no resta de mas
            cantidad_claridad = sum(claridad); % suma directa (CL5=0 cuando no evaluable, no infla ni penaliza doble)
            claridad_normalizada = cantidad_claridad / criterios_evaluables;

            % Umbral de "pico claro": >=5/6 si el CL5 es evaluable (igual que siempre),
            % o >=4/5 (80%) si CL5 no es evaluable, para mantener el mismo estandar relativo.
            if cl5_evaluable
                pico_claro = cantidad_claridad >= 5;
            else
                pico_claro = claridad_normalizada >= 0.8;
            end

            if curva_confiable && pico_claro
                veredicto = 'VALIDA';
            elseif ~curva_confiable && estado_C3 == 0
                veredicto = 'NO CONCLUYENTE';
            elseif curva_confiable && ~pico_claro
                veredicto = 'CURVA CONFIABLE - PICO NO CLARO';
            else
                veredicto = 'NO VALIDA';
            end

            % Nombre de grafico: el principal mantiene el nombre de siempre;
            % los secundarios llevan sufijo para no pisarse entre si.
            if es_principal
                nombre_grafico = nombre_hv;
            else
                base = strrep(nombre_hv, '.hv', '');
                nombre_grafico = sprintf('%s_cand%d_f%.2fHz.hv', base, c, f0);
            end

            generar_grafico_sesame(frecuencia, HV, HVmin, HVmax, f0, A0, veredicto, cantidad_claridad, nombre_grafico, carpeta_graficos);

            fprintf('  Candidato %d (%s): f0=%.4f Hz  A0=%.3f  N_claridad=%d/%d  %s\n', ...
                c, ternario(es_principal,'PRINCIPAL','secundario'), f0, A0, cantidad_claridad, criterios_evaluables, veredicto);

            resultados(end+1,:) = {nombre_hv, es_principal, f0, A0, Nw, LW_SECONDS, nc, C1, C2, C3, ...
                cantidad_claridad, criterios_evaluables, claridad_normalizada, ...
                claridad(1), claridad(2), claridad(3), claridad(4), claridad(5), claridad(6), ...
                sigma_f, epsilon, sigmaA_f0, theta, sigmaA_max, fpeak_min, fpeak_max, veredicto};
        end

    catch ME
        fprintf('\nERROR en archivo %s: %s\n', nombre_hv, ME.message);
        resultados(end+1,:) = {nombre_hv, true, NaN, NaN, NaN, LW_SECONDS, NaN, false, false, false, ...
            0, 0, NaN, false, false, false, false, false, false, NaN, NaN, NaN, NaN, NaN, NaN, NaN, 'ERROR'};
    end
end

fid = fopen(archivo_salida, 'w');
fprintf(fid, ['Estacion;Es_Principal;f0_Hz;A0;Nw;lw_s;nc;C1_frecuencia;C2_ciclos;C3_estabilidad;' ...
     'N_claridad;Criterios_evaluables;N_claridad_norm;CL1;CL2;CL3_A0;CL4_fpeak;CL5_sigmaf;CL6_sigmaA;' ...
     'sigma_f;epsilon;sigmaA_f0;theta;sigmaA_max;fpeak_min;fpeak_max;Veredicto\n']);
for i = 1:size(resultados,1)
    fprintf(fid, '%s;%d;%.6f;%.6f;%d;%.3f;%.3f;%d;%d;%d;%d;%d;%.4f;%d;%d;%d;%d;%d;%d;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%.6f;%s\n', resultados{i,:});
end
fclose(fid);
fprintf('\n============================================================\nPROCESAMIENTO TERMINADO.\n============================================================\n');

end % CIERRE OBLIGATORIO DE LA FUNCION PRINCIPAL EN OCTAVE


%% ================================================================
% FUNCIONES DE SOPORTE SUBORDINADAS
% ================================================================

function candidatos = detectar_picos(f, HV, min_amplitud, min_prominencia_rel, min_separacion_oct)
% Detecta maximos locales en la curva HV promedio, filtrando por amplitud
% minima y prominencia, y descartando duplicados muy cercanos en frecuencia.
    candidatos = struct('f0', {}, 'A0', {});
    f = f(:); HV = HV(:);
    v = isfinite(f) & isfinite(HV) & f > 0;
    f = f(v); HV = HV(v);
    [f, ord] = sort(f); HV = HV(ord);
    n = length(f);
    if n < 3, return; end

    idx_max = find(HV(2:end-1) > HV(1:end-2) & HV(2:end-1) > HV(3:end)) + 1;

    for k = 1:length(idx_max)
        i = idx_max(k);
        Ai = HV(i);
        if Ai < min_amplitud, continue; end

        valle_izq = min(HV(1:i));
        valle_der = min(HV(i:end));
        prominencia = Ai - max(valle_izq, valle_der);
        if prominencia < min_prominencia_rel * Ai, continue; end

        candidatos(end+1).f0 = f(i);
        candidatos(end).A0 = Ai;
    end
    if isempty(candidatos), return; end

    fs = [candidatos.f0]; As = [candidatos.A0];
    [~, orden] = sort(As, 'descend');
    mantener = true(size(fs));
    for a = 1:length(orden)
        if ~mantener(orden(a)), continue; end
        for b = a+1:length(orden)
            if ~mantener(orden(b)), continue; end
            if abs(log2(fs(orden(a)) / fs(orden(b)))) < min_separacion_oct
                mantener(orden(b)) = false;
            end
        end
    end
    candidatos = candidatos(mantener);
    [~, orden_f] = sort([candidatos.f0]);
    candidatos = candidatos(orden_f);
end

function s = ternario(cond, a, b)
    if cond, s = a; else s = b; end
end

function [resultado, estado, sigma_max] = criterio_estabilidad(f, HV, HVmin, HVmax, f0)
    resultado = false; estado = 0; sigma_max = NaN; f_inf = 0.5 * f0; f_sup = 2.0 * f0;
    if min(f) > f_inf || max(f) < f_sup, return; end
    mascara = f > f_inf & f < f_sup; if sum(mascara) == 0, return; end
    A = HV(mascara); Amin = HVmin(mascara); Amax = HVmax(mascara);
    v = isfinite(A) & isfinite(Amin) & isfinite(Amax) & A > 0 & Amin > 0 & Amax > 0; if sum(v) == 0, return; end
    A = A(v); Amin = Amin(v); Amax = Amax(v); sigmaA = sqrt(Amax ./ Amin); sigma_max = max(sigmaA);
    limite = 3.0; if f0 > 0.5, limite = 2.0; end
    if all(sigmaA < limite), resultado = true; estado = 1; else resultado = false; estado = 2; end
end

function [resultado, estado] = criterio_existencia(f, HV, fmin, fmax, limite)
    resultado = false; estado = 'FAIL'; mascara = f >= fmin & f <= fmax; if sum(mascara) == 0, estado = 'NO_DATA'; return; end
    valores = HV(mascara); valores = valores(isfinite(valores)); if isempty(valores), estado = 'NO_DATA'; return; end
    if any(valores < limite)
        resultado = true; estado = 'PASS';
    else
        if fmin < min(f) || fmax > max(f), estado = 'INCOMPLETE'; end;
    end
end

function [resultado, fpeak_min, fpeak_max] = criterio_fpeak(f, HVmin, HVmax, f0)
    resultado = false; fpeak_min = NaN; fpeak_max = NaN;
    if isempty(f), return; end
    banda = f >= f0/4 & f <= 4*f0;
    if sum(banda) == 0, return; end
    f_b = f(banda); HVmin_b = HVmin(banda); HVmax_b = HVmax(banda);
    [~, imin] = max(HVmin_b); [~, imax] = max(HVmax_b);
    fpeak_min = f_b(imin); fpeak_max = f_b(imax);
    resultado = (abs(fpeak_min - f0) <= 0.05 * f0) && (abs(fpeak_max - f0) <= 0.05 * f0);
end

function epsilon = obtener_epsilon(f0)
    if f0 < 0.2, epsilon = 0.25 * f0; elseif f0 < 0.5, epsilon = 0.20 * f0; elseif f0 < 1.0, epsilon = 0.15 * f0; elseif f0 < 2.0, epsilon = 0.10 * f0; else epsilon = 0.05 * f0; end
end

function [sigmaA, theta] = sigmaA_en_f0(f, HV, HVmin, HVmax, f0)
    sigmaA = NaN; theta = obtener_theta(f0); if isempty(f), return; end
    Amin = interp1(f, HVmin, f0, 'linear', NaN); Amax = interp1(f, HVmax, f0, 'linear', NaN);
    if isnan(Amin) || isnan(Amax) || Amin <= 0 || Amax <= 0, return; end
    sigmaA = sqrt(Amax / Amin);
end

function theta = obtener_theta(f0)
    if f0 < 0.2, theta = 3.0; elseif f0 < 0.5, theta = 2.5; elseif f0 < 1.0, theta = 2.0; elseif f0 < 2.0, theta = 1.78; else theta = 1.58; end
end
