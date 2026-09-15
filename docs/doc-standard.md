# Padrão de documentos

Vale pra `AGENTS.md`/`CLAUDE.md`, `README.md`, PRD, ROUTES, DESIGN, CONVENTIONS.
Carregam toda sessão ou são a primeira coisa que alguém lê. Instrução viva, não changelog.

## A fronteira

**README descreve pra quem chega de fora. AGENTS.md manda em quem já está dentro.**

Teste por linha:
- *Isto muda o que o agente faz?* → AGENTS.md
- *Isto ajuda alguém a decidir se adota, ou a instalar e rodar?* → README

Marca gramatical, que é como se fiscaliza sem discutir caso a caso: README em terceira
pessoa ("o serviço expõe X"); AGENTS.md no imperativo ("rode X antes de commitar"). Bloco
imperativo dentro do README é sinal de duplicação.

## Teste de admissão do AGENTS.md

Toda linha precisa ser **failure-backed**: já vi o agente errar sem ela. Se não vi, não
entra. Se hook, lint ou CI já força, não entra: cita-se o comando de enforcement.

O estudo AGENTbench (ETH, fev/2026, 138 tarefas, 4 modelos) mediu arquivo de contexto
escrito por humano melhorando sucesso em 4% e custando 19% a mais; gerado por LLM, piora
de 3% custando 20% a mais. Só instrução de tooling não-óbvio teve efeito grande. Linha
marginal é líquido negativo, então o default é cortar.

## Cortar

| Categoria | Exemplo |
|---|---|
| Conselho genérico de engenharia | "escreva código limpo", "trate erros", "vá na causa raiz" |
| Coaching procedural | "pense passo a passo", "seja meticuloso" |
| Inventário de diretório | árvore de pastas que `ls` mostra |
| Stack e dependência | o que `package.json` ou `pyproject.toml` já diz |
| Comando padrão da ferramenta | `pytest` sem flag especial |
| Regra já enforçada por hook, lint ou CI | cita o comando de enforcement no lugar |
| Duplicata do README | overview de arquitetura, tour do repo, instalação |
| Assinatura de API e schema copiados do código | |
| Histórico | vai pra ADR, spec, `CHANGELOG.md`, FEEDBACK ou memória |
| Status volátil | vai pro `TODOS.md` ou pro tracker |
| Justificativa que não muda decisão | mantém a regra, corta a racionalização |
| Workaround já corrigido | senão o agente contorna problema que não existe mais |
| Ramificação por modelo | "se Opus faça X, se GPT faça Y" apodrece antes da arquitetura |

## Manter

Gotcha e failure mode; escolha local que **diverge** do default da linguagem ou
ferramenta; comando não-adivinhável (script próprio, flag obrigatória, setup de
ambiente); gate com consequência real; proibição crítica; etiqueta de repo (branch,
commit, PR); glossário de domínio; ponteiro pra doc que carrega o detalhe.

Na dúvida, mantém.

## Estrutura

1. **Cabeçalho:** 2 linhas: o que é, onde a doutrina longa mora.
2. **Invariantes:** sempre verdadeiro, sem gatilho. Fica no topo porque modelo atende
   pior ao meio do contexto longo.
3. **Roteamento:** tabela `gatilho → ação`. Um item por linha. Parágrafo corrido com
   várias regras separadas por ponto-e-vírgula é o pior formato: o modelo perde o item
   do meio.
4. **Ponteiros:** docs e skills.

Teto de 130 linhas, enforçado por `hooks/claude_md_size_guard.py`. Densidade importa mais
que a contagem.

## O ponteiro do CLAUDE.md

`AGENTS.md` é a fonte. Em projeto, o `CLAUDE.md` é um arquivo de uma linha só,
`@AGENTS.md`, nunca symlink nem cópia. Symlink não atravessa Windows, zip e
export, e no diff de PR aparece como blob de caminho. Cópia diverge no primeiro
commit que esquecer o par.

Custo: `@` é mecanismo do Claude Code. Harness que leia o `CLAUDE.md` literal vê
uma linha e nenhuma doutrina; quem precisa de portabilidade total edita o
`AGENTS.md`, que é o arquivo do padrão.

## Herança

Child AGENTS.md só escreve override próprio ou fato que só existe naquele projeto.
Repetir doutrina do `~/.claude/AGENTS.md` carrega duas vezes em toda sessão.

## Nomenclatura

Raiz em CAIXA-ALTA é doc único e estável. Instância (`spec-<slug>`, `adr-NNNN`) em
lowercase. Transiente vai pra `_tmp/`, gitignored.

Escopo se declara pelo que o projeto **É**, sem tabela de exclusão: a negativa que
importa vive na decisão que a produziu.
