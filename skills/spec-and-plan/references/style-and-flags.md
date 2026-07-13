# Voz, red flags e rationalizations — spec-and-plan

## Voz

Spec aprovada é um documento que vai sobreviver à conversa que a gerou e que outras pessoas vão ler frio meses depois. Tem que soar como alguém pensando no problema, não como template preenchido.

**Escreva assim:**

- **Decisões em parágrafo.** "A page já publicada é arquivada via API (`archived=true`). Notion mantém archived pages recuperáveis por 30 dias na UI; nada se perde. Hard delete não é uma alternativa real porque a API não oferece." Direto, sem cabeçalhos `Pergunta:`, `Escolha:`, `Tradeoff:`.
- **Resumo, Problema, Objetivo em prosa.** Bullets simétricos em todas as seções sinalizam preenchimento mecânico. Quando uma lista é mesmo uma lista (ACs, tasks, properties), bullets ok.
- **Primeira pessoa quando faz sentido.** "Eu aprovo antes do build começar." Soa como dono, não como narrador externo.
- **Mini-ADR em prosa.** "Considerei fazer X em vez de Y; Y ganhou porque mantém a arquitetura consistente, é testável sem rodar Python, e os próximos PRs reusam o skeleton." Sem `Opções: A, B / Escolhida: B / Por quê: ...` em estrutura rígida.
- **Tabelas pra Security/Rollback/Rastreabilidade.** Continuam funcionando — são matriz de fato, não prosa que virou bullet.

**Não escreva:**

- **Meta-commentary de processo no doc final.** Nada de "ratificadas em conversa", "verificada-contra-stale", "round 1 patch aplicado", "Owners: Claude (drafting)". Esse contexto vai pro commit, PR description, ou ficha de processo paralela. O doc fala do problema e da solução.
- **Evaluator Status Block como narrativa de rounds adversariais.** O Block reporta o estado: `Gate 1: ok | critical_aberto | teto_atingido` + reviewer. Histórico detalhado de findings/patches vive em outro lugar (PR comments, log da skill, transcript).
- **`Owners: <nome> (decisões), Claude (drafting)`.** Owner é quem decide; Claude não é coautor do doc — é ferramenta de drafting. Frontmatter padrão: `Owner: <nome humano>`.
- **`ZONA 1 — CONTRATO` como `## H2`.** Vira lente de revisão na cabeça do leitor, não cabeçalho impresso.
- **"Decisão consciente do dono", "premissa load-bearing", "verificada-contra-stale"** e outros termos do processo. Quando precisar marcar uma decisão como pendente de validação live, escreve: *"Fica decidida em T0, com dado em mãos"* ou *"Aguardando confirmação do Robson"*.

**Regra simples:** se o trecho fosse lido em voz alta numa reunião e soasse robótico, reescreve. O doc é dele, não nosso.

## Red flags da spec

- 🚩 Jargão técnico (SQL, nome de tabela) na Zona 1 → desce pra Zona 2; Zona 1 é comportamento.
- 🚩 Contexto reescreve o PRD em vez de linkar → duplicação; linka.
- 🚩 `D-NN` sem task correspondente na Zona 2 → decisão órfã.
- 🚩 Critérios vagos ("funcionar corretamente") → reescrever em SIM/NÃO comportamental.
- 🚩 User journey descrita na spec **e** no test-and-debug → spec só nomeia (ramos do Como fica); mecânica vive no test-and-debug.
- 🚩 Spec sem "Fora de escopo" → escopo não fechado.
- 🚩 Spec escrita durante/depois da implementação → invalida o processo.
- 🚩 Apresentar pra aprovação sem Evaluator Status Block no corpo → invalida o processo.
- 🚩 ≥2 caminhos arquiteturais viáveis sem Mini-ADR → comparação nunca feita.
- 🚩 *(governança)* input externo sem **Segurança/Modelo de ameaça**, ou prod sem **Rollback** concreto → vetor/falha não enumerados.
- 🚩 **Decisões `D-NN` escritas como template** `· pergunta · escolha · tradeoff` simétrico → reescrever em parágrafo curto. Spec é doc, não formulário.
- 🚩 **Meta-commentary de processo no doc final** ("ratificadas em conversa", "verificada-contra-stale", "round 1 patch", `Owners: Claude (drafting)`) → esse contexto vai pra commit/PR/log paralelo, não pro doc.
- 🚩 **Evaluator Status Block com narrativa de rounds adversariais despejada no doc** → Block é status (`ok | critical_aberto | teto_atingido` + reviewer); histórico mora fora.
- 🚩 **`## ZONA 1` / `## ZONA 2` como cabeçalho físico** → quebra tooling e expõe template; mapeia pras seções H2 canônicas (Resumo, Decisões, Critérios de Aceite, Mudanças).
- 🚩 **Resumo/Problema/Objetivo em bullets simétricos quando prosa caberia** → soa preenchido, não pensado.

## Red flags do plano

- 🚩 Task `L`/`XL` → quebrar.
- 🚩 Task sem critério de aceite testável → não dá pra verificar done.
- 🚩 Cadeia longa em série → procurar paralelismo.
- 🚩 Pipeline/handler sem o checklist acima preenchido → planning gap conhecido.
- 🚩 `D-NN` sem rastreabilidade pra task → decisão da Zona 1 sumiu no plano.
- 🚩 Task sem classificação de delegação (nem `delega:` nem decisão explícita de ficar no orquestrador) → planning gap; o build não reavalia.

## Red flags do build

- 🚩 >100 linhas sem rodar teste → parar, escrever teste.
- 🚩 Editando arquivo fora do escopo → parar e perguntar.
- 🚩 "Vou arrumar isso aqui também" → não; abre task nova.
- 🚩 Commit intermediário com sistema quebrado → cada incremento deve ser verde.
- 🚩 Propor commit sem Evaluator Status Block completo no output → invalida o processo.

## Rationalizations comuns (rejeitar)

| Desculpa | Por que não aceitar |
|---|---|
| "É pequeno demais para spec" | Se leva >30 min, merece spec leve de 10 min |
| "Já discutimos, não precisa escrever" | Conversas se perdem; a spec é a memória |
| "Vou ajustar a spec depois" | Atualize a spec quando mudar decisão, não o código |
| "Vou testar no final" | Testes no final = validação tardia, não TDD |
| "É simples, não precisa planejar" | Tasks sem plano viram retrabalho |
