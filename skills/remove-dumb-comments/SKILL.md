---
name: remove-dumb-comments
description: |
  Sinaliza comentários que só repetem o que o código já diz, e remove apenas os que o usuário aprovar. Usa `git blame` pra idade e uma tabela com veredito Remover/Manter.
  Invoque quando o usuário pedir pra remover comentários óbvios/redundantes, limpar comentários, ou digitar `/remove-dumb-comments [<número>|all]`.
  Não invoque para: comentário que carrega o porquê (decisão, workaround, referência), remoção de código morto sem relação com comentário, ou revisão geral de qualidade (isso é `code-review`/`simplify`).
---

# remove-dumb-comments

Sinaliza comentário que só descreve *o quê* o código já mostra; mantém todo comentário que
carrega o *porquê*. Quem decide o que remover é o usuário, não o agente.

## Invocação

| Comando | Comportamento |
|---|---|
| `/remove-dumb-comments` | Acha os 10 comentários de menor valor |
| `/remove-dumb-comments <número>` | Acha essa quantidade |
| `/remove-dumb-comments all` | Acha todos os comentários de baixo valor |

## Nunca remover

Mantém comentário que carrega porquê que o código sozinho não mostra:

- backport, compatibilidade, comportamento específico de versão;
- infraestrutura, deploy, arquitetura;
- workaround, gotcha, motivo não óbvio;
- documentação, spec, RFC, ADR;
- bug, issue, ticket, TODO/FIXME com contexto;
- intenção, trade-off, constraint.

Na dúvida, mantém. Só sinaliza repetição pura.

## Fluxo

1. Resolve o limite da invocação (padrão 10).
2. Busca em arquivo fonte; pula gerado, dependência vendorizada, lockfile e doc.
3. Rankeia do mais redundante pro menos.
4. Pega a idade de cada candidato com `git blame` (ver Idade do comentário).
5. Apresenta a tabela abaixo, depois pergunta se remove todos os recomendados (ver Feedback).
6. Se sim, trata todo item `Remover` como aprovado. Se não, pergunta `Remover` ou `Manter`
   item a item, nomeando pelo texto exato, não pela localização.
7. Remove só o aprovado.
8. Roda lint/typecheck do projeto e corrige o que quebrar.

Delegue a busca read-only pra um subagente rápido e de baixo raciocínio quando disponível
(ex: `Explore`, ou `caveman:cavecrew-investigator` se o repo tiver caveman ativo): pede no
máximo o limite, cada um com caminho exato, linha, texto do comentário e uma a três linhas
de código ao redor. Sem subagente disponível, busca direto.

## Idade do comentário

Pra cada candidato, roda:

```bash
git blame -L <linha>,<linha> --date=relative -- <arquivo>
```

Usa a data relativa. Linha sem commit marca `uncommitted`.

## Saída obrigatória

Usa exatamente estas colunas:

```markdown
| Comentário | Idade | Porquê |
|---|---|---|
| `// incrementa o contador` | 8 meses atrás | *Remover.* Repete `count++` literalmente. |
| `/** Retorna o id do usuário. */` | 3 semanas atrás | *Remover.* Descreve a função palavra por palavra. |
| `// debounce evita martelar a API a cada tecla` | 1 ano atrás | *Manter.* Explica intenção, não mecânica. |
```

- **Comentário**: texto exato entre crases.
- **Idade**: idade relativa do `git blame`.
- **Porquê**: começa com `*Remover.*` ou `*Manter.*`, depois razão curta.

## Feedback

Depois da tabela, pergunta:

> **Remove todos os recomendados?**
> - Sim, remove todos os recomendados
> - Não, quero revisar um por um
