# Ejemplos de Uso del Ledger

Este directorio contiene archivos CSV de ejemplo que demuestran las funcionalidades del sistema ledger.

## Archivos Incluidos

- **`transacciones.csv`** - Transacciones de ejemplo con diferentes tipos
- **`monedas.csv`** - Monedas soportadas con sus cotizaciones en USD

## Explicación de los Datos de Ejemplo

### Flujo de Transacciones

El archivo `transacciones.csv` muestra un flujo realista de un sistema ledger:

```csv
1;1754800000;USDT;;1000.0;userA;;alta_cuenta
2;1754900000;BTC;;1.0;userC;;alta_cuenta  
3;1754937004;USDT;USDT;100.5;userA;userB;transferencia
4;1755541804;USDT;USDT;25.0;userB;userA;transferencia
5;1757751404;ETH;BTC;5.0;userA;;swap
```

**Explicación cronológica:**

1. **userA** se crea con saldo inicial de 1000 USDT
2. **userC** se crea con saldo inicial de 1 BTC  
3. **userA** transfiere 100.5 USDT a **userB** (userB se crea implícitamente)
4. **userB** devuelve 25 USDT a **userA**
5. **userA** hace un swap: cambia 5 ETH por BTC

### Tipos de Creación de Cuentas

**Cuentas con `alta_cuenta`:**
- `userA`: Creada explícitamente con 1000 USDT inicial
- `userC`: Creada explícitamente con 1 BTC inicial

**Cuentas implícitas:**
- `userB`: Creada automáticamente al recibir la primera transferencia

### Balances Resultantes

```bash
# userA: Saldo inicial + transferencias + swap
../ledger balance -c1=userA
# BTC=5.000000, ETH=-5.000000, USDT=924.500000

# userB: Solo transferencias recibidas/enviadas  
../ledger balance -c1=userB
# USDT=75.500000

# userC: Solo saldo inicial
../ledger balance -c1=userC
# BTC=1.000000
```

## Comandos de Prueba

Desde el directorio del proyecto (`../`):

```bash
# Ver todas las transacciones
../ledger transacciones

# Ver balance de cada usuario
../ledger balance -c1=userA
../ledger balance -c1=userB  
../ledger balance -c1=userC

# Convertir balance a BTC
../ledger balance -c1=userA -m=BTC

# Filtrar transacciones por usuario
../ledger transacciones -c1=userA
../ledger transacciones -c2=userB
```