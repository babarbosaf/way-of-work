# Fatiamento, paralelismo e red flags do plano

## Conteúdo

- Tracer bullet, não camada
- Ownership de arquivo
- Quando não paralelizar
- Refactor mecânico de blast radius alto
- Ordem e tamanho
- Red flags do plano
- Red flags do build

## Tracer bullet, não camada

Slice é um caminho **estreito e completo** por todas as camadas que a mudança
toca: schema, serviço, interface, teste. Vertical.

Fatiar por camada é o erro caro. Um time rodou 26 tickets fatiados por camada
(corpus, producer, aggregator, selector) e gastou cerca de vinte execuções de
agente por ticket fechado, três quartos delas retrabalho. O post-mortem deles
atribuiu toda classe de falha ao fatiamento horizontal, não às implementações.

O sintoma: nada funciona até a última camada entrar, e o aceite de um ticket
precisa alcançar trabalho que outro ticket possui.

**Teste do demo:** *"o que eu demonstro quando isto fecha?"* Sem resposta, é
fatia horizontal. Refatiar.

**Teto:** o ticket cabe numa janela de contexto fresca. Um agente que nunca viu a
spec tem que conseguir executá-lo só com o ticket.

**Piso:** se a mudança inteira cabe numa janela, não precisa de ticket nenhum,
vai direto pro código. Fatiar o que não precisa é overhead puro.

## Ownership de arquivo

`files:` lista o que o ticket **possui**, não o que ele talvez encoste. Nenhum
outro ticket da leva toca esses arquivos.

Três regras, e as três juntas é que funcionam:

1. **Preferir arquivo novo** a editar compartilhado.
2. **Particionar quando precisa editar existente**, por seção ou classe, sem
   sobreposição.
3. **Cross-cutting vai pro ticket de integração**, feito por último, sequencial.

Aplicadas juntas, cinco PRs paralelos mergearam sem conflito. Ressalva do mesmo
relato: zero conflito de git não é zero trabalho de integração. Lá foram trinta
minutos de git e cinco horas e meia de incompatibilidade de API entre os PRs.

Se dois tickets querem o mesmo arquivo, o fatiamento está errado. Refatiar,
sequenciar por `blocked_by`, ou juntar num ticket só. Nunca deixar passar com
"eles mal se tocam".

## Quando não paralelizar

Zona onde `[P]` não vale mesmo com `files:` disjuntos:

- schema de banco compartilhado
- contrato de API que outro ticket consome
- config central, wiring, tabela de rotas
- biblioteca que os dois importam e um dos dois vai mudar

Nesses casos o conflito não é textual, é semântico: o git mergeia limpo e o
sistema quebra. Sequenciar com `blocked_by`.

## Refactor mecânico de blast radius alto

Rename de coluna, troca de assinatura consumida em toda parte: **não vira tracer
bullet**. Vira expand → migrate → contract:

```
expand    forma nova passa a existir, a antiga continua      1 ticket
migrate   consumidores migram em lotes por blast radius      N tickets
contract  forma antiga morre                                 1 ticket
```

CI verde entre lotes, porque a forma antiga ainda existe. Cada fase é ticket
próprio, e `contract` é `blocked_by` de todos os lotes.

Prefactor antes: "make the change easy, then make the easy change".

## Ordem e tamanho

- `blocked_by` ordena; `priority` prioriza. São campos diferentes e coexistem.
- Bloqueador primeiro, sempre.
- Tamanho `XS`, `S` ou `M`. `L` significa que ainda não foi fatiado.
- Ticket bloqueado em coisa externa (auth, sign-off, credencial, dado que não
  chegou) leva `bloqueado: <X>` e sai da frente do que dá pra fazer agora.

## Red flags do plano

- 🚩 Ticket `L` ou `XL` → quebrar.
- 🚩 Ticket sem `files:` → não dá pra paralelizar com segurança.
- 🚩 Dois tickets `[P]` com `files:` que se cruzam → conflito garantido.
- 🚩 `blocked_by` com pseudo-ID (`#S3`, `T04`) → não resolve, não ordena, mente
  pro loop que consome o tracker.
- 🚩 Ticket sem aceite testável → não dá pra saber o que é "done".
- 🚩 `verify:` vazio ou apontando pra `verify_cmd` que é `<TODO: ...>` → o repo
  não tem gate; resolver antes de abrir ticket.
- 🚩 Cadeia longa em série sem nenhum `[P]` → procurar paralelismo real.
- 🚩 Cross-cutting marcado `[P]` → vai pro ticket de integração.
- 🚩 Ticket sem `delega:` (nem type, nem "não") → planning gap; o build não
  reavalia.
- 🚩 `D-NN` da spec sem ticket → decisão sumiu no plano.
- 🚩 Pipeline, handler ou endpoint sem o checklist de `to-spec` respondido →
  planning gap conhecido (idempotência, TTL, falha encadeada).

## Red flags do build

- 🚩 Mais de 100 linhas sem rodar teste → parar, escrever teste.
- 🚩 Editando arquivo fora dos `files:` do ticket → parar e perguntar. Não é zelo,
  é o ownership de outro ticket.
- 🚩 "Vou arrumar isso aqui também" → não; abre ticket.
- 🚩 Commit intermediário com sistema quebrado → cada incremento verde.
- 🚩 Merge concorrente de dois PRs da mesma leva → serializar, verify entre cada.
- 🚩 PR mergeada com branch viva → órfã. `--delete-branch` é default.
