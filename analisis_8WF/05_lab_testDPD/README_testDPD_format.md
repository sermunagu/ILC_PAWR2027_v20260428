# Formato `testDPD` para CommonK

Esta carpeta contiene herramientas offline para comprobar y preparar los archivos que espera `main_testDPD_ADRV_v2060226.m`. Ningún script de esta carpeta ejecuta hardware, `measureADRV`, ni `main_testDPD_ADRV_v2060226.m`.

El flujo oficial no requiere ejecutar estos scripts a mano. El maestro:

```matlab
run('analisis_8WF/run_full_commonK_pipeline_8wf.m')
```

llama automaticamente a `create_testDPD_package_from_commonK.m` si `cfg.createTestDPDPackage = true`.

## Qué espera `main_testDPD_ADRV_v2060226.m`

El script oficial asume que existe una variable `filenamedate` y carga:

```matlab
load(['results' filesep 'experiment' filenamedate], 'meas_out', 'exp_config')
load(['results' filesep 'experiment' filenamedate '_xy_execution'], 'dpd')
```

Después usa estos campos:

- `meas_out(1).u`
- `exp_config.captureTime`
- `dpd(k).yvalmod`
- `dpd(k).modeltype`

Por tanto, los archivos requeridos son:

```text
results/experiment<filenamedate>.mat
results/experiment<filenamedate>_xy_execution.mat
```

## Validar antes del laboratorio

La validacion principal se hace automaticamente al crear el paquete desde el maestro. El script `validate_testDPD_inputs_commonK.m` queda como herramienta auxiliar para revisar manualmente un par de archivos existente.

Editar al principio de:

```matlab
analisis_8WF/05_lab_testDPD/validate_testDPD_inputs_commonK.m
```

como mínimo:

```matlab
cfg.filenamedate = 'YYYYMMDDTHHMMSS';
cfg.expectedNumSignals = [];
```

Ejecutar:

```matlab
run('analisis_8WF/05_lab_testDPD/validate_testDPD_inputs_commonK.m')
```

El validador comprueba existencia de archivos, campos obligatorios, longitudes, NaN/Inf, potencia y PAPR. Guarda CSV/TXT de informe en la carpeta `latest/` del experimento CommonK si puede inferirla, o en una carpeta de informes bajo `results/common_model_experiments/`.

## Exportar `_xy_execution.mat`

El exportador manual queda como herramienta auxiliar. El flujo principal usa `create_testDPD_package_from_commonK.m`, que toma la senal candidata directamente del `.mat` de evaluacion CommonK.

Editar:

```matlab
analisis_8WF/05_lab_testDPD/export_commonK_to_testDPD_format.m
```

campos mínimos:

```matlab
cfg.filenamedate = 'YYYYMMDDTHHMMSS';
cfg.commonLabel = 'commonK';
cfg.yvalmodSourceMat = 'ruta/a/fuente_con_yvalmod.mat';
cfg.yvalmodVariable = 'yvalmod';
```

La fuente debe contener una señal `yvalmod`, una matriz con señales por columnas, un cell array de señales, o una estructura `dpd` ya existente. El exportador no inventa la señal a inyectar.

Ejecutar:

```matlab
run('analisis_8WF/05_lab_testDPD/export_commonK_to_testDPD_format.m')
```

Por seguridad, si ya existe:

```text
results/experiment<filenamedate>_xy_execution.mat
```

el exportador no lo sobrescribe por defecto. En ese caso genera un candidato con timestamp:

```text
results/experiment<filenamedate>_xy_execution_<commonLabel>_<timestamp>.mat
```

Solo escribirá el nombre exacto si no existe previamente, o si se activa explícitamente:

```matlab
cfg.allowOverwriteExactXYExecution = true;
```

## Campos mínimos de `dpd`

Cada entrada debe contener:

- `dpd(k).yvalmod`: vector numérico real o complejo que se inyectará en `testDPD`.
- `dpd(k).modeltype`: texto descriptivo, por ejemplo `common168` o `common168_POMP200_comparison`.

Si la fuente ya contiene una estructura `dpd` con más campos, el exportador conserva esos campos.

En el paquete generado por el maestro, la fuente oficial es:

```matlab
dpd(k).yvalmod = yhatValCommonK{wf};
```

El `modeltype` se genera como:

```matlab
sprintf('%s_struct_ge6_thr095_WF%02d', commonLabel, wf)
```

Campos extra incluidos por el maestro:

- `dpd(k).commonLabel`
- `dpd(k).nCommon`
- `dpd(k).waveformIndex`
- `dpd(k).measurementDirName`
- `dpd(k).experimentName`
- `dpd(k).runStamp`
- `dpd(k).signalSource`
- `dpd(k).createdBy`

El paquete se guarda en:

```text
results/common_model_experiments/<measurementDirName>/<experimentName>/<runStamp>/testDPD/
```

con alias en:

```text
results/common_model_experiments/<measurementDirName>/<experimentName>/latest/testDPD/
```

Para lanzamiento directo del script oficial, los dos `.mat` deben estar en `results/`:

```text
results/experiment<filenamedate>.mat
results/experiment<filenamedate>_xy_execution.mat
```

El maestro solo copia esos archivos a `results/` si:

```matlab
cfg.copyTestDPDPackageToResultsRoot = true;
```

Si `cfg.testDPDBaseExperimentMat` y `cfg.testDPDBaseExperimentDate` estan vacios, el maestro intenta inferir un `.mat` base desde:

```text
results/<measurementDirName>/experiment*.mat
```

El candidato debe contener `meas_out` y `exp_config`. Si no existe un candidato compatible, el pipeline falla antes de producir un paquete que parezca lanzable.

El hardware solo se ejecuta cuando se lance manualmente:

```matlab
filenamedate = '...';
main_testDPD_ADRV_v2060226
```

## Qué no hacen estos scripts

- No ejecutan `measureADRV`.
- No conectan con ADRV.
- No ejecutan `main_testDPD_ADRV_v2060226.m`.
- No borran resultados previos.
- No sobrescriben el `_xy_execution.mat` exacto salvo confirmación explícita en configuración.
