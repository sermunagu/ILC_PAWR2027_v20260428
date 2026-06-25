# analisis_8WF

Esta carpeta contiene los scripts usados para construir y evaluar un modelo común de 171 regresores sobre 8 waveforms ILC.

## Flujo principal

Comando maestro para ejecutar el flujo completo:

```matlab
run('analisis_8WF/run_full_common171_pipeline_8wf.m')
```

Para usar un nuevo conjunto de medidas, normalmente solo hay que editar al principio de `run_full_common171_pipeline_8wf.m`:

```matlab
cfg.measurementDirName = 'NOMBRE_DEL_DIRECTORIO_DE_MEDIDAS';
```

y colocar las 8 medidas en:

```text
results/NOMBRE_DEL_DIRECTORIO_DE_MEDIDAS/
```

Cada archivo debe seguir el patrón `experiment*_xy.mat` y contener las variables `x` e `y`. Las salidas estables se guardan separadas por campaña en:

```text
results/common171_full_pipeline/NOMBRE_DEL_DIRECTORIO_DE_MEDIDAS/
```

1. `01_generacion_modelos/run_composite_8wf.m`
   Genera modelos composite específicos de 300 regresores para las 8 waveforms.

2. `02_modelo_comun/build_common171_from_composite.m`
   Analiza la estructura común entre las 8 waveforms usando correlación estructural y genera el modelo común de 171 regresores.

3. `02_modelo_comun/common171_regressors.csv`
   Lista final de los 171 regresores comunes.

4. `03_evaluacion/eval_common171_vs_specific300_all8.m`
   Compara el modelo común 171 frente a modelos específicos composite/GVG de 300 regresores.

5. `03_evaluacion/eval_tutor_pomp200_wf5.m`
   Reproduce el baseline del tutor en WF5 usando compositeall + POMP200.

6. `03_evaluacion/eval_common171_tutor_method_wf5.m`
   Evalúa el modelo común 171 en WF5 con la misma metodología del tutor.

7. `03_evaluacion/eval_common171_vs_pomp200_all8.m`
   Extiende la comparación tutor-method a las 8 waveforms: POMP200 específico vs Common171.

## Diagnóstico WF6

Los scripts de `04_diagnostico_wf6/` se usan para analizar la anomalía de WF6, que presenta NMSE pobre incluso con modelos específicos.

## Archivos Archivados

La carpeta `_archive_no_definitivo/` contiene scripts exploratorios o superados por versiones más definitivas.

## Comandos Principales

Desde la raíz del repositorio:

```matlab
run('analisis_8WF/01_generacion_modelos/run_composite_8wf.m')
run('analisis_8WF/02_modelo_comun/build_common171_from_composite.m')
run('analisis_8WF/03_evaluacion/eval_common171_vs_pomp200_all8.m')
```

No ejecutar estos scripts sin revisar primero las ventanas/configuración de cada experimento y confirmar que los resultados existentes no se van a sobrescribir.
