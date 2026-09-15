function datos = leer_HV(nombre, archivo)
    fid = fopen(archivo, 'r');
    if fid < 0, error('No se pudo abrir el archivo %s.', nombre); end

    datos.f0 = NaN; datos.A0 = NaN; datos.Nw = NaN; datos.f0_windows = NaN; datos.sigma_f = NaN;
    frecuencia = []; HV = []; HVmin = []; HVmax = [];

    while ~feof(fid)
        linea = fgetl(fid); if ~ischar(linea), continue; end
        linea = strtrim(linea); if isempty(linea), continue; end

        if strncmp(linea, '# Number of windows =', 21)
            partes = strsplit(linea, '='); if length(partes) >= 2, datos.Nw = str2double(strtrim(partes{2})); end
        elseif strncmp(linea, '# f0 from average', 17)
            partes = regexp(linea, '\s+', 'split'); if length(partes) >= 5, datos.f0 = str2double(partes{5}); end
        elseif strncmp(linea, '# f0 from windows', 17)
            partes = regexp(linea, '\s+', 'split');
            if length(partes) >= 7, datos.f0_windows = str2double(partes{5}); datos.sigma_f = (str2double(partes{7}) - str2double(partes{6})) / 2; end
        elseif strncmp(linea, '# f0 amplitude', 14) || strncmp(linea, '# Peak amplitude', 16)
            partes = regexp(linea, '\s+', 'split'); if length(partes) >= 4, datos.A0 = str2double(partes{4}); end
        elseif linea(1) ~= '#'
            valores = sscanf(linea, '%f');
            if length(valores) >= 4, frecuencia(end+1) = valores(1); HV(end+1) = valores(2); HVmin(end+1) = valores(3); HVmax(end+1) = valores(4); end
        end
    end
    fclose(fid);
    datos.frecuencia = frecuencia(:); datos.HV = HV(:); datos.HVmin = HVmin(:); datos.HVmax = HVmax(:);
end

