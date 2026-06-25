# `run_full_common171_pipeline_8wf.m`

Este script ejecuta automáticamente el flujo completo para construir y evaluar el modelo común de 171 regresores sobre las 8 waveforms.

La idea es evitar ejecutar manualmente cada etapa por separado. Con un único comando se generan los modelos composite, se obtiene la estructura común de regresores, se evalúa frente a un baseline específico por waveform y se prepara una salida estable para laboratorio.

## Comando de ejecución

Desde la raíz del repositorio:

```matlab
run('analisis_8WF/run_full_common171_pipeline_8wf.m')
```

## Qué hace el script

El flujo principal es:

1. Detecta automáticamente la raíz del repositorio.
2. Comprueba que existen las 8 waveforms `experiment*_xy.mat`.
3. Ejecuta la generación de modelos composite para las 8 waveforms.
4. Construye el modelo común de 171 regresores.
5. Evalúa el modelo común frente a un baseline `POMP200` específico por waveform.
6. Guarda una salida estable para laboratorio en `results/common171_full_pipeline/`.

## Comparación realizada

La comparación final es:

```text
POMP200 específico por waveform
vs
Common171 común a todas las waveforms
```

### Baseline `POMP200`

Para cada waveform se construye un modelo específico usando:

- pool `compositeall`;
- método POMP;
- 200 regresores;
- `lambda = 1e-5`;
- `alpha = 1/(1+lambda)`;
- `diagLoad = 1e-12`;
- NMSE reconstruido explícitamente:

```matlab
NMSE = 20*log10(norm(y - yhat)/norm(y));
```

### Modelo `Common171`

El modelo común usa siempre la misma estructura fija de 171 regresores para todas las waveforms.

Importante: el modelo común **no se amplía a 200 regresores**.  
Los 171 regresores proceden del análisis de estructura común entre waveforms.

Los coeficientes se reestiman para cada waveform usando esa estructura fija.

## Archivos principales que genera

El script deja una salida estable en:

```text
results/common171_full_pipeline/
```

Dentro se crean o sobrescriben estos archivos:

### `latest_common171_regressors.csv`

Contiene la estructura final del modelo común: la lista de los 171 regresores.

Es el archivo principal para usar el modelo en laboratorio.

Este archivo define **qué regresores forman el modelo**, pero no debe interpretarse como un conjunto universal de coeficientes cerrado para cualquier señal.

En laboratorio:

```text
estructura de regresores = fija
coeficientes = se estiman con los datos disponibles
```

---

### `latest_common171_vs_pomp200_all8.csv`

Contiene la tabla final de resultados para las 8 waveforms.

Compara, waveform por waveform:

```text
POMP200 específico
vs
Common171 común
```

Incluye métricas de identificación, validación y deltas:

```text
delta = Common171 - POMP200
```

Interpretación:

```text
delta > 0  -> Common171 es peor que POMP200
delta < 0  -> Common171 es mejor que POMP200
```

Este es el archivo principal para analizar el rendimiento del modelo común.

---

### `latest_common171_lab_package.mat`

Paquete MATLAB para uso posterior en laboratorio.

Incluye, entre otros datos:

- configuración usada;
- timestamp de ejecución;
- rutas relevantes;
- lista de waveforms;
- tabla de resultados;
- regresores comunes;
- nota conceptual sobre el uso del modelo común.

Sirve para cargar en MATLAB toda la información relevante del modelo común sin tener que buscar cada archivo por separado.

---

### `latest_summary.txt`

Resumen legible de la última ejecución.

Incluye:

- fecha/hora de ejecución;
- ruta del modelo común;
- ruta de la tabla de evaluación;
- número de regresores comunes;
- tabla de resultados;
- medias de los deltas en identificación y validación;
- interpretación básica de los deltas.

Es el archivo más cómodo para revisar rápidamente los resultados sin abrir MATLAB.

## Archivos con timestamp

Además de los archivos `latest_*`, pueden generarse resultados con timestamp.

Los archivos con timestamp sirven para trazabilidad histórica.  
Los archivos `latest_*` son los recomendados para uso práctico, porque siempre apuntan a la última ejecución válida.

## Uso en laboratorio

El archivo clave para laboratorio es:

```text
results/common171_full_pipeline/latest_common171_regressors.csv
```

Este archivo fija la estructura común de 171 regresores.

Conceptualmente:

```text
estructura común = fija
coeficientes = se reestiman con los datos de laboratorio
```

Por tanto, el resultado no debe interpretarse como un modelo universal cerrado con coeficientes definitivos para cualquier señal, sino como una estructura común sobre la que se ajustan coeficientes.

## Resultado esperado

Al finalizar correctamente, el script debe imprimir algo similar a:

```text
FULL COMMON171 PIPELINE FINISHED

Final common model:
results/common171_full_pipeline/latest_common171_regressors.csv

Final evaluation:
results/common171_full_pipeline/latest_common171_vs_pomp200_all8.csv

Lab package:
results/common171_full_pipeline/latest_common171_lab_package.mat

Summary:
results/common171_full_pipeline/latest_summary.txt
```

## Nota sobre WF5

WF5 se usó inicialmente para comprobar que la metodología del tutor se reproducía correctamente.

Sin embargo, en este script WF5 no es la referencia global.

La referencia final es el modelo `POMP200` específico de cada waveform:

```text
WF01 -> Common171 vs POMP200 específico de WF01
WF02 -> Common171 vs POMP200 específico de WF02
...
WF08 -> Common171 vs POMP200 específico de WF08
```

## Nota sobre WF6

WF6 se mantiene en la tabla final, pero se considera una waveform anómala porque presenta NMSE pobre incluso con modelos específicos.

Por eso el resumen incluye medias tanto incluyendo WF6 como excluyéndola.
