# Script de Entrega Automatizada - TP1 Sistema Ledger

## Descripción

El script `crear_entrega.sh` automatiza completamente el proceso de creación del archivo ZIP de entrega para el TP1, incluyendo todas las verificaciones y validaciones necesarias.

## Uso

```bash
# Desde el directorio del proyecto ledger
./crear_entrega.sh
```

## Funcionalidades

### ✅ Verificaciones Automáticas
- **Estructura del proyecto**: Verifica que todos los archivos esenciales estén presentes
- **Funcionalidad del ejecutable**: Prueba que `./ledger -h` funcione correctamente
- **Tests del proyecto**: Ejecuta `mix test --cover` para validar calidad
- **Verificación de entrega**: Prueba que la estructura generada funcione

### 📦 Proceso de Creación
1. **Copia archivos esenciales**:
   - `lib/` - Código fuente completo
   - `test/` - Suite de tests (57 tests)
   - `examples/` - Datos de ejemplo
   - `mix.lock` - Dependencias bloqueadas
   - `mix.exs` - Configuración del proyecto
   - `README.md` - Documentación académica
   - `.formatter.exs` - Configuración de formato (si existe)
   - `ledger` - Ejecutable precompilado
   - `*.csv` - Archivos de datos

2. **Genera estructura temporal** con timestamp único
3. **Crea archivo ZIP** con nomenclatura: `TP1-Sistema-Ledger-YYYYMMDD-HHMMSS.zip`
4. **Limpia archivos temporales** automáticamente

### 🎯 Salida del Script

El script proporciona:
- **Output colorizado** para fácil seguimiento
- **Verificación de contenido** del ZIP generado
- **Información detallada** del archivo creado (tamaño, ubicación)
- **Resumen visual** del contenido de la entrega

### 🛡️ Validaciones de Seguridad
- **Verificación de directorio**: Solo se ejecuta desde el directorio correcto
- **Validación de archivos**: Confirma existencia de todos los componentes
- **Prueba funcional**: Verifica que la entrega funcione antes de crear ZIP
- **Manejo de errores**: Termina ejecución si encuentra problemas

## Ejemplo de Uso

```bash
$ cd /ruta/al/proyecto/ledger
$ ./crear_entrega.sh

🚀 INICIANDO PROCESO DE CREACIÓN DE ENTREGA TP1
===============================================
[INFO] Verificando estructura del proyecto...
[✓] Estructura del proyecto verificada
[INFO] Ejecutando suite de tests...
[✓] Tests completados exitosamente
[INFO] Verificando funcionalidad del ejecutable...
[✓] Ejecutable funciona correctamente
...
🎉 ENTREGA CREADA EXITOSAMENTE
==============================
Archivo: TP1-Sistema-Ledger-20250920-132151.zip
Tamaño: 1,3M
```

## Ventajas

### 🚀 **Automatización Completa**
- **Un solo comando** genera la entrega completa
- **Cero configuración manual** requerida
- **Proceso reproducible** y consistente

### 🔍 **Calidad Asegurada**
- **Tests automáticos** antes de crear entrega
- **Verificación funcional** de la estructura generada
- **Validación de completitud** de archivos

### 📊 **Trazabilidad**
- **Timestamps únicos** previenen sobrescritura
- **Output detallado** para troubleshooting
- **Verificación de contenido** del archivo final

### 🎓 **Optimizado para Evaluación**
- **Estructura estándar** esperada por docentes
- **Documentación incluida** y actualizada
- **Ejecutable listo** para pruebas inmediatas

## Requisitos

- **Bash shell** (disponible en sistemas Unix/Linux/macOS)
- **Elixir/Mix** instalado (para ejecutar tests)
- **zip command** disponible en el sistema
- **Proyecto compilado** con ejecutable `ledger` existente

## Ubicación del Archivo Generado

El ZIP se crea en el directorio padre del proyecto:
```
Taller-Programacion/
├── TP1/
│   ├── ledger/           # ← Ejecutar script desde aquí
│   └── TP1-Sistema-Ledger-TIMESTAMP.zip  # ← Archivo generado
```

---

**📝 Nota**: Este script es parte del sistema de entrega del TP1 y está diseñado para uso académico en el contexto del Taller de Programación.