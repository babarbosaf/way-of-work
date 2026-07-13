# Evoluir > criar (anti-duplicação)

**Default:** estender artefato existente antes de criar paralelo.

## Antes de minimizar, entender

A escada (estender > criar, reuse > novo) roda **depois** de entender o problema, não no lugar de entender: ler a task, traçar o fluxo, então escolher a opção menor. Preguiça é sobre a solução, nunca sobre a leitura.

O menor diff **no lugar errado** é o segundo bug, não economia. Diff curto que você não entende é preguiça disfarçada de eficiência.

**Simplificação deliberada ganha marca no código.** Ao parar de propósito num nível simples (sync-only, sem cache, hardcoded), comentar o teto + upgrade path: `# simplif: sync só; async se volume > 1k/min`. Distinto de `[ASSUMPTION ARBITRÁRIA]` (premissa incerta) — aqui a escolha é consciente, marca-se onde a simplicidade quebra.

Cada novo artefato (staging dbt, view, property no destino, módulo Python, flag CLI, helper, abstração) duplica superfície de manutenção:
- Fix futuro vira N lugares
- Lógica diverge silenciosamente entre os artefatos paralelos
- FUP de "consolidar X e Y" se acumula como dívida técnica
- Onboarding mental: novo dev precisa entender "qual usar quando"

## Checklist antes de criar

1. **Já existe artefato cobrindo ~80% do escopo?** → estender (adicionar coluna, ampliar UNION, mudar filtro pra opt-in). Consumidores não-tocados não veem diferença.
2. **Consumidor único do artefato existente?** → evoluir in-place no mesmo PR; sem janela de transição, sem FUP de cleanup.
3. **Nome existente captura a semântica ampliada?** → manter nome, ampliar conteúdo. Renomear só quando a categoria muda fundamentalmente.

## Criar novo é correto quando

- **Boundary semântico distinto.** Categoria diferente, não "mais do mesmo". Ex: "conjunto filtrado" e "conjunto completo" são DUAS categorias se o filtro é contrato firme de consumidor; é UMA categoria com flag se o filtro é só recorte.
- **Consumidores existentes com contratos divergentes reais.** Evoluir quebraria back-compat de verdade, não só estética. Test diff != contract diff.
- **Custo do refactor > overhead da duplicação.** Medir em N artefatos × frequência de mudança esperada × probabilidade de divergência. Se artefato muda 1x/ano e duplicação é trivial, evoluir não compensa.

## Smell test

Se a **única** razão pra criar é "fica mais limpo conceitualmente" sem nenhum consumidor pedindo separação → evoluir. Estética não é engenharia.

Outro smell: "vou criar o `_v2` e migrar depois". Migração nunca acontece. Evolui in-place se o consumidor é único; se múltiplos, alinha o contrato e evolui in-place mesmo assim (PR maior, mas zero dívida).

## Aplicação cross-domain

Vale pra qualquer artefato — antes de criar o paralelo, evoluir o existente:
- **dbt** — ampliar model em vez de `_extended`/`_v2`
- **Pydantic** — campo opcional no model existente em vez de `ModelV2`
- **Notion** — espelhar nome do source em vez de property nova
- **Módulos Python** — arquivo direto no pacote existente em vez de subpacote novo
- **Flags CLI** — mudar default + tests em vez de flag opt-in paralela
- **Abstrações** — regra de 3 (só criar interface com 3 impls concretas)

## Exceção registrada

Quando o boundary semântico é genuinamente novo (ex: staging `_completo` vs `_filtrado` — categorias diferentes de conjunto), criar é correto. Marcar a decisão no Mini-ADR da spec explicando POR QUÊ era boundary, não evolução.
