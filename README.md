' # HV_TEST_QUALITY_CONTROL
' HV_TEST_QUALITY_CONTROL
' [README_SESAME_HVSR.txt](https://github.com/user-attachments/files/32242649/README_SESAME_HVSR.txt)
' README - AUTOMATIZACION SESAME PARA CURVAS HVSR
' GNU OCTAVE + ARCHIVOS .HV DE GEOPSY

' 1. OBJETIVO
Este programa permite evaluar automaticamente la confiabilidad y claridad de
picos de curvas H/V (HVSR) obtenidas con Geopsy, siguiendo la logica de los
criterios SESAME.

IMPORTANTE: el programa NO procesa señales sismicas crudas. Trabaja sobre
archivos .hv que ya fueron procesados y exportados desde Geopsy.

2. ARCHIVOS PRINCIPALES
- leer_HV.m: lee cada archivo .hv y extrae Nw, f0, A0, informacion de f0 por
  ventanas y las curvas Frequency / Average / Min / Max.
- generar_grafico_sesame.m: genera el grafico de control de cada estacion.
- script principal: recorre los .hv, aplica los criterios V1-V9 y genera los
  resultados.

3. REQUISITO IMPORTANTE: DURACION DE VENTANA
El archivo .hv no contiene directamente la duracion de la ventana utilizada
en el procesamiento. Por eso el programa usa un parametro global definido
en el script principal.

Para el conjunto de datos original:

    LW_SECONDS = 50

Esto significa que las ventanas utilizadas fueron de 50 segundos.

Si se utilizan archivos generados con otra duracion, hay que cambiar
LW_SECONDS antes de ejecutar el programa.

No mezclar archivos procesados con distintas duraciones de ventana sin
revisar este parametro.

4. PREPARACION
Se recomienda una estructura como:

PROYECTO/
  script_principal.m
  leer_HV.m
  generar_grafico_sesame.m
  INPUT/
      ESTACION_01.hv
      ESTACION_02.hv
      ESTACION_03.hv
      ...
  OUTPUT/

Coloque los .m en la carpeta del proyecto y los archivos .hv en la carpeta
de entrada definida por el script principal.

5. FORMATO ESPERADO DEL .HV
Los archivos deben contener informacion equivalente a:

# Number of windows = ...
# f0 from average ...
# f0 from windows ...
# f0 amplitude ...
...
# Frequency Average Min Max

seguida por los datos de frecuencia y amplitud.

6. COMO EJECUTAR
1) Abra GNU Octave.
2) Cambie a la carpeta del proyecto, por ejemplo:
       cd 'C:\ruta\del\proyecto'
3) Compruebe que LW_SECONDS tenga el valor correcto.
4) Ejecute el script principal, por ejemplo:
       run('script_principal.m')

El nombre del script principal puede variar.

7. QUE HACE EL PROGRAMA
Para cada archivo .hv:
- lee automaticamente f0, A0, Nw y las curvas H/V;
- utiliza LW_SECONDS;
- calcula el numero de ciclos:
      nc = lw * Nw * f0
- evalua los nueve criterios SESAME V1-V9;
- cuenta los criterios de claridad satisfactorios;
- genera un resultado por estacion;
- genera un grafico de control;
- guarda los resultados en una tabla/CSV, segun la configuracion del script.

8. CRITERIOS SESAME
CONFIABILIDAD:
- V1: comprueba f0 > 10/lw.
- V2: comprueba nc > 200.
- V3: evalua la estabilidad de la amplitud en la banda 0.5*f0 a 2*f0.

CLARIDAD DEL PICO:
- V4: busca una caida por debajo de A0/2 entre f0/4 y f0.
- V5: busca una caida por debajo de A0/2 entre f0 y 4*f0.
- V6: comprueba A0 > 2.
- V7: comprueba la posicion de los maximos de las curvas Min y Max dentro
  de aproximadamente +/-5 % de f0.
- V8: comprueba la estabilidad de la frecuencia del pico.
- V9: comprueba la estabilidad de la amplitud del pico.

9. PASS / FAIL / INCOMPLETO
PASS:
El criterio pudo evaluarse completamente y cumple el requisito.

FAIL:
El criterio pudo evaluarse completamente pero NO cumple el requisito.

INCOMPLETO:
No existe informacion suficiente en el .hv para evaluar todo el intervalo
requerido.

INCOMPLETO NO significa FAIL.

Ejemplo importante:
Si 2*f0 queda fuera del rango de frecuencias disponible del archivo .hv,
V3 no puede evaluarse completamente y debe quedar como INCOMPLETO.

Lo mismo aplica cuando las bandas necesarias para V4 o V5 no estan cubiertas.

10. RESULTADOS
El resultado tabular puede incluir, por estacion:
- nombre del archivo;
- f0;
- A0;
- Nw;
- lw;
- nc;
- V1 a V9;
- numero de criterios de claridad aprobados;
- veredicto general.

El grafico de control muestra:
- H/V promedio;
- H/V Min;
- H/V Max;
- lineas de referencia 0.5*f0 y 2*f0;
- ubicacion de f0 y A0;
- veredicto;
- cantidad de criterios de claridad aprobados.

Los graficos se guardan con nombres del tipo:
    ESTACION_SESAME.png
Por ejemplo:
    SB_1_SESAME.png

11. CONTROL DE CALIDAD
Aunque la evaluacion es automatica, se recomienda revisar visualmente:
- estaciones con FAIL;
- estaciones con INCOMPLETO;
- posicion de f0;
- forma de la curva H/V;
- amplitud A0;
- que LW_SECONDS coincida con el procesamiento original;
- que los archivos pertenezcan a una configuracion homogenea.

12. PROBLEMAS FRECUENTES

"No se pudo abrir el archivo"
Verifique ruta, nombre y permisos.

"No aparecen f0, A0 o Nw"
Revise que el .hv tenga las lineas de cabecera esperadas.

"V3 aparece como INCOMPLETO"
Compruebe si la curva llega hasta 2*f0. Si no llega, falta informacion.

"Los resultados parecen incorrectos"
Revise principalmente LW_SECONDS y las rutas de entrada/salida.

13. LIMITACIONES
Este programa automatiza criterios numericos sobre curvas H/V. No reemplaza
la revision de la calidad de la señal, la seleccion de ventanas, el analisis
de ruido, la interpretacion geofisica ni el criterio profesional del analista.

Un PASS indica cumplimiento de los criterios evaluados; no significa por si
solo que la interpretacion geofisica sea correcta en todos los casos.

14. FLUJO GENERAL

GEOPSY
  |
  v
Archivos .HV
  |
  v
leer_HV.m
  |
  v
Extraccion de f0, A0, Nw y curvas
  |
  v
Evaluacion V1-V9
  |
  +----------------------+
  |                      |
  v                      v
CSV / tabla          Graficos PNG
  |                      |
  +----------+-----------+
             v
       Revision del analista
             |
             v
      Interpretacion final

15. LISTA DE COMPROBACION ANTES DE USAR
[ ] GNU Octave instalado y funcionando.
[ ] Archivos .m disponibles.
[ ] Archivos .hv validos.
[ ] LW_SECONDS correcto.
[ ] Ruta de entrada correcta.
[ ] Ruta de salida correcta.
[ ] Se revisaron resultados INCOMPLETO.
[ ] Se revisaron resultados FAIL.
[ ] Se conservaron los archivos de salida.

El objetivo del programa es facilitar un analisis SESAME rapido, consistente,
reproducible y trazable sobre un conjunto grande de curvas HVSR.
