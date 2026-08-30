# Voz e red flags da spec

## Voz

Spec aprovada sobrevive à conversa que a gerou. Alguém vai ler frio, meses depois.
Tem que soar como alguém pensando no problema, não como template preenchido.

**Escreva assim:**

- **Decisões em parágrafo.** "A page já publicada é arquivada via API
  (`archived=true`). Notion mantém archived pages recuperáveis por 30 dias na UI;
  nada se perde. Hard delete não é alternativa real porque a API não oferece."
  Direto, sem cabeçalhos `Pergunta:` / `Escolha:` / `Tradeoff:`.
- **Problema e objetivo em prosa.** Bullet simétrico em toda seção sinaliza
  preenchimento mecânico. Quando a lista é mesmo uma lista (aceite, slices),
  bullet serve.
- **Primeira pessoa quando cabe.** "Eu aprovo antes do build começar." Soa como
  dono, não como narrador externo.
- **Tabela para Segurança, Rollback e rastreabilidade.** São matriz de fato, não
  prosa que virou bullet.

**Não escreva:**

- **Meta-comentário de processo.** Nada de "ratificadas em conversa",
  "verificada-contra-stale", "round 1 patch aplicado". Esse contexto vai pro
  commit, pro PR ou pro ticket. O doc fala do problema e da solução.
- **`Owners: <nome> (decisões), Claude (drafting)`.** Owner é quem decide; Claude
  é ferramenta de drafting, não coautor. Frontmatter: `Owner: <nome humano>`.
- **`ZONA 1 — CONTRATO` como cabeçalho.** É lente de revisão na cabeça do leitor,
  não título impresso. Quebra tooling e expõe o template.
- **Termos de processo** ("decisão consciente do dono", "premissa load-bearing").
  Decisão pendente de validação se escreve: *"fica decidida em T0, com dado em
  mãos"*.

**Regra simples:** se o trecho fosse lido em voz alta numa reunião e soasse
robótico, reescreve. O doc é do dono, não nosso.

## Red flags

- 🚩 Jargão técnico (SQL, nome de tabela, assinatura) no contrato → o contrato é
  comportamento; detalhe desce pro ticket.
- 🚩 Caminho de arquivo ou trecho de código na spec → envelhece antes do ship.
  Exceção única: snippet que codifica a decisão melhor que a prosa.
- 🚩 Contexto reescreve o PRD em vez de linkar → duplicação.
- 🚩 `D-NN` sem slice correspondente → decisão órfã.
- 🚩 Critério vago ("funcionar corretamente") → reescrever em SIM/NÃO.
- 🚩 Jornada descrita em detalhe → a spec nomeia os ramos do "Como fica"; cada
  ramo vira um teste no build. Não descrever a mesma jornada duas vezes.
- 🚩 Sem "Fora de escopo" → escopo não fechado.
- 🚩 ≥2 caminhos arquiteturais viáveis sem ADR → comparação nunca feita. O ADR
  mora em `docs/adrs/`, não como seção da spec.
- 🚩 Input externo sem **Segurança**, ou prod sem **Rollback** concreto → vetor e
  falha não enumerados.
- 🚩 `D-NN` em template simétrico `· pergunta · escolha · tradeoff` → parágrafo.
  Spec é documento, não formulário.
- 🚩 **`## Resposta ao Round N`, `## Anexo`, `status: post-reconciliation`** →
  rodada de review virando seção. O finding vira ticket; a spec, no máximo, ganha
  `## Revisão N` com a decisão e o ticket que ela cria.
- 🚩 **Arquivo irmão `<spec>.round-N.md` ou `.gate-round-N.md`** → o mesmo material
  multiplicado. Um caso real chegou a cinco cópias de ~700 linhas.
- 🚩 **Seção de design maior que o resto somado** → o que atravessa slices vira
  ADR; o que é de um slice vai pro ticket dono.
- 🚩 Spec escrita durante ou depois da implementação → é ata, não contrato.

## Rationalizations (rejeitar)

| Desculpa | Por que não |
|---|---|
| "É grande mas escrevo a spec depois" | Spec depois do código é ata |
| "Já discutimos, não precisa escrever" | Conversa se perde; a spec é a memória |
| "Vou ajustar a spec depois" | Atualiza quando a decisão muda, não quando o código muda |
| "O DDL é importante, tem que estar aqui" | Importante e no lugar errado. Vai pro ticket dono |
| "É só mais uma seção de findings" | Foi assim que uma spec chegou a 1733 linhas |
