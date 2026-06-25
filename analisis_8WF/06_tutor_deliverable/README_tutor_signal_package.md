# Tutor Signal Package

Este entregable se genera automaticamente desde:

```matlab
run('analisis_8WF/run_full_commonK_pipeline_8wf.m')
```

No se debe ejecutar manualmente en el flujo normal.

## Contenido

El paquete contiene:

- `signals_specific_POMP200.mat`: estructura `specificSignals`, una entrada por waveform.
- `signals_common_CommonK.mat`: estructura `commonSignals`, una entrada por waveform.
- `signals_combined_specific_and_common.mat`: ambas estructuras y `signalPackageMetadata`.
- `tutor_signal_manifest.csv`: una fila por senal.
- `tutor_signal_package_summary.txt`: resumen del paquete.
- `README_tutor_signal_package.md`: esta descripcion.
- `tutor_signal_package_<measurementTag>_<experimentName>_<runStamp>.zip`: ZIP del entregable.

## Fuentes de senal

Las senales especificas POMP200 salen de:

```matlab
yhatValPOMP200{wf}
```

Las senales comunes CommonK salen de:

```matlab
yhatValCommonK{wf}
```

Ambas son predicciones de validacion reconstruidas por los modelos. Confirmar la convencion de bloque antes de inyeccion final en laboratorio.

## Relacion con testDPD

El paquete `testDPD` puede exportar:

- `commonK_only`
- `specific_only`
- `both`

Para el entregable actual, el maestro usa:

```matlab
cfg.testDPDExportMode = 'both';
```

Con `both`, `main_testDPD_ADRV_v2060226.m` recorrera `numel(dpd)` y medira 16 senales: 8 especificas POMP200 y 8 comunes CommonK.
