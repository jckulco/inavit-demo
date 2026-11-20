# Nota sobre esta versión

Esta es la versión **genérica y pública** de este proyecto de demostración de arquitectura Data Fabric.

- Todos los datos utilizados son **100% sintéticos** (catálogos de municipios, nombres de empresas y trabajadores, RFCs, CURPs, NSS y cuentas generados mediante scripts con faker/generadores deterministas).
- La institución ("INAVIT") es una entidad ficticia inspirada en esquemas de fondos nacionales de vivienda y aportaciones patronales.
- Los archivos binarios pesados de export (`*.zip` de Netezza, DataStage y Cognos) se excluyen del repositorio por tamaño y para seguir buenas prácticas de control de versiones. Pueden regenerarse siguiendo las guías incluidas en la carpeta `docs/`.
