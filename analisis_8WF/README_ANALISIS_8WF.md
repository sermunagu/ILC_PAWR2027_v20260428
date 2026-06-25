# analisis_8WF

Esta carpeta contiene los scripts usados para construir y evaluar un modelo común CommonK sobre 8 waveforms ILC. El número K no es fijo: se calcula automáticamente para cada campaña aplicando el criterio de soporte estructural configurado.

CommonK es el flujo oficial. Common171 queda solo como histórico/deprecated.

## Flujo principal

Comando maestro para ejecutar el flujo completo:

```matlab
run('analisis_8WF/run_full_commonK_pipeline_8wf.m')
```

Para usar un nuevo conjunto de medidas, normalmente solo hay que editar al principio de `run_full_commonK_pipeline_8wf.m`:

```matlab
cfg.measurementDirName = 'NOMBRE_DEL_DIRECTORIO_DE_MEDIDAS';
cfg.commonCorrelationThreshold = 0.95;
cfg.commonSupportColumn = 'structuralSupportWaveformCount';
cfg.commonSupportThreshold = 6;
cfg.experimentName = '';

cfg.createTestDPDPackage = true;
cfg.testDPDBaseExperimentDate = '';
cfg.testDPDBaseExperimentMat = '';
cfg.copyTestDPDPackageToResultsRoot = false;
```

y colocar las 8 medidas en:

```text
results/NOMBRE_DEL_DIRECTORIO_DE_MEDIDAS/
```

Cada archivo debe seguir el patrón `experiment*_xy.mat` y contener las variables `x` e `y`. Las salidas se guardan separadas por campaña, experimento y timestamp en:

```text
results/common_model_experiments/NOMBRE_DEL_DIRECTORIO_DE_MEDIDAS/<experimentName>/<runStamp>/
```

Si `cfg.experimentName` está vacío, el maestro lo genera como `commonK_struct_ge6_thr095`, donde `K` es el número real de regresores que cumplen `structuralSupportWaveformCount >= 6` en el CSV `common_structure_thr095` más reciente de la campaña. También se actualiza un alias cómodo en:

```text
results/common_model_experiments/NOMBRE_DEL_DIRECTORIO_DE_MEDIDAS/<experimentName>/latest/
```

Para `ILC_8waveforms_20260624`, con `structuralSupportWaveformCount >= 6` y `thr095`, se espera Common168. Ese número debe salir de `nCommon`, no estar escrito a mano en el código.

1. `01_generacion_modelos/run_composite_8wf.m`
   Genera modelos composite específicos de 300 regresores para las 8 waveforms.

2. `02_modelo_comun/build_common_structure_from_composite.m`
   Analiza la estructura común entre las 8 waveforms usando correlación estructural y genera los CSVs `common_structure_thrXXX`.

3. Modelo común filtrado por el maestro
   El maestro lee el último `common_structure_thr095`, filtra por `structuralSupportWaveformCount >= 6`, calcula CommonK y guarda un CSV con nombre tipo `commonK_ge6_thr095_regressors.csv`.

4. `03_evaluacion/eval_commonK_vs_specific300_all8.m`
   Placeholder para una comparación futura frente a modelos específicos composite/GVG de 300 regresores. Está desactivada por defecto en el maestro.

5. `03_evaluacion/eval_tutor_pomp200_wf5.m`
   Reproduce el baseline del tutor en WF5 usando compositeall + POMP200.

6. `03_evaluacion/eval_common171_tutor_method_wf5.m`
   Script histórico de WF5. No forma parte del flujo principal CommonK.

7. `03_evaluacion/eval_commonK_vs_pomp200_all8.m`
   Extiende la comparación tutor-method a las 8 waveforms: POMP200 específico vs CommonK. El número de regresores comunes se lee del CSV indicado por el maestro. También guarda `yhatValCommonK{wf}`, que se usa como señal candidata `dpd(k).yvalmod`.

8. `05_lab_testDPD/`
   Herramientas offline para crear y validar el paquete compatible con `main_testDPD_ADRV_v2060226.m`. El maestro llama automáticamente a `create_testDPD_package_from_commonK.m` si `cfg.createTestDPDPackage = true`.

## Paquete testDPD

El pipeline genera dentro del run:

```text
results/common_model_experiments/<measurementDirName>/<experimentName>/<runStamp>/testDPD/
```

con:

```text
experiment<filenamedate>.mat
experiment<filenamedate>_xy_execution.mat
testDPD_manifest.csv
testDPD_summary.txt
run_testDPD_commonK_generated.m
```

El campo crítico para laboratorio es:

```matlab
dpd(k).yvalmod
```

El pipeline lo rellena con:

```matlab
yhatValCommonK{wf}
```

`main_testDPD_ADRV_v2060226.m` aplicará CFR internamente:

```matlab
xCFR = CFR_hard(x, 15);
```

La generación del paquete no ejecuta hardware. El hardware solo se ejecuta cuando se lance manualmente:

```matlab
filenamedate = '...';
main_testDPD_ADRV_v2060226
```

## Diagnóstico WF6

Los scripts de `04_diagnostico_wf6/` se usan para analizar la anomalía de WF6, que presenta NMSE pobre incluso con modelos específicos.

## Archivos Archivados

La carpeta `_archive_no_definitivo/` contiene scripts exploratorios o superados por versiones más definitivas.

## Comando Principal

Desde la raíz del repositorio:

```matlab
run('analisis_8WF/run_full_commonK_pipeline_8wf.m')
```

Los scripts internos pueden existir para mantenimiento o depuración, pero el flujo oficial es el maestro CommonK.
