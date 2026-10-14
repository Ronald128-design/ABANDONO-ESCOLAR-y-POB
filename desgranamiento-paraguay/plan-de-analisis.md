# Alcance de los análisis por manuscrito

## Manuscrito 1: corte distrital 2022

### Resultados disponibles

El libro [Desgranamiento Paraguay 2022, resultados](resultados/manuscrito-1/Desgranamiento-Paraguay-2022-Resultados.xlsx) contiene resultados del Manuscrito 1: descriptivos, validación del indicador, reproducción del plan original, asociaciones bivariadas, modelos Poisson-lognormal multinivel y análisis de robustez.

El panel y el abandono directo aportan contrastes de validez para el indicador de este manuscrito. La comparación de la cohorte 2013-2021 y del abandono del tercer ciclo en 2021-2022 no constituye la estimación de los modelos del Manuscrito 2 ni del Manuscrito 3.

### Exploración inicial implementada en el programa

La unidad es el distrito. El resultado es el desgranamiento definido por la razón G9/G1. Las exposiciones principales son la incidencia monetaria del mapa INE y la proporción de hogares con al menos una NBI. Las covariables estructurales son proporción urbana, proporción oficial y número de instituciones.

Se describen todas las observaciones disponibles por variable. Las asociaciones de Spearman con las seis medidas INE forman una familia de contrastes con ajuste de Holm. La privación educativa relativa se reserva para descripción territorial porque deriva de la misma razón que el resultado.

Se comparan modelos OLS de estructura, pobreza monetaria, NBI y ambas exposiciones en la misma muestra. Se presentan HC3 y CR2 por departamento con aproximación de Satterthwaite. Se examinan valores ajustados, residuos, leverage y distancia de Cook. La sensibilidad material incluye vivienda e infraestructura sanitaria; distingue esas dimensiones de la NBI educativa, cuyo contenido se solapa conceptualmente con la escolarización.

La sensibilidad comprende respuesta fraccional, cuantiles .10, .25, .50, .75 y .90, remuestreo por departamento, exclusión sucesiva de cada departamento y exclusión de las estimaciones monetarias sintéticas. El modelo contextual original se estima por separado en sus casos completos y se compara con el modelo INE en esa misma muestra. Los indicadores departamentales repetidos no aportan observaciones independientes de contexto por cada distrito.

Las estimaciones describen asociaciones ecológicas. La fuente monetaria combina Censo 2022 y EPHC 2023; no se establece precedencia temporal frente al resultado educativo de 2022. Sus límites publicados se conservan para examinar incertidumbre, pero no constituyen por sí solos una distribución conjunta de error de medición.

## Manuscrito 2: panel 2013-2023

La base [m2-panel.csv](datos/bases/m2-panel.csv) contiene 1.302 observaciones de 270 distritos en cinco olas. El módulo [manuscrito-2-panel.R](codigo/manuscrito-2-panel.R) implementa los análisis descritos en esta sección. La hoja `Paper 2 Waves` del [libro exploratorio](datos/fuentes/02-Analisis-exploratorio-Paraguay.xlsx) contiene los descriptivos iniciales por ola. El repositorio contiene la base, esos descriptivos y el código de este manuscrito; su libro final de resultados no está publicado.

La unidad es distrito por ola. Se conserva el panel no balanceado y se identifica la submuestra observada en las cinco olas. El año se trata como factor debido al espaciamiento irregular.

Se describen retención y desgranamiento por ola, junto con Gini y Theil sobre el desgranamiento distrital no ponderado. Se estiman efectos fijos distritales y de ola, con errores agrupados por distrito. Se repite la especificación en el panel completo y se separan los componentes dentro y entre distritos de las covariables estructurales.

Las medidas INE de 2022 no se rellenan retrospectivamente como exposiciones anuales. Su efecto constante tampoco es identificable en un modelo con efectos fijos de distrito. El panel conserva los códigos originales; la estabilidad de límites territoriales requiere documentación geográfica antes de interpretar cambios como trayectorias de áreas equivalentes.

## Manuscrito 3: abandono 2021-2024

La base [m3-abandono.csv](datos/bases/m3-abandono.csv) contiene 12.786 registros en los períodos 2021-2022, 2022-2023 y 2023-2024. El módulo [manuscrito-3-abandono.R](codigo/manuscrito-3-abandono.R) implementa los análisis descritos en esta sección. Las series de [retención](datos/bases/m3-retencion.csv) y [educación inicial](datos/bases/m3-educacion-inicial.csv) son complementarias. Las hojas `Paper 3 Patterns` y `Retention Above 1` del [libro exploratorio](datos/fuentes/02-Analisis-exploratorio-Paraguay.xlsx) contienen patrones descriptivos iniciales. El repositorio contiene las bases, esos descriptivos y el código de este manuscrito; su libro final de resultados no está publicado.

La unidad es distrito por ciclo, zona, sector, sexo y período. Se describen proporciones, ceros y unos, con medias no ponderadas de los estratos observados.

El modelo fraccional incluye período por ciclo, sexo, zona y sector, con covarianza agrupada por distrito. El GEE ordena los registros por estrato estable y ola y usa correlación intercambiable. Ese GEE evalúa repetición dentro del estrato; no sustituye la agrupación distrital del análisis principal. Una sensibilidad lineal incorpora efectos fijos de distrito.

Las covariables monetaria y NBI se vinculan muchos-a-uno por clave distrital. Su asociación contemporánea se estima para 2022-2023. No se repiten como mediciones nuevas en cada período ni se les atribuye un efecto causal temporal.

La retención y el déficit de educación inicial se describen en sus propias unidades departamentales. La retención superior a uno no se trunca ni se introduce en una familia restringida a proporciones.

## Alcance del programa exploratorio

`codigo/analisis-exploratorio.R` implementa la exploración inicial del Manuscrito 1 y los módulos de panel y abandono de los Manuscritos 2 y 3. Guarda tablas y objetos R en `resultados/analisis-exploratorio/`. Los estimadores deben ejecutarse con sus dependencias para producir esas salidas. La especificación multinivel y los análisis ampliados del libro de resultados del Manuscrito 1 están documentados en sus hojas de ruta, decisiones metodológicas y código R.
