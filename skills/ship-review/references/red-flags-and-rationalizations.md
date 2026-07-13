# Red flags e rationalizations — ship-review

## Red flags

- 🚩 Finding Critical em aberto → não ship
- 🚩 Mudança > 300 linhas → dividir em commits menores antes de revisar (disciplina de atomic commits: ver `git-workflow-and-versioning`)
- 🚩 "Corrijo depois do merge" → não; cleanup antes
- 🚩 Feature nova sem teste novo → Important automático
- 🚩 Refactor misturado com feature → separar em commits
- 🚩 `os.getenv("TOKEN")` sem `.env.example` → documente
- 🚩 `except Exception: pass` → silencia falhas de segurança também
- 🚩 Token/chave hardcoded "temporário" → nunca é temporário
- 🚩 Resposta ao usuário inclui traceback → configure error handling

## Rationalizations

| Desculpa | Por que não aceitar |
|---|---|
| "É pequeno, não precisa review" | Reviews rápidos evitam bugs caros |
| "Já vi sendo escrito, sei que está certo" | Escrever e revisar são modos cognitivos diferentes |
| "Limpo na próxima sprint" | Dívida técnica acumula juros compostos |
| "Uso pessoal, não precisa segurança" | Credenciais expostas no git são permanentes |
| "Movo para .env depois" | Depois não existe; o commit já foi feito |

### Red flags do ship-review

- 🚩 Ship-review invocando `peer-review.sh` direto — viola ownership único de writer. `spec-and-plan` e `test-and-debug` são donos do Evaluator Status Block; ship-review só lê.
- 🚩 Ship-review escrevendo Evaluator Status Block próprio — mesma razão.
- 🚩 Marcar "sem bloqueantes" quando Block indica `indisponível`, `blocked_precondition`, `critical_aberto` ou `teto_atingido` — invalida o processo.
