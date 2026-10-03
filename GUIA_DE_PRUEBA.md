# Guion de prueba · Módulo de inicio

Recorrido completo en ~3 minutos. La demo corre sobre la API real: cada pantalla
hace peticiones de verdad contra PostgreSQL, con bcrypt, JWT y rotación de tokens.

> **El código SMS aparece en pantalla.** En modo demostración la API devuelve el
> OTP en la respuesta (`devCode`) y la app lo muestra en un recuadro ámbar con
> un botón **Usar**. Con `DEMO_MODE=false` ese campo desaparece.

---

## 1. Bienvenida (onboarding)

Tres slides con el azul de marca, el verde dinero y el celeste.
Fíjate en el indicador inferior: la píldora activa se alarga en vez de solo
cambiar de color.

➡️ Pulsa **Crear mi cuenta**.

## 2. Registro

Cabecera con degradado `#1757D6 → #17B3E8` y círculos translúcidos; el
formulario flota en una tarjeta blanca con sombra azulada.

**Qué probar:**

| Acción | Resultado esperado |
|---|---|
| Escribe `Juan123` en Nombre | «Solo admite letras» |
| Toca la bandera 🇺🇸 | Hoja inferior con 20 países y buscador |
| Escribe `12345678` en contraseña | Barra roja «Muy débil» |
| Cámbiala a `Remesas2026$Seg` | Barra verde «Excelente» (4/4) |
| Pulsa Continuar sin marcar términos | Aviso rojo flotante |

Datos sugeridos: nombre `María`, apellido `González`, correo
`maria@demo.app`, país 🇻🇪 `+58`, teléfono `4121234567`.

➡️ Marca términos y pulsa **Continuar**.

## 3. Verificación OTP

**Qué probar:**

- Escribe un código incorrecto (`000000`): las casillas **se sacuden**, se
  pintan de rojo y el mensaje indica cuántos intentos quedan.
- El contador «Puedes pedir otro código en 00:59» corre hacia abajo; al llegar
  a cero aparece **Reenviar código**.
- Pega los 6 dígitos de golpe: se reparten solos entre las casillas.

➡️ Pulsa **Usar** en el recuadro ámbar y luego **Verificar código**.

## 4. PIN de acceso

Teclado numérico propio (no el del sistema) y puntos que crecen al llenarse.

**Qué probar:**

| Acción | Resultado esperado |
|---|---|
| Teclea `123456` | «Ese PIN es demasiado común» — lo rechaza el servidor |
| Teclea `111111` | Rechazado por dígitos repetidos |
| Teclea `284913` y repite `284914` | Vibra, puntos en rojo y vuelve a empezar |
| Teclea `284913` dos veces | Avanza al KYC |

## 5. Verificación de identidad (KYC)

Tres pasos con barra de progreso.

1. **Documento**: elige Cédula/DNI, escribe `V-24556113`.
2. **Capturas**: toca las zonas para subir dos imágenes cualesquiera
   (en navegador abre el selector de archivos; en móvil, la cámara).
   Al cargarse se ponen verdes con un check.
3. **Selfie**: toca el círculo y sube otra imagen.

➡️ **Enviar verificación**. Pasa a la pantalla de revisión con spinner; la API
simula al proveedor (Jumio/Onfido) y **aprueba sola a los 10 segundos**. La
pantalla lo detecta por polling y avanza al home sin que toques nada.

## 6. Home

- La tarjeta de saldo pasa de `$0` a **$1 000 por transacción** y aparecen los
  límites diario y mensual: es el nivel KYC 1 ya desbloqueado.
- El banner cambia de ámbar «Verificación pendiente» a verde
  «Identidad verificada».
- El panel de seguridad muestra PIN ✓ y el estado real de la biometría.

**Qué probar:**

- Toca el candado 🔒 de la cabecera → bloquea la app y pide el PIN.
  Introduce `284913` para volver. Con un PIN erróneo verás los intentos
  restantes que devuelve el servidor.
- **Dispositivos y sesiones** → lista las sesiones activas reales.
- **Cerrar sesión** y vuelve a entrar con `maria@demo.app` / `Remesas2026$Seg`:
  entra **directo, sin OTP**, porque el dispositivo ya es de confianza.

## 7. Recuperar contraseña

Desde el login → «¿Olvidaste tu contraseña?» → correo → OTP → nueva contraseña.
Si intentas reutilizar la anterior, el servidor lo impide
(`PASSWORD_REUSED`). Al cambiarla se revocan todas las sesiones.

---

## Paleta aplicada

| Color | Hex | Dónde se ve |
|---|---|---|
| Azul primario | `#1757D6` | Botones, cabeceras, foco de campos |
| Celeste | `#17B3E8` | Final del degradado de marca |
| Azul marino | `#0A1734` | Splash y textos principales |
| Verde dinero | `#0FA968` | Confirmaciones, KYC aprobado, capturas listas |
| Ámbar | `#F59E0B` | Avisos y recuadro de modo demostración |
| Rojo | `#E0394B` | Errores, PIN incorrecto, OTP fallido |
| Lienzo | `#F6F8FC` | Fondo general |

Tipografía en escala de 11,5 a 32 pt con interletraje negativo en los títulos;
espaciado en múltiplos de 4 y radios de 10/14/20/28.

---

## Diferencias entre la demo web y el móvil real

| | Navegador | Android / iOS |
|---|---|---|
| Biometría | No disponible (se oculta el botón) | Huella / Face ID reales |
| Cámara KYC | Selector de archivos | Cámara trasera y frontal |
| Almacén de tokens | Cifrado del navegador | Keystore / Keychain |
| Vibración en errores | No | Háptica real |
