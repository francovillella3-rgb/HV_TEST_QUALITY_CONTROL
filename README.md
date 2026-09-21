================================================================================
 SESAME_TESTHV.m
 Evaluacion automatica de criterios de fiabilidad y claridad SESAME (2004)
 para curvas H/V (HVSR) exportadas desde Geopsy, con deteccion automatica
 de picos multiples
================================================================================

Autor: Franco Villella
Contexto: Tesis de grado, Licenciatura en Geofisica (UNSJ)
"Evaluacion del peligro sismico en la ciudad de Salta a partir del analisis
del terremoto de febrero de 2010 y su contexto sismotectonico"

--------------------------------------------------------------------------------
1. QUE HACE ESTE SCRIPT
--------------------------------------------------------------------------------

Automatiza el control de calidad de curvas HVSR (razon espectral horizontal/
vertical) siguiendo los criterios definidos por el proyecto europeo SESAME
(Site EffectS assessment using AMbient Excitations, 2004), que son el
estandar de facto para decidir si una curva H/V y su pico de frecuencia
fundamental (f0) son estadisticamente confiables.

Toma como entrada archivos .hv exportados desde Geopsy (uno por estacion de
medicion) y para cada uno:

  1. Lee la curva promedio H/V, sus envolventes (HVmin, HVmax) y los
     metadatos del procesamiento (numero de ventanas, f0 picado, amplitud).
  2. Detecta automaticamente TODOS los picos (maximos locales) presentes en
     la curva, no solo el que fue picado manualmente en Geopsy.
  3. Evalua, para cada pico candidato, los 3 criterios de FIABILIDAD de la
     curva y los 6 criterios de CLARIDAD del pico segun SESAME.
  4. Asigna un veredicto final (VALIDA / CURVA CONFIABLE-PICO NO CLARO /
     NO CONCLUYENTE / NO VALIDA) a cada candidato.
  5. Genera un grafico PNG por cada curva/candidato evaluado, con las bandas
     de referencia SESAME superpuestas.
  6. Exporta todos los resultados a un unico CSV (Resultados_SESAME.csv),
     con una fila por candidato de pico.

--------------------------------------------------------------------------------
2. POR QUE SE DETECTAN MULTIPLES PICOS POR ESTACION
--------------------------------------------------------------------------------

Un pico H/V representa un contraste de impedancia acustica en profundidad.
Cuando existe mas de un contraste significativo (por ejemplo, una capa
superficial rigida sobre sedimentos blandos, y mas abajo el contacto
sedimento-basamento), la curva puede mostrar mas de un pico genuino:

  - El pico de mayor amplitud suele asociarse al contraste mas fuerte,
    frecuentemente el mas somero.
  - Un pico de menor amplitud (y menor frecuencia) puede corresponder a un
    contraste mas profundo, como el contacto sedimento-basamento, que es
    habitualmente el de mayor interes para estudios de espesor de cuenca y
    peligro sismico de periodo largo.

Evaluar unicamente el pico de mayor amplitud puede hacer que se descarte,
sin analizar, informacion geologica real contenida en picos secundarios.
Por eso el script identifica todos los maximos locales relevantes de la
curva y corre el control de calidad SESAME sobre cada uno por separado.

--------------------------------------------------------------------------------
3. LOS 3 CRITERIOS DE FIABILIDAD DE LA CURVA (C1, C2, C3)
--------------------------------------------------------------------------------

Determinan si la curva en su conjunto es estadisticamente confiable,
independientemente de que tan marcado sea el pico.

  C1 (frecuencia minima resoluble):
      f0 > 10 / Lw
      donde Lw es la longitud de la ventana de analisis (segundos).
      Garantiza que la ventana sea lo bastante larga para resolver la
      frecuencia f0 con precision espectral suficiente.

  C2 (numero de ciclos):
      nc = Lw * Nw * f0 > 200
      donde Nw es el numero de ventanas utilizadas. Garantiza que se
      promediaron suficientes ciclos de la senal en la frecuencia f0.

  C3 (estabilidad de amplitud en la banda [0.5*f0, 2*f0]):
      sigmaA(f) = sqrt(HVmax(f) / HVmin(f)) < limite
      con limite = 2.0 si f0 > 0.5 Hz, o 3.0 si f0 <= 0.5 Hz, para todas
      las frecuencias dentro de la banda. Ademas requiere que el archivo
      .hv cubra efectivamente esa banda completa (si el rango de frecuencias
      exportado desde Geopsy no llega a 2*f0, este criterio no puede
      evaluarse y el resultado se marca como "no concluyente").

La curva se considera "confiable" (curva_confiable) solo si se cumplen
los 3 criterios simultaneamente.

--------------------------------------------------------------------------------
4. LOS 6 CRITERIOS DE CLARIDAD DEL PICO (CL1 a CL6)
--------------------------------------------------------------------------------

Determinan si el pico en f0 esta bien definido (y no es, por ejemplo, una
meseta ancha o un maximo ambiguo). Se requieren al menos 5 de 6 para
considerar el pico "claro".

  CL1: existe una frecuencia f- en [f0/4, f0] tal que HV(f-) < A0/2.
  CL2: existe una frecuencia f+ en [f0, 4*f0] tal que HV(f+) < A0/2.
       (Ambos verifican que el pico realmente decae hacia los flancos,
        y no es parte de una meseta ancha.)
  CL3: A0 > 2 (amplitud minima del pico).
  CL4: el maximo de las curvas HVmin y HVmax, buscado dentro de la banda
       [f0/4, 4*f0], cae dentro de un 5% de f0. Verifica que el pico sea
       consistente entre las envolventes de variabilidad, y no solo en la
       curva promedio.
  CL5: la desviacion estandar de f0 entre ventanas individuales (sigma_f)
       es menor que un umbral epsilon(f0) (mas estricto cuanto mayor es f0).
       Esto solo puede evaluarse para el pico que fue picado manualmente en
       Geopsy, porque es el unico para el cual el archivo .hv reporta la
       linea "# f0 from windows" con la dispersion entre ventanas. Para
       picos detectados automaticamente por este script (candidatos
       secundarios), CL5 no es evaluable y se excluye del conteo en vez de
       contarse como fallido.
  CL6: la dispersion de amplitud en f0 (sigmaA_f0 = sqrt(HVmax(f0)/HVmin(f0)))
       es menor que un umbral theta(f0).

Como CL5 no siempre es evaluable, el script calcula ademas un puntaje
normalizado (N_claridad / Criterios_evaluables) y usa un umbral equivalente
(>= 5/6 cuando CL5 aplica, >= 4/5 cuando no aplica) para no penalizar a los
picos secundarios por una limitacion de exportacion de Geopsy y no por una
falla real de la curva.

--------------------------------------------------------------------------------
5. VEREDICTO FINAL
--------------------------------------------------------------------------------

  VALIDA                            -> curva confiable Y pico claro
  CURVA CONFIABLE - PICO NO CLARO   -> curva confiable, pico no claro
  NO CONCLUYENTE                    -> curva no confiable por rango de
                                        frecuencias insuficiente (no se
                                        pudo evaluar C3)
  NO VALIDA                         -> curva no confiable por otro motivo
                                        (inestabilidad real, no de rango)

--------------------------------------------------------------------------------
6. ARCHIVOS DEL PROYECTO
--------------------------------------------------------------------------------

  SESAME_TESTHV.m
      Script principal. Recorre todos los archivos .hv de una carpeta,
      llama a leer_HV.m para parsear cada uno, detecta picos candidatos,
      evalua los criterios SESAME sobre cada candidato, genera los graficos
      via generar_grafico_sesame.m y exporta Resultados_SESAME.csv.

  leer_HV.m
      Parsea un archivo .hv de Geopsy. Extrae: numero de ventanas (Nw),
      f0 promedio, f0 y su dispersion entre ventanas (f0_windows, sigma_f),
      amplitud del pico (A0), y las curvas de frecuencia/HV/HVmin/HVmax.

  generar_grafico_sesame.m
      Genera y guarda un grafico PNG de la curva H/V con las bandas de
      referencia SESAME (0.5*f0 y 2*f0), el pico marcado, y el veredicto
      y puntaje de claridad en el titulo.

  Resultados_SESAME.csv (salida)
      Una fila por cada pico candidato evaluado en cada estacion. Columnas
      principales: Estacion, Es_Principal (1 si es el pico picado
      manualmente en Geopsy, 0 si fue detectado automaticamente), f0_Hz,
      A0, C1/C2/C3, CL1 a CL6, N_claridad, Criterios_evaluables,
      N_claridad_norm, Veredicto.

--------------------------------------------------------------------------------
7. PARAMETROS AJUSTABLES
--------------------------------------------------------------------------------

  LW_SECONDS (en SESAME_TESTHV.m)
      Longitud de ventana usada en el procesamiento Geopsy (segundos).
      Debe coincidir con la usada al generar los .hv, ya que se usa para
      evaluar C1 y C2.

  MIN_AMPLITUD, MIN_PROMINENCIA, MIN_SEPARACION_OCT (funcion detectar_picos)
      Controlan la sensibilidad de la deteccion automatica de picos:
      amplitud minima para considerar un maximo local como candidato,
      prominencia minima relativa al valle mas cercano, y separacion
      minima entre dos candidatos (en octavas) para no duplicar el mismo
      pico. Se recomienda ajustarlos revisando visualmente los graficos
      generados en una primera corrida de prueba.

--------------------------------------------------------------------------------
8. LIMITACIONES CONOCIDAS
--------------------------------------------------------------------------------

  - CL5 no es evaluable para picos detectados automaticamente (ver seccion 4).
  - El criterio C3 (y por lo tanto el veredicto NO CONCLUYENTE) depende del
    rango de frecuencias exportado desde Geopsy. Si el pico de interes tiene
    f0 alto, el archivo .hv debe exportarse con un techo de frecuencia de al
    menos 2*f0 (idealmente 4*f0) para poder evaluar la curva por completo.
  - La deteccion automatica de picos puede requerir ajuste de parametros
    segun el nivel de ruido de cada dataset; se recomienda inspeccionar los
    graficos PNG generados antes de dar por buena una corrida masiva.

--------------------------------------------------------------------------------
9. REQUISITOS
--------------------------------------------------------------------------------

  - GNU Octave (probado con el toolkit grafico 'gnuplot').
  - Archivos .hv exportados desde Geopsy (formato estandar, con encabezados
    "# Number of windows =", "# f0 from average", "# f0 from windows",
    "# f0 amplitude", y columnas Frecuencia/Promedio/Min/Max).

--------------------------------------------------------------------------------
10. REFERENCIA
--------------------------------------------------------------------------------

SESAME European Research Project (2004). "Guidelines for the implementation
of the H/V spectral ratio technique on ambient vibrations - Measurements,
processing and interpretation." SESAME European Research Project WP12,
Deliverable D23.12.
================================================================================
