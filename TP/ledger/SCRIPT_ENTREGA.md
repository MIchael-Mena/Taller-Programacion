# Script de Entrega Automatizada - TP2 Sistema Ledger

## Descripción

El script `crear_entrega.sh` automatiza completamente el proceso de creación del archivo ZIP de entrega para el **TP2**, incluyendo todas las verificaciones y validaciones necesarias para el sistema completo con base de datos PostgreSQL.

## Uso

```bash
# Ejecución básica (elimina carpeta temporal automáticamente)
./crear_entrega.sh

# Mantener carpeta temporal después de crear el ZIP
./crear_entrega.sh --keep-folder

# Ver ayuda y opciones disponibles
./crear_entrega.sh --help
```

### Opciones Disponibles

| Flag | Descripción |
|------|-------------|
| `--keep-folder` | Mantiene la carpeta temporal después de crear el ZIP (útil para inspección manual) |
| `-h, --help` | Muestra mensaje de ayuda con todas las opciones disponibles |

**Comportamiento por defecto**: La carpeta temporal se **elimina automáticamente** después de crear el ZIP exitosamente.

## Funcionalidades

### ✅ Verificaciones Automáticas TP2
- **Estructura del proyecto TP2**: Verifica archivos esenciales (lib, test, priv, config)
- **Migraciones de BD**: Confirma existencia de `priv/repo/migrations/`
- **Funcionalidad del ejecutable**: Prueba que `./ledger --help` funcione localmente
- **Tests del proyecto**: Ejecuta `mix test --cover` y valida 220 tests
- **Cobertura de código**: Verifica que los tests pasen (>90% en core modules)
- **Archivos de configuración**: Docker Compose, configs, Makefile
- **⚠️ Optimización de tamaño**: NO incluye ejecutable (reduce de 2.4 MB a ~144 KB)

### 📦 Proceso de Creación
1. **Copia archivos esenciales TP2**:
   - `lib/` - Código fuente completo (schemas, contexts, CLI)
     * 4 schemas: User, Currency, Account, Transaction
     * 4 contexts: Accounts, Currencies, Banking, Transactions
     * CLI principal + 4 CLI modules
     * CSV Reader (compatibilidad TP1)
   - `test/` - Suite de tests (220 tests, 95%+ coverage)
   - `priv/repo/migrations/` - Migraciones de base de datos
   - `config/` - Configuración (dev, test, prod)
   - `examples/` - Datos de ejemplo (CSVs)
   - `docs/` - Documentación visual (diagrama ER)
   - `mix.lock` - Dependencias bloqueadas
   - `mix.exs` - Configuración del proyecto
   - `README.md` - Documentación completa (2500+ líneas)
   - `BUILD.md` - **⚠️ NUEVO: Instrucciones para generar ejecutable**
   - `.formatter.exs` - Configuración de formato
   - `.gitignore` - Archivos ignorados
   - ~~`ledger`~~ - **❌ NO incluido** (los evaluadores deben generarlo)
   - `docker-compose.yml` - Setup de PostgreSQL 17
   - `Makefile` - Comandos útiles

2. **Genera estructura temporal** con timestamp único
3. **Crea archivo ZIP optimizado** con nomenclatura: `TP2-Sistema-Ledger-YYYYMMDD-HHMMSS.zip`
4. **Limpia archivos temporales** automáticamente (o mantiene con `--keep-folder`)

### 🎯 Salida del Script

El script proporciona:
- **Output colorizado** para fácil seguimiento
- **Verificación de contenido** del ZIP generado
- **Información detallada** del archivo creado (tamaño, ubicación)
- **Resumen completo** de la estructura TP2
- **Instrucciones para evaluadores** sobre cómo ejecutar el proyecto

### 🛡️ Validaciones de Seguridad
- **Verificación de directorio**: Solo se ejecuta desde el directorio correcto
- **Validación de estructura TP2**: Confirma existencia de migraciones, configs
- **Prueba de tests**: Ejecuta suite completa y verifica 220 tests passing
- **Prueba funcional**: Verifica que el ejecutable funcione antes de crear ZIP
- **Manejo de errores**: Termina ejecución si encuentra problemas

## Ejemplo de Uso

```bash
$ cd /ruta/al/proyecto/ledger
$ ./crear_entrega.sh

🚀 INICIANDO PROCESO DE CREACIÓN DE ENTREGA TP2
================================================
[INFO] Verificando estructura del proyecto TP2...
[✓] Estructura del proyecto TP2 verificada
[INFO] Ejecutando suite de tests (esto puede tomar unos momentos)...
[✓] Tests completados: 220 tests, 0 failures
[INFO] Verificando funcionalidad del ejecutable...
[✓] Ejecutable funciona correctamente
[INFO] Creando estructura de entrega en: ../tp2-entrega-20251017-220000
[INFO] Copiando código fuente...
[✓] lib/ copiado (schemas, contexts, CLI)
[INFO] Copiando tests...
[✓] test/ copiado (220 tests)
[INFO] Copiando migraciones de base de datos...
[✓] priv/ copiado (migraciones)
...
🎉 ENTREGA TP2 CREADA EXITOSAMENTE
====================================
Archivo: TP2-Sistema-Ledger-20251017-220000.zip
Tamaño: 2,5M
```

## Ventajas

### 🚀 **Automatización Completa TP2**
- **Un solo comando** genera la entrega completa con BD
- **Cero configuración manual** requerida
- **Proceso reproducible** y consistente
- **Gestión inteligente de archivos temporales** con flag `--keep-folder`

### 🔍 **Calidad Asegurada**
- **220 tests automáticos** antes de crear entrega
- **Verificación funcional** de la estructura generada
- **Validación de migraciones** y configuración BD
- **Cobertura >90%** en core modules verificada

### 🗂️ **Gestión Flexible de Archivos**
- **Por defecto**: Limpieza automática de carpeta temporal (solo queda el ZIP)
- **Con `--keep-folder`**: Mantiene carpeta para inspección manual o debugging
- **Nombrado con timestamp**: Evita sobrescrituras accidentales

### 📊 **Trazabilidad**
- **Timestamps únicos** previenen sobrescritura
- **Output detallado** para troubleshooting
- **Verificación de contenido** del archivo final
- **Contador de tests** mostrado en output

### 🎓 **Optimizado para Evaluación TP2**
- **Estructura completa** con BD y migraciones
- **Documentación exhaustiva** (README 2500+ líneas)
- **Ejecutable listo** para pruebas inmediatas
- **Docker Compose** para PostgreSQL incluido
- **Instrucciones claras** para evaluadores

### 🔄 **Compatibilidad TP1 + TP2**
- **Comandos CSV** funcionan con flag `-t`
- **Auto-detección** de modo (BD vs CSV)
- **Archivos de ejemplo** incluidos en `examples/`

## Requisitos

- **Bash shell** (disponible en sistemas Unix/Linux/macOS)
- **Elixir/Mix** instalado (para ejecutar tests)
- **zip command** disponible en el sistema
- **Proyecto compilado** con ejecutable `ledger` existente
- **PostgreSQL** (Docker recomendado, para ejecutar tests)

## Ubicación del Archivo Generado

El ZIP se crea en el directorio padre del proyecto:
```
Taller-Programacion/
├── TP/
│   ├── ledger/                          # ← Ejecutar script desde aquí
│   └── TP2-Sistema-Ledger-TIMESTAMP.zip # ← Archivo generado
```

## Contenido del ZIP Generado

```
TP2-Sistema-Ledger-TIMESTAMP/
├── lib/                   # Código fuente (4 schemas + 4 contexts + CLI)
├── test/                  # Tests (220 tests, 95%+ coverage)
├── priv/repo/migrations/  # Migraciones BD (4 tablas)
├── config/                # Configuración (dev, test, prod)
├── examples/              # Datos de ejemplo (CSVs TP1)
├── docs/                  # Documentación visual (diagrama ER)
├── mix.exs                # Configuración del proyecto
├── mix.lock               # Dependencias bloqueadas
├── README.md              # Documentación completa
├── BUILD.md               # ⚠️ Instrucciones para generar ejecutable
├── docker-compose.yml     # PostgreSQL 17 setup
├── Makefile               # Comandos útiles
├── .formatter.exs         # Formato de código
└── .gitignore             # Archivos ignorados

⚠️ NOTA: El ejecutable 'ledger' NO está incluido para cumplir límite de 2 MB.
         Tamaño del ZIP: ~144 KB (vs 2.4 MB con ejecutable)
         Los evaluadores deben generarlo con: mix escript.build
```

## Diferencias con Script TP1

| Aspecto | TP1 | TP2 |
|---------|-----|-----|
| **Tests** | 57 tests | 220 tests |
| **Cobertura** | ~70% | >90% core modules |
| **Base de Datos** | ❌ Solo CSV | ✅ PostgreSQL + Ecto |
| **Migraciones** | ❌ | ✅ priv/repo/migrations/ |
| **Entidades** | ❌ | ✅ 4 (User, Currency, Account, Transaction) |
| **Configuración** | ❌ | ✅ config/ (dev, test, prod) |
| **Docker** | ❌ | ✅ docker-compose.yml |
| **Ejecutable incluido** | ✅ Sí (2.3 MB) | ❌ No (generarlo con mix escript.build) |
| **Tamaño ZIP** | ~2.4 MB | ~144 KB |
| **Documentación** | ~500 líneas | 2500+ líneas |
| **Diagrama ER** | ❌ | ✅ docs/ledger_diagram.png |

## Instrucciones Post-Entrega para Evaluadores

Incluidas automáticamente en el output del script:

```bash
💡 RECORDATORIO PARA EVALUADORES:
   1. Descomprimir el archivo ZIP
   2. Ejecutar: docker-compose up -d (PostgreSQL)
   3. Ejecutar: mix deps.get
   4. Ejecutar: mix compile
   5. ⚠️  GENERAR EJECUTABLE: mix escript.build
   6. Ejecutar: mix ecto.create && mix ecto.migrate
   7. Probar: ./ledger --help
   8. Ejecutar tests: mix test --cover

📄 Ver BUILD.md en el ZIP para instrucciones detalladas
📖 Ver README.md para documentación completa
```

**⚠️ Nota importante**: El ejecutable `ledger` NO está incluido en el ZIP para cumplir con el límite de 2 MB de Algotrón (tamaño reducido de 2.4 MB a 144 KB). Los evaluadores deben generarlo con `mix escript.build`, lo cual toma menos de 1 minuto.

## Ejemplos de Uso

### Caso 1: Entrega Final (Limpieza Automática)
```bash
# Para entregar el TP - solo genera el ZIP y limpia la carpeta temporal
./crear_entrega.sh

# Resultado:
# - Se crea: TP2-Sistema-Ledger-20251017-230956.zip (144 KB)
# - Se elimina automáticamente la carpeta temporal
# - Solo queda el ZIP listo para subir a Algotrón
# - ✅ Cumple límite de 2 MB (reducido de 2.4 MB sin ejecutable)
```

### Caso 2: Debugging o Inspección Manual
```bash
# Si quieres revisar manualmente los archivos antes de enviar
./crear_entrega.sh --keep-folder

# Resultado:
# - Se crea: TP2-Sistema-Ledger-20251017-230956.zip (144 KB)
# - Se mantiene: ../tp2-entrega-20251017-230956/ (carpeta completa)
# - Puedes inspeccionar la carpeta y eliminarla manualmente cuando quieras
```

### Caso 3: Múltiples Versiones
```bash
# Primera versión
./crear_entrega.sh
# Crea: TP2-Sistema-Ledger-20251017-120000.zip (144 KB)

# Después de hacer cambios, segunda versión
./crear_entrega.sh
# Crea: TP2-Sistema-Ledger-20251017-150000.zip (144 KB)

# Los timestamps únicos evitan sobrescribir versiones anteriores
```

### Caso 4: Ver Ayuda
```bash
./crear_entrega.sh --help

# Muestra:
# Uso: ./crear_entrega.sh [opciones]
# 
# Opciones:
#   --keep-folder    Mantener la carpeta temporal después de crear el ZIP
#   -h, --help       Mostrar este mensaje de ayuda
```

## Requisitos
```

---

**📝 Nota**: Este script es parte del sistema de entrega del TP2 y está diseñado para uso académico. No forma parte de la entrega pero se usa para generarla. El ZIP generado cumple con los requisitos de Algotrón: excluye todo lo que está en un `.gitignore` típico de Elixir (_build, deps, .volumes, erl_crash.dump, etc.).


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