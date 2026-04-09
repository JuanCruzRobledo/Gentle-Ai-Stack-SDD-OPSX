# Gentle-AI Stack con OPSX

**Fork mejorado del [Gentle-AI Stack](https://github.com/Gentleman-Programming/gentle-ai) original, actualizado para usar el workflow OPSX de OpenSpec.**

> Este repositorio reemplaza el flujo Legacy (SDD con fases rigidas) por el nuevo flujo **OPSX** (acciones fluidas e iterativas). Si ya tenes el stack original instalado, esta guia te lleva paso a paso a la version mejorada.

---

## Que cambio respecto al original?

| Aspecto | Stack Original (Legacy) | Este Fork (OPSX) |
|---------|------------------------|-------------------|
| **Flujo de trabajo** | Fases rigidas y bloqueantes (`planning -> implementing -> archiving`) | Fluido e iterativo: explora, propone, aplica, archiva en cualquier orden |
| **Comandos** | `/sdd-apply`, `/sdd-archive`, `/sdd-explore`, etc. | `/opsx:explore`, `/opsx:propose`, `/opsx:apply`, `/opsx:archive` |
| **Orchestrator** | Coordina sub-agentes SDD con engram y fases | Coordina via skills + CLI `openspec` como fuente de verdad |
| **Skills** | Logica interna con persistencia engram | Delegacion directa al CLI `openspec` |
| **Vuelta atras** | No permitida entre fases | Podes actualizar cualquier artefacto en cualquier momento |

### Archivos modificados

Los cambios principales estan en:

```
internal/assets/
  generic/sdd-orchestrator.md        -> Reescrito con instrucciones OPSX (OpenCode)
  claude/sdd-orchestrator.md         -> Reescrito con instrucciones OPSX (Claude Code)
  gemini/sdd-orchestrator.md         -> Reescrito con instrucciones OPSX (Gemini CLI)
  codex/sdd-orchestrator.md          -> Reescrito con instrucciones OPSX (Codex)
  cursor/sdd-orchestrator.md         -> Reescrito con instrucciones OPSX (Cursor)
  windsurf/sdd-orchestrator.md       -> Reescrito con instrucciones OPSX (Windsurf)
  antigravity/sdd-orchestrator.md    -> Reescrito con instrucciones OPSX (Antigravity)
  opencode/commands/                 -> Comandos renombrados: sdd-* a opsx-*
  opencode/sdd-overlay-*.json        -> Simplificado (solo orchestrator, sin sub-agentes)
  skills/sdd-*/SKILL.md              -> Reescritos para usar openspec CLI
```

> **Todos los agentes soportados** (Claude Code, OpenCode, Cursor, Gemini CLI, Codex, Windsurf, Antigravity) reciben las instrucciones OPSX. Cada orchestrator mantiene las particularidades de su herramienta (sub-agentes, inline execution, Plan Mode, etc.) pero con el core OPSX.

---

## Pre-requisitos

- **Go 1.24+** instalado ([descargar](https://go.dev/dl/))
- **El stack original ya instalado** (si nunca lo instalaste, hace eso primero desde el [repo original](https://github.com/Gentleman-Programming/gentle-ai))

Verifica Go:

```bash
go version
```

---

## Instalacion

### 1. Clonar o descargar este repositorio

```bash
git clone https://github.com/JuanCruzRobledo/Gentle-Ai-Stack-SDD-OPSX.git
cd Gentle-Ai-Stack-SDD-OPSX
```

### 2. Limpiar la configuracion anterior (IMPORTANTE)

Si ya tenias el stack original instalado, **es necesario limpiar la configuracion anterior** antes de sincronizar. El sync hace un merge (no un reemplazo), asi que los comandos y agentes del flujo Legacy persisten y generan conflictos con OPSX.

**Linux / macOS (OpenCode):**

```bash
rm -rf ~/.config/opencode/commands/sdd-*.md
rm -f ~/.config/opencode/opencode.json
```

**Linux / macOS (otras herramientas):**

```bash
# Claude Code
rm -rf ~/.claude/commands/sdd-*.md

# Cursor
rm -rf ~/.cursor/agents/sdd-*.md

# Gemini CLI
rm -rf ~/.gemini/commands/sdd-*.md
```

**Windows (PowerShell):**

```powershell
# OpenCode
Remove-Item "$HOME\.config\opencode\commands\sdd-*.md" -ErrorAction SilentlyContinue
Remove-Item "$HOME\.config\opencode\opencode.json" -ErrorAction SilentlyContinue

# Claude Code
Remove-Item "$HOME\.claude\commands\sdd-*.md" -ErrorAction SilentlyContinue

# Cursor
Remove-Item "$HOME\.cursor\agents\sdd-*.md" -ErrorAction SilentlyContinue
```

> **Por que es necesario?** El sync del stack original instala comandos `sdd-*.md` y agentes con instrucciones Legacy. El sync de este fork agrega los nuevos `opsx-*` pero NO borra los viejos. La herramienta ve ambos sets de comandos y el orchestrator puede caer en el comportamiento Legacy.

### 3. Compilar

**Windows:**

```bash
go build -o gentle-ai.exe ./cmd/gentle-ai/
```

**Linux / macOS:**

```bash
go build -o gentle-ai ./cmd/gentle-ai/
```

### 4. Sincronizar

**Windows:**

```bash
./gentle-ai.exe sync
```

**Linux / macOS:**

```bash
./gentle-ai sync
```

Si la terminal muestra el mensaje de exito, tu entorno esta actualizado con OPSX.

---

## Verificacion

Abri OpenCode en cualquier proyecto y preguntale al agente:

```
Quien sos y que podes hacer? Explicame tu flujo de trabajo completo.
```

Deberia responder mencionando:
- Que es el **OPSX Orchestrator**
- Que trabaja con el CLI `openspec`
- Que el flujo es: **explore -> propose -> apply -> archive**
- Que los comandos son `/opsx:explore`, `/opsx:propose`, `/opsx:apply`, `/opsx:archive`

Si responde con el flujo viejo (menciona `/sdd-*`, fases rigidas, phase gates), revisa la seccion de troubleshooting.

---

## Flujo OPSX — Como funciona

```
/opsx:explore   (opcional: pensar antes de comprometerse)
       |
       v
/opsx:propose   (crear cambio + propuesta + diseno + tareas)
       |
       v
/opsx:apply     (implementar las tareas del cambio)
       |
       v
/opsx:archive   (sincronizar specs + cerrar el cambio)
```

**No hay fases rigidas.** Podes volver atras, saltear pasos, o repetir cualquier accion en cualquier momento.

### Comandos

| Comando | Que hace |
|---------|----------|
| `/opsx:explore [tema]` | Modo exploracion: investigar ideas, aclarar requisitos, pensar. No genera archivos. |
| `/opsx:propose [nombre]` | Crea un cambio con todos los artefactos: `proposal.md`, `design.md`, `tasks.md` |
| `/opsx:apply [nombre]` | Implementa las tareas del cambio, marcandolas como completadas |
| `/opsx:archive [nombre]` | Sincroniza delta specs con los specs principales y archiva el cambio |

### Estructura de un cambio

```
openspec/changes/<nombre-del-cambio>/
  .openspec.yaml    <- metadata del cambio
  proposal.md       <- que y por que
  design.md         <- como (enfoque tecnico)
  tasks.md          <- checklist de implementacion
  specs/            <- delta specs (requisitos que cambian)
```

---

## Troubleshooting

### El agente sigue respondiendo con el flujo Legacy (SDD)

**Causa:** Quedan archivos del stack original en la configuracion de OpenCode.

**Solucion:**

1. Borra la configuracion vieja (paso 2 de la instalacion)
2. Volve a compilar y sincronizar (pasos 3 y 4)

Podes verificar que no queden residuos:

```bash
# Linux/macOS
ls ~/.config/opencode/commands/

# Solo deberian estar: opsx-apply.md, opsx-archive.md, opsx-explore.md, opsx-propose.md
```

```powershell
# Windows
dir $HOME\.config\opencode\commands\

# Solo deberian estar: opsx-apply.md, opsx-archive.md, opsx-explore.md, opsx-propose.md
```

Si ves archivos `sdd-*.md`, borra la carpeta `commands/` completa y volve a sincronizar:

```bash
# Linux/macOS
rm -rf ~/.config/opencode/commands/
./gentle-ai sync

# Windows
Remove-Item "$HOME\.config\opencode\commands" -Recurse -Force
./gentle-ai.exe sync
```

### El build falla con errores de Go

- Verifica que tenes Go 1.24+ con `go version`
- Asegurate de estar en la raiz del repositorio (donde esta `go.mod`)

### OpenCode no reconoce los comandos `/opsx:*`

- Verifica que el sync termino sin errores
- Reinicia OpenCode despues del sync
- Revisa que `~/.config/opencode/commands/` tenga los archivos `opsx-*.md`

---

## Diferencia conceptual: Legacy vs OPSX

El stack original usaba **Spec-Driven Development (SDD)** con fases bloqueantes:

```
LEGACY: Planning -> Implementing -> Archiving (lineal, sin vuelta atras)
```

OPSX reemplaza esto con **acciones fluidas**:

```
OPSX: Cualquier accion, en cualquier momento, sobre cualquier cambio
```

La fuente de verdad pasa de ser el estado interno del agente (engram) a ser el **CLI `openspec`**. El orchestrator siempre consulta `openspec status` antes de actuar — nunca asume el estado de los artefactos.

Para mas contexto sobre OPSX y OpenSpec, consulta la [documentacion oficial de OpenSpec](https://openspec.dev/).

---

## Creditos

- **Stack original:** [Gentleman Programming — gentle-ai](https://github.com/Gentleman-Programming/gentle-ai)
- **OpenSpec / OPSX:** [Fission AI — OpenSpec](https://github.com/Fission-AI/OpenSpec)
- **Fork OPSX:** [JuanCruzRobledo](https://github.com/JuanCruzRobledo/Gentle-Ai-Stack-SDD-OPSX)

---

<div align="center">
<a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
</div>
