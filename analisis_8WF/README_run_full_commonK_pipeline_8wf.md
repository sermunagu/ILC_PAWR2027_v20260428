# `run_full_commonK_pipeline_8wf.m`

Script maestro para ejecutar el flujo completo CommonK sobre una campaña de 8 waveforms ILC.

El modelo común no está fijado a un número concreto de regresores. El maestro calcula automáticamente:

```matlab
nCommon = height(Tfiltered);
commonLabel = sprintf('common%d', nCommon);
```

donde `Tfiltered` sale de filtrar el último CSV `common_structure_thr095` de la campaña con:

```matlab
T.(cfg.commonSupportColumn) >= cfg.commonSupportThreshold
```

La configuración por defecto usa:

```matlab
cfg.measurementDirName = 'ILC_8waveforms_20260624';
cfg.commonCorrelationThreshold = 0.95;
cfg.commonSupportColumn = 'structuralSupportWaveformCount';
cfg.commonSupportThreshold = 6;
cfg.experimentName = '';

cfg.createTestDPDPackage = true;
cfg.createTutorSignalPackage = true;
cfg.testDPDBaseExperimentDate = '';
cfg.testDPDBaseExperimentMat = '';
cfg.testDPDSignalSource = 'yhatValCommonK';
cfg.testDPDExportMode = 'both';
cfg.copyTestDPDPackageToResultsRoot = false;
```

For `ILC_8waveforms_20260624`, this criterion is expected to produce Common168. The code still derives that value from `nCommon`; it is not hardcoded.

Si `cfg.experimentName` está vacío, el maestro genera un nombre tipo:

```text
commonK_struct_ge6_thr095
```

## Ejecución

Desde cualquier carpeta de MATLAB:

```matlab
run('analisis_8WF/run_full_commonK_pipeline_8wf.m')
```

## Flujo

1. Detecta automáticamente `repoRoot`.
2. Añade las rutas necesarias.
3. Verifica las 8 medidas `results/<measurementDirName>/experiment*_xy.mat`.
4. Genera o reutiliza modelos composite.
5. Genera o reutiliza el análisis `common_structure_thr095`.
6. Filtra por soporte estructural y construye CommonK.
7. Evalúa CommonK frente a POMP200 específico por waveform.
8. Guarda `yhatValCommonK{wf}` y señales alineadas en el `.mat` de evaluación.
9. Guarda `yhatValPOMP200{wf}` y señales alineadas POMP200 en el `.mat` de evaluación.
10. Genera el paquete del tutor con señales específicas POMP200 y CommonK.
11. Genera y valida el paquete `testDPD` según `cfg.testDPDExportMode`.
12. Guarda el run timestamped y actualiza el alias `latest/`.

## Salidas

Cada ejecución se conserva en:

```text
results/common_model_experiments/<measurementDirName>/<experimentName>/<runStamp>/
```

Dentro se guardan:

- `<commonLabel>_ge6_thr095_regressors.csv`
- `<commonLabel>_vs_pomp200_all8_<measurementTag>_<runStamp>.csv`
- `<commonLabel>_vs_pomp200_all8_<measurementTag>_<runStamp>.mat`
- `<commonLabel>_lab_package_<measurementTag>_<runStamp>.mat`
- `<commonLabel>_summary_<measurementTag>_<runStamp>.txt`
- `<commonLabel>_manifest_<measurementTag>_<runStamp>.csv`
- `tutor_signal_package/`
- `testDPD/experiment<filenamedate>.mat`
- `testDPD/experiment<filenamedate>_xy_execution.mat`
- `testDPD/testDPD_manifest.csv`
- `testDPD/testDPD_summary.txt`
- `testDPD/run_testDPD_commonK_generated.m`

El alias cómodo se actualiza en:

```text
results/common_model_experiments/<measurementDirName>/<experimentName>/latest/
```

con:

- `latest_common_regressors.csv`
- `latest_common_vs_pomp200_all8.csv`
- `latest_lab_package.mat`
- `latest_summary.txt`
- `latest_manifest.csv`
- `tutor_signal_package/`
- `testDPD/`

## Paquete del Tutor

Si:

```matlab
cfg.createTutorSignalPackage = true;
```

el maestro llama automaticamente a:

```matlab
analisis_8WF/06_tutor_deliverable/create_tutor_signal_package_commonK.m
```

El paquete se guarda en:

```text
results/common_model_experiments/<measurementDirName>/<experimentName>/<runStamp>/tutor_signal_package/
```

y como alias en:

```text
results/common_model_experiments/<measurementDirName>/<experimentName>/latest/tutor_signal_package/
```

Contiene:

- `signals_specific_POMP200.mat` con `specificSignals`.
- `signals_common_CommonK.mat` con `commonSignals`.
- `signals_combined_specific_and_common.mat` con `specificSignals`, `commonSignals` y `signalPackageMetadata`.
- `tutor_signal_manifest.csv`.
- `tutor_signal_package_summary.txt`.
- `README_tutor_signal_package.md`.
- `tutor_signal_package_<measurementTag>_<experimentName>_<runStamp>.zip`.

Las fuentes son:

```matlab
yhatValPOMP200{wf}
yhatValCommonK{wf}
```

Estas son predicciones de validacion reconstruidas por los modelos. Confirmar la convencion de bloque antes de inyeccion final en laboratorio.

## Paquete `testDPD`

El maestro llama automaticamente a:

```matlab
analisis_8WF/05_lab_testDPD/create_testDPD_package_from_commonK.m
```

si:

```matlab
cfg.createTestDPDPackage = true;
```

Para crear un paquete directamente lanzable por `main_testDPD_ADRV_v2060226.m`, hay que proporcionar un experimento base que contenga `meas_out` y `exp_config`:

```matlab
cfg.testDPDBaseExperimentDate = 'YYYYMMDDTHHMMSS';
```

o:

```matlab
cfg.testDPDBaseExperimentMat = 'results/experimentYYYYMMDDTHHMMSS.mat';
```

Si no se proporciona ninguno, el pipeline intenta inferir automáticamente un `.mat` compatible desde:

```text
results/<measurementDirName>/experiment*.mat
```

buscando variables `meas_out` y `exp_config`. Si no encuentra un `.mat` base compatible y `cfg.createTestDPDPackage = true`, el pipeline falla con un error claro. El paquete se guarda siempre dentro de la carpeta del run. Para copiar los dos `.mat` a `results/` y dejarlo directamente lanzable por el script oficial:

```matlab
cfg.copyTestDPDPackageToResultsRoot = true;
```

Por seguridad, no se sobrescriben archivos existentes en `results/` salvo que:

```matlab
cfg.allowOverwriteTestDPDExactFile = true;
```

El paquete `testDPD` puede exportar:

```matlab
cfg.testDPDExportMode = 'commonK_only';
cfg.testDPDExportMode = 'specific_only';
cfg.testDPDExportMode = 'both';
```

Para el entregable actual se usa `both`. En ese caso `dpd(1:8)` son `specific_POMP200` y `dpd(9:16)` son `common_CommonK`.

`main_testDPD_ADRV_v2060226.m` aplicara CFR internamente:

```matlab
xCFR = CFR_hard(x, 15);
```

El pipeline imprime y guarda el comando:

```matlab
filenamedate = '...';
main_testDPD_ADRV_v2060226
```

## Interpretación

La evaluación calcula:

```text
delta = CommonK - POMP200
```

Por tanto:

- `delta > 0`: CommonK es peor que el POMP200 específico.
- `delta < 0`: CommonK es mejor que el POMP200 específico.

WF6 se mantiene en la tabla, pero los resúmenes incluyen medias con y sin WF6.
