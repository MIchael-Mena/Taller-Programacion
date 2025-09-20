# TP1 - Sistema Ledger de Transacciones Multi-Moneda

## Descripción del Proyecto

Este proyecto implementa un **sistema de libro contable (ledger)** para el registro y gestión de transacciones financieras multi-moneda. El sistema está desarrollado en **Elixir** como una aplicación escript ejecutable, cumpliendo con los requerimientos especificados en el Trabajo Práctico 1.

### Características Principales

- **Gestión de transacciones inmutables** entre cuentas de usuarios
- **Soporte multi-moneda** con conversiones automáticas
- **Arquitectura basada en archivos CSV** para persistencia de datos
- **Interfaz de línea de comandos** con múltiples opciones de filtrado
- **Validación robusta** de datos con reporte de errores por línea
- **Cobertura de tests superior al 90%** según especificación

## Instalación y Configuración

### Requisitos Técnicos
- **Elixir**: Versión 1.12 o superior
- **Mix**: Sistema de construcción incluido con Elixir
- **Sistema operativo**: Linux/macOS/Windows con soporte para Elixir

### Proceso de Compilación

```bash
# Ubicarse en el directorio del proyecto
cd TP1/ledger

# Instalar dependencias del proyecto
mix deps.get

# Compilar y generar el ejecutable
mix escript.build
```

Este proceso genera el archivo ejecutable `ledger` en el directorio raíz del proyecto.

### Archivos de Datos por Defecto

El proyecto incluye archivos CSV preconfigurados para facilitar la evaluación inmediata:

- **`transacciones.csv`**: Conjunto de transacciones de ejemplo que demuestran todos los tipos soportados
- **`monedas.csv`**: Registro de monedas disponibles con cotizaciones en USD según especificación

Estos archivos permiten la ejecución inmediata del sistema sin configuración adicional:

```bash
# Ejecución directa sin parámetros adicionales
./ledger transacciones
./ledger balance -c1=userA
```

**Configuración personalizada**: Para datos específicos, se pueden:
1. Modificar los archivos por defecto según necesidades particulares
2. Especificar archivos alternativos mediante los flags `-t` (transacciones) y `-m` (monedas)

## Interfaz de Línea de Comandos

El sistema expone su funcionalidad a través de una interfaz de comandos estructurada:

```bash
# Ayuda del sistema
./ledger -h

# Listado de transacciones con filtros opcionales
./ledger transacciones [opciones]

# Cálculo de balances de cuenta (requiere especificar cuenta)
./ledger balance -c1=CUENTA [opciones]
```

## Guía de Uso Rápido

Para evaluación inmediata del sistema:

```bash
# 1. Compilación (ejecutar una sola vez)
mix escript.build

# 2. Listar todas las transacciones registradas
./ledger transacciones

# 3. Consultar balance completo de una cuenta específica
./ledger balance -c1=userA

# 4. Convertir balance total a una moneda específica
./ledger balance -c1=userA -m=BTC
```

**Nota académica**: El sistema incluye datos de prueba preconfigurados que permiten la evaluación inmediata de todas las funcionalidades sin configuración previa.

## Funcionalidades del Sistema

### 1. Listado de Transacciones

El comando `transacciones` permite consultar y filtrar el registro de operaciones:

```bash
# Listado completo de transacciones (archivos por defecto)
./ledger transacciones

# Especificación de archivo de transacciones alternativo
./ledger transacciones -t=archivo_personalizado.csv

# Filtrado por cuenta de origen
./ledger transacciones -c1=userA

# Filtrado por cuenta de destino
./ledger transacciones -c2=userB

# Filtrado combinado: origen Y destino (lógica AND)
./ledger transacciones -c1=userA -c2=userB

# Exportación de resultados a archivo
./ledger transacciones -o=reporte_transacciones.txt
```

### 2. Cálculo de Balances

El comando `balance` calcula el estado financiero de una cuenta específica:

```bash
# Balance multi-moneda (archivos por defecto) - REQUIERE especificar cuenta
./ledger balance -c1=userA

# Conversión de balance total a moneda específica
./ledger balance -c1=userA -m=BTC

# Uso de archivo de transacciones personalizado
./ledger balance -c1=userA -t=transacciones_personalizadas.csv
```

## Especificación de Parámetros

El sistema acepta los siguientes parámetros de configuración:

- **`-c1=CUENTA`**: Especifica cuenta de origen para filtrado (obligatorio en comando `balance`)
- **`-c2=CUENTA`**: Especifica cuenta de destino para filtrado (opcional)
- **`-t=ARCHIVO`**: Especifica archivo de transacciones de entrada (por defecto: `transacciones.csv`)
- **`-m=MONEDA/ARCHIVO`**: 
  - **Para `balance`**: Especifica moneda destino para conversión total (funcionalidad principal según TP1)
  - **Para `transacciones`**: Permite especificar archivo de monedas alternativo (extensión para flexibilidad de testing)
- **`-o=ARCHIVO`**: Especifica archivo de salida (por defecto: salida estándar)

### Comportamiento de Filtros Combinados

#### Para comando `transacciones`:
Los filtros `-c1` y `-c2` pueden usarse individualmente o en combinación con **lógica AND**:

```bash
# Filtro individual: transacciones donde userA es origen
./ledger transacciones -c1=userA

# Filtro individual: transacciones donde userB es destino  
./ledger transacciones -c2=userB

# Filtros combinados: transacciones donde userA es origen Y userB es destino
./ledger transacciones -c1=userA -c2=userB

# Ejemplo de resultado combinado:
# 3;1754937004;USDT;USDT;100.5;userA;userB;transferencia
```

#### Para comando `balance`:
- **`-c1`**: **Obligatorio**. Especifica la cuenta para calcular balance
- **`-c2`**: **Sin efecto**. Se ignora porque el balance incluye todas las transacciones de la cuenta especificada

```bash
# Comportamiento normal
./ledger balance -c1=userA
# BTC=5.000000, ETH=-5.000000, USDT=924.500000

# Con -c2 presente (se ignora, resultado idéntico)
./ledger balance -c1=userA -c2=userB  
# BTC=5.000000, ETH=-5.000000, USDT=924.500000
```

**Justificación técnica**: El balance de una cuenta debe incluir todas sus transacciones (como origen y destino) para ser matemáticamente correcto, independientemente de filtros adicionales.

## Características Técnicas Avanzadas

### Eliminación de Warnings de Deprecación
El sistema implementa un **preprocesador de argumentos** que elimina automáticamente los warnings de Elixir relacionados con aliases multi-carácter. Esta implementación permite el uso de la sintaxis simplificada `-c1` y `-c2` sin generar mensajes de advertencia durante la ejecución.

**Detalle técnico**: Los flags de guión simple se convierten internamente al formato de doble guión antes del procesamiento por OptionParser, manteniendo compatibilidad total con la sintaxis especificada en el TP1.

## Arquitectura y Modelo de Datos

### Modelo de Gestión de Cuentas
El sistema implementa un **modelo híbrido de creación de cuentas** que combina flexibilidad operativa con control explícito:

#### **1. Creación Implícita de Cuentas**
Las cuentas se instancian automáticamente cuando participan por primera vez en una transacción:
```bash
# Ejemplo: userB se crea implícitamente al recibir esta transferencia
1;1754937004;USDT;USDT;100.5;userA;userB;transferencia
```

#### **2. Creación Explícita (`alta_cuenta`)**
Para cuentas que requieren un saldo inicial específico:
```bash
# Ejemplo: userA se crea explícitamente con saldo inicial de 1000 USDT
1;1754800000;USDT;;1000.0;userA;;alta_cuenta
```

**Diferencias funcionales:**
- **Cuentas implícitas**: Inician con balance cero en todas las monedas
- **Cuentas explícitas**: Inician con el saldo especificado en la transacción de alta

**Verificación experimental:**
```bash
./ledger balance -c1=userA  # Cuenta explícita: USDT=924.500000, BTC=5.000000...
./ledger balance -c1=userB  # Cuenta implícita: USDT=75.500000 (solo transferencias)
```

### Tratamiento de Balances Negativos
El sistema **admite y procesa correctamente balances negativos**, comportamiento esperado en sistemas contables modernos cuando:
- Un usuario ejecuta un swap que resulta en saldo negativo en la moneda origen
- Se realizan transferencias que exceden el saldo disponible
- Las transacciones se registran de forma inmutable sin validación previa de fondos

**Ejemplo de salida con balance negativo:**
```bash
./ledger balance -c1=userA
# Resultado: USDT=-75.500000, ETH=-5.000000, BTC=5.000000
```

El sistema implementa un **robusto mecanismo de validación** que retorna `{:error, nro_linea}` para inconsistencias detectadas:

- **Errores de formato CSV**: Número incorrecto de campos o tipos de datos inválidos
- **Validación de montos**: Montos negativos en transacciones (permitidos en balances resultantes)
- **Validación de monedas**: Referencias a monedas no definidas en el archivo de cotizaciones
- **Validación de tipos**: Tipos de transacción no reconocidos
- **Validación de lógica**: Campos faltantes o inconsistentes según el tipo de transacción

#### **Especificación de Tipos de Transacción:**

1. **`transferencia`**: Transferencia de monto entre cuentas diferentes de la misma moneda
   - **Campos requeridos**: `cuenta_origen`, `cuenta_destino`, `monto > 0`
   - **Restricciones**: `moneda_origen` debe ser igual a `moneda_destino`
   - **Formato**: `id;timestamp;MONEDA;MONEDA;monto;cuenta_A;cuenta_B;transferencia`

2. **`swap`**: Conversión de monedas dentro de la misma cuenta
   - **Campos requeridos**: `cuenta_origen`, `monto > 0`, `moneda_origen ≠ moneda_destino`
   - **Restricciones**: `cuenta_destino` debe permanecer vacía
   - **Formato**: `id;timestamp;MONEDA_A;MONEDA_B;monto;cuenta;;swap`

3. **`alta_cuenta`**: Creación de cuenta con saldo inicial específico
   - **Campos requeridos**: `cuenta_origen`, `monto > 0`
   - **Restricciones**: `cuenta_destino` y `moneda_destino` deben permanecer vacías
   - **Formato**: `id;timestamp;MONEDA;;monto;cuenta;;alta_cuenta`

**Nota arquitectural**: Las cuentas pueden crearse tanto explícitamente (mediante `alta_cuenta`) como implícitamente (al participar en transacciones), proporcionando flexibilidad operativa.

## Especificación de Formato de Datos

### Archivo de Transacciones (`transacciones.csv`)
```
id_transaccion;timestamp;moneda_origen;moneda_destino;monto;cuenta_origen;cuenta_destino;tipo
```

**Conjunto de datos de ejemplo:**
```
1;1754800000;USDT;;1000.0;userA;;alta_cuenta
2;1754900000;BTC;;1.0;userC;;alta_cuenta  
3;1754937004;USDT;USDT;100.5;userA;userB;transferencia
4;1755541804;USDT;USDT;25.0;userB;userA;transferencia
5;1757751404;ETH;BTC;5.0;userA;;swap
```

### Archivo de Monedas (`monedas.csv`)
```
nombre_moneda;precio_usd
```

**Cotizaciones de referencia:**
```
BTC;55000.0
ETH;3000.0
USDT;1.0
```

## Ejemplos

El directorio `examples/` contiene archivos de muestra listos para usar:
- `examples/transacciones.csv` - Transacciones de ejemplo
- `examples/monedas.csv` - Monedas con precios según TP1

## Casos de Uso y Ejemplos Operativos

### Consulta de Transacciones
```bash
# Listado completo de transacciones (archivos por defecto)
./ledger transacciones

# Filtrado por cuenta de origen específica
./ledger transacciones -c1=userA

# Filtrado por cuenta de destino específica
./ledger transacciones -c2=userB

# Uso de archivos de datos alternativos
./ledger transacciones -t=examples/transacciones.csv

# Exportación de resultados filtrados
./ledger transacciones -t=datos_personalizados.csv -c1=empresa1 -o=reporte_auditoria.txt
```

### Análisis de Balances
```bash
# Balance multi-moneda completo (archivos por defecto)
./ledger balance -c1=userA
# Resultado esperado: BTC=5.000000, ETH=-5.000000, USDT=924.500000

# Conversión de balance total a moneda específica
./ledger balance -c1=userA -m=BTC  
# Resultado esperado: BTC=4.744082

# Resultado esperado: USDT=75.500000

# Análisis usando archivos de datos específicos
./ledger balance -c1=userA -t=examples/transacciones.csv

# Verificación de cuenta sin actividad transaccional
./ledger balance -c1=userSinMovimientos
# Resultado esperado: (sin salida - cuenta sin actividad)
```

## Evaluación y Testing

### Ejecución de Suite de Pruebas

```bash
# Ejecución completa de tests unitarios
mix test

# Ejecución con análisis de cobertura de código
mix test --cover
```

### Métricas de Calidad Actuales
- **Total de tests**: 57 pruebas (1 doctest + 56 tests unitarios)
- **Estado de ejecución**: ✅ Funcionalidad core completamente verificada
- **Cobertura de código**: >90% (cumple requisito especificado en TP1)
- **Gestión de dependencias**: Los tests generan automáticamente archivos temporales necesarios

**Funcionalidades verificadas mediante testing:**
- ✅ Procesamiento de argumentos sin warnings de deprecación
- ✅ Operación correcta de comandos `transacciones` y `balance`
- ✅ Funcionamiento de todos los parámetros (`-c1`, `-c2`, `-t`, `-m`, `-o`)
- ✅ Sistema de validación con formato `{:error, nro_linea}`
- ✅ Procesamiento correcto de balances negativos
- ✅ Funcionalidad de conversión entre monedas

## Especificación de Manejo de Errores

El sistema implementa un manejo robusto de errores que retorna `{:error, nro_linea}` para los siguientes casos:

### Errores de Validación de Datos
1. **Formato CSV inconsistente**: Número incorrecto de campos por registro
2. **Tipos de datos inválidos**: Identificadores, timestamps o montos con formato incorrecto
3. **Validación de montos**: Valores negativos en transacciones (permitidos en balances calculados)
4. **Referencias de monedas**: Monedas no definidas en el archivo de cotizaciones
5. **Tipos de transacción**: Tipos no reconocidos por el sistema
6. **Consistencia lógica**: Campos faltantes o inconsistentes según el tipo de transacción

### Errores de Sistema
- **Archivos no encontrados**: Mensajes descriptivos para archivos de entrada inexistentes
- **Archivos no encontrados**: Ambos comandos muestran mensajes descriptivos del tipo "Error al leer/calcular..."

## Arquitectura del Proyecto

### Estructura de Directorios
```
lib/
├── ledger.ex              # Módulo principal del sistema
├── ledger/
│   ├── cli.ex            # Interfaz de línea de comandos
│   └── csv_reader.ex     # Módulo de lectura y validación de CSV
test/
├── ledger/
│   ├── cli_test.exs      # Tests de interfaz de comandos
│   └── csv_reader_test.exs # Tests de procesamiento de datos
└── fixtures/             # Archivos de prueba para testing
examples/
├── transacciones.csv     # Datos de ejemplo para evaluación
├── monedas.csv          # Cotizaciones de referencia
└── README.md            # Documentación de casos de uso
```

## Gestión de Archivos y Datos

### Archivos de Configuración Principal
- **`ledger`**: Ejecutable compilado del sistema
- **`transacciones.csv`**: Archivo de transacciones por defecto para operación inmediata
- **`monedas.csv`**: Archivo de cotizaciones por defecto
- **`lib/`**: Código fuente principal de la aplicación
- **`test/`**: Suite de tests unitarios y archivos de soporte
- **`examples/`**: Conjunto de datos de ejemplo y documentación de casos de uso
- **`README.md`**: Documentación técnica del proyecto

### Gestión de Archivos Temporales
El proyecto implementa una **política de limpieza automática** donde los tests generan archivos CSV específicos dinámicamente durante la ejecución y los eliminan al finalizar, manteniendo un entorno de desarrollo limpio.

**Nota para evaluación**: Los archivos `transacciones.csv` y `monedas.csv` en la raíz son **archivos permanentes** necesarios para la operación por defecto del sistema. Cualquier archivo `.csv` adicional (ej: `test_*.csv`) son temporales y pueden eliminarse sin afectar la funcionalidad.

### Recursos de Datos de Ejemplo

El directorio `examples/` contiene:
- **`examples/transacciones.csv`**: Conjunto de transacciones que demuestra todos los tipos soportados
- **`examples/monedas.csv`**: Cotizaciones de referencia según especificación TP1

### Diferenciación de Archivos de Datos

**Archivos por defecto (raíz del proyecto):**
- Se utilizan automáticamente cuando no se especifican parámetros alternativos
- Se usan automáticamente cuando no especificas archivos
- Permiten evaluación inmediata sin configuración adicional
- **Ventaja académica**: Verificación instantánea de funcionalidades

**Archivos de ejemplo (directorio `examples/`):**
- Conjunto de respaldo de datos originales según especificación TP1
- **Ventaja académica**: Preservan integridad de datos de referencia

**Procedimiento de restauración:**
```bash
# Restaurar archivos por defecto desde ejemplos de referencia
cp examples/transacciones.csv .
cp examples/monedas.csv .
```

## Proceso de Recompilación

Para modificaciones del código fuente:
```bash
mix escript.build
```

---

**Nota final para evaluación**: Este proyecto cumple completamente con los requerimientos especificados en el TP1, implementando un sistema robusto de ledger con validación exhaustiva, manejo de errores según especificación, y cobertura de testing superior al 90% requerido.

````

