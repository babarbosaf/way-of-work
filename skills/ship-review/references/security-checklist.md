# Checklist de segurança — ship-review

## Checklist de segurança (aplicar sempre antes do ship)

> Em spec de tier **governança**, este checklist **verifica** o Modelo de Ameaça definido na spec (`spec-and-plan` → Security): confirma que cada vetor previsto tem defesa no código. Não redefine o modelo.

- [ ] Credenciais apenas em `.env` / secret manager — nunca no código
- [ ] `.env` no `.gitignore`; `.env.example` existe com placeholders
- [ ] Inputs externos validados na boundary de entrada (tipo, tamanho, formato)
- [ ] Input externo não é usado diretamente em query, path ou eval
- [ ] Erros retornam mensagem genérica ao usuário final (sem stack trace)
- [ ] Logs sem tokens, senhas, PII
- [ ] Bot/serviço usa apenas scopes/permissões necessárias (least privilege)
- [ ] HTTPS para toda comunicação externa
- [ ] Dependências sem vulnerabilidades conhecidas (`pip-audit`, `npm audit`)

### Regras absolutas

**Sempre:** credenciais em env, validar input externo, HTTPS, logs sem sensíveis
**Perguntar antes:** mudar fluxo de autenticação, adicionar scope, armazenar dados de usuário, mudar CORS
**Nunca:** commitar `.env`, logar tokens/senhas/PII, `eval()` com dados externos, confiar em validação client-side como boundary, expor stack trace
