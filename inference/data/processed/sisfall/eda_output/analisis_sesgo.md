# Analisis de sesgo SisFall

## Hallazgos principales

- Sujetos totales: 38 (23 adultos, 15 mayores).
- Ensayos totales: 4396; caidas: 1744; ADL: 2652.
- Las caidas de SisFall son simuladas; el dataset es valido para el sprint por su soporte academico, pero este sesgo debe aparecer en el informe tecnico.
- Sujetos mayores sin ensayos de caida: 14 (SE01, SE02, SE03, SE04, SE05, SE07, SE08, SE09, SE10, SE11, SE12, SE13, SE14, SE15).
- La validacion posterior debe partir por sujeto (GroupKFold/LOSO) para evitar fuga entre ensayos.

## Balance por edad y sexo

| age_group | sex | n_trials | n_falls | n_subjects | fall_rate |
| --- | --- | --- | --- | --- | --- |
| adult | F | 1730 | 844 | 12 | 0.4879 |
| adult | M | 1693 | 825 | 11 | 0.4873 |
| elderly | F | 406 | 0 | 7 | 0.0 |
| elderly | M | 567 | 75 | 8 | 0.1323 |

## Implicacion para ML

Un modelo puede aprender patrones de sujetos adultos jovenes que no generalicen igual en mayores. Para SL-17/SL-18 se debe reportar recall de caidas y revisar folds con sujetos mayores.
