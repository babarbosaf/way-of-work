# Caveman — comunicação terse

**Fonte:** https://github.com/juliusbrussee/caveman
**Capturado:** 2026-07-07 · **Status:** doutrina de escrita adotada; plugin opcional instalado à parte.

## O que é

Skill/plugin pra 30+ agentes (Claude Code incluso) que comprime output ~65% mantendo precisão técnica. Filosofia: separa **o que o agente sabe** de **quão verboso fala**. "Make mouth smaller, not brain smaller."

## Regras de estilo (o que adotamos direto nos arquivos user-level)

- Fragmento > frase completa. Cortar preâmbulo explicativo, hedging, filler.
- Código, comandos e mensagens de erro: **byte-a-byte exatos**, nunca comprimir.
- Manter o idioma original (PT-BR aqui) e a correção ortográfica — nada de trocar acento por ASCII.

Exemplo: "The reason your component re-renders is likely..." → "New object ref cada render → re-render. Wrap em `useMemo`."

## Níveis (do plugin)

`lite` (moderado) · `full` (default) · `ultra` (agressivo) · `wenyan` (chinês clássico, máx compressão).

## Instalação do plugin (rodar no terminal — não auto-aplico)

```
claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman
```

Invocação: `/caveman [nível]`; "normal mode" desliga. No Claude Code liga automático a partir da 1ª msg. Statusline mostra `[CAVEMAN] ⛏ tokens saved`; `/caveman-stats` acumula.

## Nota de aplicação aqui

Adotamos o **estilo** direto no CLAUDE.md e docs (sem depender do plugin). O plugin afeta o *output* em runtime — dado o requisito de bom português, `lite`/`full` são mais seguros que `ultra`/`wenyan`, que degradam o PT-BR.
