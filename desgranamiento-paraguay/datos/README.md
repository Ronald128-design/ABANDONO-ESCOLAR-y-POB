# Datos del estudio

`fuentes/` conserva los cinco libros de entrada. `bases/` contiene las tablas que lee R. `diccionario-de-variables.csv` describe los campos y sus transformaciones.

`codigo/preparar-datos.py` reconstruye las tablas desde los libros, exige claves únicas, verifica los enlaces INE contra las tablas oficiales adjuntas y compara el corte educativo con la ola 2022 del panel. La unión del abandono se hace por las etiquetas originales del cruce suministrado; nunca por similitud automática de nombres.

La clave `clave_distrito` combina código de departamento y código de distrito, separados por un guion. Cada ola conserva la identificación recibida.

Las columnas `fila_origen*` mantienen la trazabilidad del libro educativo; `fila_fuente_pobreza_ine` y `fila_fuente_nbi_ine` identifican filas de las tablas INE adjuntas. Las hojas distritales y barriales se conservan separadas.

La tabla monetaria se titula 2022 y cita el Censo 2022 junto con la EPHC 2023. Sus límites se conservan sin asignar un nivel de confianza que el cuadro no indica. La bandera `pobreza_estimacion_sintetica` identifica Boquerón y Alto Paraguay, según la nota publicada.

Las variables `ipm_h_percent`, `pobreza`, `inasistencia`, `sobreedad`, `logro_minimo` y `trabajo_infantil` son contextuales departamentales en este archivo. Sus ausencias originales se conservan. Las nuevas medidas INE no las sustituyen ni las imputan.

`retencion_g9_g1` compara matrículas del mismo año en dos grados; no sigue una cohorte individual. `desgranamiento` mantiene la definición recibida, `max(0, 1 - G9/G1)`. `privacion_educativa_relativa` describe una posición relativa de esa misma razón y no se usa como predictor del desgranamiento.

Los valores de retención superiores a uno permanecen intactos. Las proporciones de abandono carecen de denominadores por estrato; sus medias distritales son no ponderadas.
