# Contribuir com o way-of-work

Este repo é a configuração de trabalho de um dev, versionada pra outros adotarem. Melhoria nasce no uso real: você trabalha num projeto, sente uma dor, ajusta a skill/doc/hook, e propõe de volta.

## Fluxo upstream

Você está usando o way-of-work num projeto (via submodule ou clonado em `~/.claude`) e melhorou algo. Pra devolver:

1. **Fork + branch.** `feature/<slug-curto>` a partir de `main`.
2. **Mude uma coisa.** Uma skill, um runbook, um hook. PR pequeno e focado revisa melhor.
3. **Sem topologia privada.** Nenhum nome de repo de negócio, path absoluto de máquina, scope pago, credencial. Use placeholders (`<seu-projeto>`, `$HOME`, `<your-paid-scope>`). Antes de abrir o PR, faça um grep pelos seus próprios nomes de projeto e paths de máquina; o review confere.
4. **Instrução viva, não changelog.** Docs de start-up (`CLAUDE.md`, `README.md`, `RUNBOOK.md`) carregam toda sessão. Sem histórico, sem status volátil. Teste cada linha: "cortar isso faria o agente errar?" Não → cortar.
5. **Evoluir > criar.** Antes de adicionar skill/doc/flag paralela, cheque se dá pra estender uma existente. Cobre ~80%? Estenda.
6. **Abra o PR** com: que dor resolve, qual arquivo mudou, como testou.

## O que é bem-vindo

- Skill nova que preenche uma fase do ciclo que falta.
- Runbook operacional pra um procedimento repetível.
- Hook de enforcement que ensina na mensagem de bloqueio.
- Correção de doc que estava desatualizada ou vazava detalhe privado.

## O que provavelmente vai ser recusado

- Cópia paralela de algo que já existe (`_v2`).
- Doc que vira changelog ou tracker de status.
- Qualquer coisa carregando topologia de negócio ou segredo.
- Skill sem consumidor real ("pode ser útil um dia").

## Estilo

Terse, bom português, fragmento > frase. Código e commits em formato normal. Sem AI slop (verborragia, dash-conector decorativo).
