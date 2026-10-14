# Desgranamiento, pobreza y abandono escolar en Paraguay

Proyecto de Ronaldo L. Rodas Jara compuesto por tres manuscritos con unidades de análisis, períodos y desenlaces diferenciados.

| Manuscrito | Unidad y período | Material disponible |
|---|---|---|
| 1. Desgranamiento y privación distrital | Distrito, corte 2022 | Base integrada, libro de resultados y código exploratorio |
| 2. Cambios territoriales del desgranamiento | Distrito por ola, 2013 a 2023 | Panel, descriptivos exploratorios y código de análisis |
| 3. Abandono escolar | Distrito por ciclo, zona, sector, sexo y período, 2021 a 2024 | Bases estratificadas, descriptivos exploratorios, series complementarias y código de análisis |

## Manuscrito 1: desgranamiento y privación distrital en 2022

Estudio ecológico transversal de 263 distritos. Examina la validez del indicador de retención aparente y su asociación con la pobreza monetaria, las necesidades básicas insatisfechas y el contexto departamental.

- [Base distrital 2022](datos/bases/m1-corte-2022.csv).
- [Resultados del Manuscrito 1](resultados/manuscrito-1/Desgranamiento-Paraguay-2022-Resultados.xlsx).
- [Código de la exploración inicial](codigo/manuscrito-1-exploratorio.R).

El libro de resultados contiene descriptivos, validación del indicador, reproducción del plan original, correlaciones, modelos Poisson-lognormal multinivel y análisis de robustez. Incluye tablas suplementarias, nueve figuras, referencias y el listado de código R correspondiente.

Su cobertura se limita al Manuscrito 1. El panel y el abandono directo se utilizan en ese libro para contrastar el indicador transversal con la cohorte 2013-2021 y con el abandono del tercer ciclo en 2021-2022. Los modelos longitudinales del Manuscrito 2 y los modelos estratificados del Manuscrito 3 tienen sus propias especificaciones.

El programa `codigo/manuscrito-1-exploratorio.R` implementa una exploración anterior con mínimos cuadrados, respuesta fraccional y regresión cuantílica. El listado R incluido en el Excel corresponde a los análisis ampliados del Manuscrito 1; son dos implementaciones diferentes.

## Manuscrito 2: panel distrital 2013-2023

Analiza los cambios territoriales de la retención aparente y del desgranamiento en las olas 2013, 2019, 2021, 2022 y 2023. El panel contiene 1.302 observaciones de 270 distritos; 250 distritos tienen las cinco olas.

- [Panel distrital](datos/bases/m2-panel.csv).
- [Código del Manuscrito 2](codigo/manuscrito-2-panel.R).
- Descriptivos por ola en la hoja `Paper 2 Waves` del [libro exploratorio](datos/fuentes/02-Analisis-exploratorio-Paraguay.xlsx).

El código incluye descriptivos por ola, Gini y Theil, modelos con efectos fijos distritales y de año, comparación con el panel balanceado y separación de los componentes dentro y entre distritos de las covariables estructurales. Las medidas INE de 2022 se conservan como mediciones de ese período.

El material publicado para este manuscrito consiste en la base, los descriptivos exploratorios y el código. No hay un libro final de resultados del Manuscrito 2 en el repositorio.

## Manuscrito 3: abandono escolar 2021-2024

Analiza 12.786 registros de abandono en los períodos 2021-2022, 2022-2023 y 2023-2024, diferenciados por ciclo, zona, sector y sexo.

- [Base de abandono directo](datos/bases/m3-abandono.csv).
- [Serie complementaria de retención departamental, 700 registros](datos/bases/m3-retencion.csv).
- [Serie complementaria de educación inicial, 72 registros](datos/bases/m3-educacion-inicial.csv).
- [Código del Manuscrito 3](codigo/manuscrito-3-abandono.R).
- Patrones descriptivos de abandono y retenciones superiores a uno en las hojas `Paper 3 Patterns` y `Retention Above 1` del [libro exploratorio](datos/fuentes/02-Analisis-exploratorio-Paraguay.xlsx).

El código incluye descriptivos por ciclo, sexo, zona, sector y período, un modelo fraccional con período por ciclo y covarianza agrupada por distrito, GEE para la repetición dentro del estrato, una sensibilidad lineal con efectos fijos distritales y la asociación contemporánea con pobreza monetaria y NBI en 2022-2023. La retención departamental y la educación inicial se analizan en sus propias unidades.

El material publicado para este manuscrito consiste en las bases, los descriptivos exploratorios y el código. No hay un libro final de resultados del Manuscrito 3 en el repositorio.

## Fuentes y variables

Los cinco libros de entrada están en [datos/fuentes](datos/fuentes). El [diccionario de variables](datos/diccionario-de-variables.csv) y la [descripción de los datos](datos/README.md) documentan escalas, transformaciones y enlaces geográficos.

Los CSV usan UTF-8, punto decimal y campos vacíos para los valores faltantes.

El [alcance de los análisis por manuscrito](plan-de-analisis.md) detalla la correspondencia entre las bases, las especificaciones y los archivos disponibles.

## Ejecución

Abrir [desgranamiento-paraguay.Rproj](desgranamiento-paraguay.Rproj) en RStudio. Ejecutar desde la raíz del repositorio:

```bash
python codigo/preparar-datos.py
Rscript codigo/verificar-datos.R
```

Seleccionar el manuscrito:

```bash
Rscript codigo/manuscrito-1-exploratorio.R
Rscript codigo/manuscrito-2-panel.R
Rscript codigo/manuscrito-3-abandono.R
```

La preparación requiere Python y `openpyxl`. La verificación de bases utiliza R base. La exploración inicial del Manuscrito 1 requiere `sandwich`, `lmtest`, `clubSandwich` y `quantreg`; el Manuscrito 2 requiere `fixest`; el Manuscrito 3 requiere `sandwich`, `lmtest`, `geepack` y `fixest`.

Estos puntos de entrada utilizan [codigo/analisis-exploratorio.R](codigo/analisis-exploratorio.R) y escriben las salidas de cada módulo en `resultados/analisis-exploratorio/`.
