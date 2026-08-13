# Guía de publicación — CV Ricardo Yoné León

Este documento es el procedimiento completo para publicar el sitio. Está escrito
para que cualquier persona o agente de IA pueda ejecutarlo sin conocer el
historial del proyecto.

**Si sólo querés publicar, saltá a [Publicar](#publicar).**

---

## Qué es este proyecto

Un CV de una sola página en HTML y CSS plano. **No hay build system, no hay npm,
no hay framework.** El repositorio es:

```
index.html                 Fuente de verdad del contenido
styles.css                 Fuente de verdad de los estilos
Foto perfil.jpg            Retrato usado en la cabecera
Ricardo-Yone-Leon-CV.pdf   PDF generado (NO se edita a mano)
netlify.toml               Config del deploy: publica la raíz del repo
scripts/                   Automatización
docs/                      Este documento
```

Se despliega en **Netlify** desde la rama `main` de
`https://github.com/RicardoYone/CV---RICARDO-YONE-LEON-ESTELA`.
El deploy es automático: **push a `main` = publicación**.

---

## La regla de oro

**El sitio se publica desde la raíz del repositorio. No existe carpeta de build,
y no debe volver a existir.**

Hubo un `dist/` que era una copia a mano de la raíz. Al no haber ningún build
que la mantuviera sincronizada, las dos copias se separaron: `dist/` terminó con
fechas de empleo distintas a las de la raíz y con un `<img>` apuntando a
`../Foto perfil.jpg`, ruta que queda fuera del directorio publicado y daba 404 en
producción. Se eliminó.

`netlify.toml` fija `publish = "."` y **tiene prioridad sobre lo configurado en
el panel de Netlify**, así que el destino del deploy vive en el repositorio y no
en un dashboard que nadie puede leer desde el código.

El único artefacto generado que queda es `Ricardo-Yone-Leon-CV.pdf`. No se edita
a mano: se regenera con el script.

---

## Publicar

Un solo comando hace toda la cadena:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy.ps1 -Message "fix(cv): actualiza el correo de contacto"
```

El mensaje sigue [Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `chore:`, `style:`, `docs:`).

### Qué hace, en orden

| Paso | Acción | Por qué importa |
|---|---|---|
| 1 | Verifica que existan los archivos fuente en la raíz | Detecta un checkout incompleto antes de tocar nada |
| 2 | Valida los invariantes de diseño | Ver la sección siguiente |
| 3 | Regenera el PDF con Chrome/Edge headless | El PDF es estático: sin este paso queda con el contenido viejo |
| 4 | Comprueba que cada asset referenciado exista | Una ruta rota da 404 recién en producción |
| 5 | `git add -A` y commit | |
| 6 | `git push origin main` | Dispara el deploy de Netlify |

**Si cualquier verificación falla, el script aborta antes de commitear.** No
publica a medias.

### Banderas

- `-DryRun` — construye y verifica, no commitea nada. Úsala para revisar antes.
- `-SkipPush` — commitea localmente pero no publica.

---

## Invariantes que nunca se rompen

Cada una de estas reglas existe porque su violación produce un bug real y
silencioso. El script las valida automáticamente, pero conviene entenderlas.

### 1. El modo claro es el default incondicional

**Prohibido usar `@media (prefers-color-scheme: dark)` en `styles.css`.**

El modo oscuro existe únicamente bajo `:root[data-theme="dark"]`, y ese atributo
sólo se activa si la persona pulsa el botón de tema. Decisión explícita del
dueño del CV: si un reclutador tiene su sistema operativo en modo oscuro, no debe
recibir el CV en negro sin haberlo pedido. La preferencia del sistema operativo
no decide cómo se presenta este documento.

El script de arranque en el `<head>` sólo restaura `dark` si
`localStorage['cv-theme'] === 'dark'`. Cualquier otro caso es claro.

### 2. El PDF nunca se genera desde `file://`

Hay que servirlo por HTTP. Chrome headless, al imprimir un `file://`, ignora la
hoja de estilos externa y las webfonts de Google: el PDF sale sin diseño.
`build-pdf.ps1` levanta `serve.ps1` justamente por esto.

### 3. `break-inside: avoid` va en las entradas, nunca en las secciones

Si se aplica a `.section`, la sección de experiencia completa no entra en el
espacio restante de la página 1 y salta entera a la página 2, dejando media
página en blanco. Debe aplicarse sólo a `.entry` y `.record`, más
`break-after: avoid` en `.section__title` para que un título no quede huérfano
al pie de página.

### 4. La impresión siempre sale en claro

El bloque `@media print` redeclara la paleta clara completa sobre `:root`,
`:root[data-theme="dark"]` y `:root[data-theme="light"]`. Un CV impreso en fondo
negro se ve mal y desperdicia tóner. El PDF sale claro sin importar el tema
activo en la web.

### 5. El botón de descarga es un enlace, no `window.print()`

`window.print()` **siempre** abre el diálogo de impresión del navegador. No
existe API web para saltarlo; es una restricción de seguridad deliberada. Por eso
el PDF se pre-genera y el botón es un `<a download>` que baja el archivo
directamente.

### 6. Dos páginas A4 es lo correcto

No es un bug. Con cuatro experiencias, educación, certificación y quince
tecnologías, dos páginas es lo esperado para un CV. Lo que sí sería un defecto
es que una experiencia quedara partida entre páginas.

### 7. Los commits no llevan atribución de IA

Nada de `Co-Authored-By` ni firmas de asistentes. Sólo Conventional Commits.

### 8. `.atl/` y `.playwright-mcp/` no se commitean

Son artefactos de herramientas locales, no del sitio. Ya están en `.gitignore`.

### 9. No se vuelve a crear una carpeta de build

Ni `dist/`, ni `build/`, ni `public/`. El sitio es HTML y CSS plano y se publica
desde la raíz. Una carpeta copiada a mano no tiene nada que la mantenga
sincronizada, y termina publicando contenido viejo. `deploy.ps1` aborta si
detecta que `dist/` reapareció.

---

## Verificación manual

El script cubre lo mecánico, pero lo visual hay que mirarlo. Antes de publicar un
cambio de diseño:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/serve.ps1
```

Abrí `http://localhost:8123/` y comprobá:

- [ ] Carga en **blanco**, aunque el sistema operativo esté en modo oscuro.
- [ ] El botón de tema alterna y la elección persiste al recargar.
- [ ] "Descargar PDF" baja el archivo sin abrir ningún diálogo.
- [ ] En móvil (≤680 px) la foto va arriba y las fechas sobre cada cargo.
- [ ] El PDF abre en dos páginas, en claro, sin experiencias cortadas.

---

## Fallas conocidas

### El push falla con código 128 y sin mensaje de error

**Causa:** el `credential.helper` está configurado como `manager` (Git Credential
Manager), que necesita abrir su ventana gráfica de inicio de sesión. Desde un
shell no interactivo —como el de un agente de IA— no puede, y falla en silencio.

**No es un problema de red.** `git ls-remote origin` funciona porque el
repositorio es público y esa operación no requiere credenciales.

**Solución:** el commit ya quedó guardado en el historial local. La persona lo
completa desde su propia terminal:

```bash
git push origin main
```

### El PDF sale sin diseño o pesa muy poco

Chrome no alcanzó a cargar la hoja de estilos o las webfonts. Subí el valor de
`--virtual-time-budget` en `scripts/build-pdf.ps1` y verificá que haya conexión
a `fonts.googleapis.com`. El script aborta si el PDF pesa menos de 50 KB.

### No hay Node ni Python en la máquina

Correcto, y es deliberado: toda la automatización está en PowerShell puro, que
viene con Windows. No hace falta instalar nada.

---

## Instrucción para un agente de IA

Si le vas a pasar este proyecto a otra IA, copiale esto:

> Este es un CV en HTML/CSS plano que se publica en Netlify desde `main`.
> Leé `docs/DEPLOY.md` completo antes de tocar nada.
>
> Reglas no negociables:
> 1. Editá sólo `index.html` y `styles.css` de la raíz. El sitio se publica desde
>    la raíz: no crees `dist/`, `build/` ni `public/`. El PDF es generado, nunca
>    lo edites a mano.
> 2. Después de cualquier cambio de contenido, publicá con
>    `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy.ps1 -Message "<conventional commit>"`.
>    No hagas los pasos por separado ni te saltees la regeneración del PDF.
> 3. No agregues `@media (prefers-color-scheme: dark)`. El modo claro es el
>    default incondicional; el oscuro es opt-in por botón.
> 4. No uses `window.print()` para la descarga del PDF.
> 5. Los commits van en Conventional Commits, sin atribución de IA.
> 6. Si el `git push` falla con código 128, no reintentes: es el Git Credential
>    Manager, que no puede pedir credenciales en un shell no interactivo. Avisale
>    a la persona que lo complete desde su terminal.
