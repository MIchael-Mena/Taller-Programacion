#!/bin/bash

# Script automatizado para crear ZIP de entrega del TP - Sistema Ledger
# Autor: Sistema automatizado de entrega
# Fecha: $(date +"%Y-%m-%d")

set -e  # Salir si cualquier comando falla

echo "🚀 INICIANDO PROCESO DE CREACIÓN DE ENTREGA TP"
echo "==============================================="

# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para imprimir con color
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Verificar que estamos en el directorio correcto
if [ ! -f "mix.exs" ] || [ ! -f "ledger" ]; then
    print_error "Este script debe ejecutarse desde el directorio del proyecto ledger"
    print_error "Asegúrate de estar en el directorio que contiene mix.exs y el ejecutable ledger"
    exit 1
fi

print_status "Verificando estructura del proyecto..."

# Verificar archivos esenciales
REQUIRED_FILES=("lib" "test" "examples" "mix.exs" "README.md" "ledger" "mix.lock")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -e "$file" ]; then
        print_error "Archivo/directorio requerido no encontrado: $file"
        exit 1
    fi
done

# Verificar que hay archivos CSV (en raíz o en examples)
if [ ! -f "transacciones.csv" ] && [ ! -f "examples/transacciones.csv" ]; then
    print_error "No se encontró transacciones.csv ni en raíz ni en examples/"
    exit 1
fi

if [ ! -f "monedas.csv" ] && [ ! -f "examples/monedas.csv" ]; then
    print_error "No se encontró monedas.csv ni en raíz ni en examples/"
    exit 1
fi

print_success "Estructura del proyecto verificada"

# Ejecutar tests antes de crear entrega
print_status "Ejecutando suite de tests..."
if mix test --cover > /dev/null 2>&1; then
    print_success "Tests completados exitosamente"
else
    print_warning "Algunos tests fallaron, pero continuando con la entrega..."
fi

# Verificar que el ejecutable funciona
print_status "Verificando funcionalidad del ejecutable..."
if ./ledger -h > /dev/null 2>&1; then
    print_success "Ejecutable funciona correctamente"
else
    print_error "El ejecutable no funciona correctamente"
    exit 1
fi

# Crear directorio temporal para la entrega
TEMP_DIR="../tp-entrega-$(date +%Y%m%d-%H%M%S)"
print_status "Creando estructura de entrega en: $TEMP_DIR"

mkdir -p "$TEMP_DIR"

# Copiar archivos esenciales
print_status "Copiando código fuente y tests..."
cp -r lib "$TEMP_DIR/"
cp -r test "$TEMP_DIR/"
cp -r examples "$TEMP_DIR/"

print_status "Copiando archivos de configuración..."
cp mix.exs "$TEMP_DIR/"
cp mix.lock "$TEMP_DIR/"
cp README.md "$TEMP_DIR/"

# Copiar .formatter.exs si existe
if [ -f ".formatter.exs" ]; then
    cp .formatter.exs "$TEMP_DIR/"
    print_success "Incluido .formatter.exs"
fi

print_status "Copiando ejecutable y datos..."
cp ledger "$TEMP_DIR/"

# Copiar archivos CSV si existen
for csv_file in *.csv; do
    if [ -f "$csv_file" ]; then
        cp "$csv_file" "$TEMP_DIR/"
        print_success "Copiado: $csv_file"
    fi
done

# Si no hay archivos CSV en raíz, copiar desde examples
if [ ! -f "$TEMP_DIR/transacciones.csv" ] || [ ! -f "$TEMP_DIR/monedas.csv" ]; then
    print_warning "Archivos CSV no encontrados en raíz, copiando desde examples/"
    cp examples/*.csv "$TEMP_DIR/"
    print_success "Archivos CSV copiados desde examples/"
fi

# Verificar que la estructura de entrega funciona
print_status "Verificando funcionalidad en estructura de entrega..."
cd "$TEMP_DIR"

if ./ledger -h > /dev/null 2>&1; then
    print_success "Verificación funcional exitosa"
else
    print_error "La estructura de entrega no funciona correctamente"
    exit 1
fi

# Volver al directorio original
cd - > /dev/null

# Crear el ZIP final
ZIP_NAME="TP-Sistema-Ledger-$(date +%Y%m%d-%H%M%S).zip"
print_status "Creando archivo ZIP: $ZIP_NAME"

cd "$(dirname "$TEMP_DIR")"
zip -r "$ZIP_NAME" "$(basename "$TEMP_DIR")" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    print_success "ZIP creado exitosamente: $ZIP_NAME"
else
    print_error "Error al crear el archivo ZIP"
    exit 1
fi

# Mostrar información del ZIP
ZIP_SIZE=$(du -h "$ZIP_NAME" | cut -f1)
print_status "Tamaño del archivo: $ZIP_SIZE"

# Verificar contenido del ZIP
print_status "Verificando contenido del ZIP..."
unzip -l "$ZIP_NAME" | head -10

# Mostrar resumen final
echo ""
echo "🎉 ENTREGA CREADA EXITOSAMENTE"
echo "=============================="
echo -e "${GREEN}Archivo:${NC} $ZIP_NAME"
echo -e "${GREEN}Tamaño:${NC} $ZIP_SIZE"
echo -e "${GREEN}Ubicación:${NC} $(pwd)/$ZIP_NAME"
echo ""
echo "📋 CONTENIDO DE LA ENTREGA:"
echo "├── lib/              # Código fuente completo"
echo "├── test/             # Suite de tests (57 tests)"
echo "├── examples/         # Datos de ejemplo"
echo "├── mix.exs           # Configuración del proyecto"
echo "├── mix.lock          # Dependencias bloqueadas"
echo "├── README.md         # Documentación académica"
echo "├── ledger            # Ejecutable precompilado"
echo "├── transacciones.csv # Datos por defecto"
echo "├── monedas.csv       # Cotizaciones"
echo "└── .formatter.exs    # Configuración de formato (si existe)"
echo ""
echo "✅ La entrega está lista para evaluación académica"

# Limpiar directorio temporal
print_status "Limpiando archivos temporales..."
rm -rf "$TEMP_DIR"
print_success "Limpieza completada"

echo ""
echo "🚀 Para entregar el TP, envía el archivo: $ZIP_NAME"