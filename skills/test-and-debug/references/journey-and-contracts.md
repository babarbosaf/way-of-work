# User journey tests, scenario tests e output contracts

Três tiers, confiança crescente:
- **Journey** (código, bordas mockadas) — fluxo entre comandos, barato, roda no CI.
- **Scenario** (sistema real, superfície do usuário, computer-use) — a prova final "como o usuário faria + como o sistema reage". Não mocka borda.
- **Output contract** (forma da saída) — estrutura de payload/log/UI, ortogonal aos dois.

Scenario NÃO substitui journey — complementa. Journey pega fluxo em <30s no CI; scenario pega o que só aparece no app rodando (a "pele").

## User journey tests — uma user story por classe (obrigatório em features multi-comando)

Output contracts pegam **canal limpo por comando**, mas não pegam **fluxo entre comandos**. Bugs típicos que jornadas pegam:
- Ação declarada na interface mas nenhum dispatcher a roteia (handler "morto")
- Handler que é stub MVP (responde "em breve" sem nunca virar real)
- Comando 1 grava state que comando 2 lê — sequência específica falha sem que cada comando isolado esteja errado
- Idempotência (replay de retry de webhook duplica side effect)

**Padrão:** `tests/test_user_journeys.py` com **uma classe por user story**. Docstring no formato:
> "Story: Como `<persona>`, quero `<objetivo>` pra `<razão>`."

Estrutura por teste:
```
Arrange: estado inicial (state, mocks das bordas externas)
Act:     sequência de calls/payloads simulando as ações do usuário
Assert:  estado final + handlers chamados + writes externas
```

### Quando exigir jornada (gate antes de SHIP)

- Feature toca **2+ comandos/handlers** que se encadeiam
- Feature usa **state pendente** (pending_*) que sobrevive entre 2 ações do user
- Feature tem **ação declarada na interface** que precisa de handler em outro arquivo
- Feature tem **modal / submissão de formulário** ou outro retorno assíncrono
- Feature tem **idempotência crítica** (webhook, command replay, retry)

### Anti-padrão

- "O usuário testa na mão" como AC final. Substitua por: "Jornada X em `test_user_journeys.py` exercita os mocks de borda + state, verde no CI".
- "Cada comando tem seu próprio test file". Comandos isolados não capturam fluxo. Adicione jornadas ortogonais.
- Jornada que apenas instancia 1 comando — não é jornada, é unit. Remova ou promova pra contract test.

### Cobertura mínima por feature

Pergunte: "Quais são as 3-7 sequências de cliques que um usuário real faria pra extrair valor?" Cada uma vira 1 classe `Test<Story>Journey`. Se não consegue listar 3, a feature provavelmente é too small for journey tests — fica em unit + contract.

## Scenario tests — computer-use, valida como o usuário faria

Journey mocka a borda e chama em código. **Scenario não mocka nada**: dirige o
sistema rodando pela superfície real do usuário e observa a reação como o usuário
a vê. É a resposta pro anti-padrão "validado na mão" — mas com evidência e roteiro.

**Execução delegada à skill `verify`** (motor de computer-use / driving do app).
test-and-debug diz **o que dirigir e o que observar**; `verify` (ou `run`) **dirige**.
Não reimplementar mecânica de browser/CLI aqui — invocar `verify` e anexar a evidência.

### Superfície por tipo de sistema

| Sistema | Como o usuário dirige (scenario) | O que observar |
|---|---|---|
| Web / app | browser via computer-use (`verify`) — clica, digita, navega | tela renderizada, estado visível, erro na UI |
| CLI / pipeline | rodar o binário real com input do usuário | stdout/exit real, arquivo/output gerado |
| Bot (Slack/WhatsApp) | mandar mensagem real no canal de teste | card/resposta que o usuário recebe |
| Dado (Notion/CSV/BI) | rodar o publish e abrir a superfície | linha/propriedade como o consumidor vê |

### Quando exigir (sempre que possível)

Gate: mudança **user-facing** COM superfície dirigível → scenario antes de SHIP.
- Há superfície observável (tela, canal, CLI, output publicado) E o bug/feature muda o que o usuário vê ou faz.
- Sem superfície (lib pura, util interno, função sem consumo externo) → `n/a`; fica em unit + journey.

### O que capturar (a evidência é o teste)

- A **reação do sistema como o usuário a vê**, não só o retorno interno: screenshot / transcript / output real anexado.
- O **roteiro executado** (passos que `verify` dirigiu) — reproduzível, não "cliquei umas coisas".
- Bordas visíveis: mensagem de erro que o usuário leria, empty state, estado pós-ação.

### Anti-padrão

- "Validado manualmente" solto, sem artefato → scenario test com evidência observável (screenshot/transcript).
- "Journey verde = pronto" quando há UI → journey não vê a pele. Jornada pode passar e a UX estar quebrada; só aparece no app real. Scenario é o gate que pega isso.
- Reimplementar driving de browser/CLI dentro do teste → delegar ao `verify`; scenario é doutrina (o quê/quando/observar), não motor.

## Output contracts — assertions estruturais (obrigatório)

Bugs que escapam pro prod tendem a estar em **bordas**: log estruturado com chave faltando, SDK chamado com tipo errado, handler que não emite observabilidade, retrofit incompleto. Tests baseados em "output contém substring X" não pegam isso.

**Padrão Output Contract:** quando um handler/comando produz saída para um sistema externo (UI estruturada, log JSON, payload pra SDK/API), escreva um teste que asserte a **forma** da saída — não o conteúdo textual.

### Exemplos canônicos

| Situação | Teste fraco (não pega bug) | Output contract (pega bug) |
|---|---|---|
| Log estruturado novo (`event=foo`) | `assert "foo" in caplog.text` | `json.loads(msg)` + `REQUIRED_KEYS - payload.keys() == set()` |
| Comando emite UI estruturada | `assert "📥" in str(saida)` | `assert saida[0]["type"] == "header"` + 1ª seção tem o campo esperado |
| SDK/API externo (config tem efeito) | mock retorna fixture pronta | capturar kwargs com FakeClient, assert `timeout >= 1000ms` + params de config corretos |
| Wiring de observabilidade em N comandos | testa 1 e assume os outros | varre o entrypoint por decorator + grep do emissor para cada comando esperado |
| Nome de campo varia (PT vs EN, alias) | hardcode `"Name"` no fixture | itera os campos, filtra por tipo, não por nome literal |

### Quando exigir output contract

- Ao introduzir log estruturado novo (JSON via `logger.info(json.dumps(...))`).
- Ao integrar SDK/API externo cuja config tem efeito (timeout, region, parâmetros) — confirmar assinatura/versão atual via `use context7` antes de escrever o teste.
- Ao adicionar comando/handler novo a uma família com observabilidade compartilhada (wiring uniforme).
- Ao retrofitar layout (helpers `render_*`) — assert que o helper é o usado, não saída ad-hoc.
- Ao parsear input externo com nomes de campo variáveis (aliases, PT vs EN).

### Prove-It Pattern aplicado a contratos

Todo bug de contrato encontrado em prod precisa virar 1 teste no arquivo `test_*_contracts.py` do módulo. Modelo:

```python
class TestFooContract:
    """Cada teste documenta um bug histórico no docstring."""

    def test_<aspecto>_<comportamento_esperado>(self):
        """B<N> — descrição curta do bug. Comentário linka commit/log."""
        # Arrange real ou fake mínimo
        # Act invoca o handler
        # Assert na forma, não no conteúdo
```

Princípio: **se um bug ficou invisível ao test runner, o teste é fraco — não o código.** Output contracts aumentam o sinal nas próximas mudanças.
