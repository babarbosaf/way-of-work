---
name: block-commit-no-tests
enabled: true
event: bash
action: warn
pattern: git\s+commit.*(?!test)
---

⚠️ **Commit sem rodar testes!**

**Lembrete:** Sempre rode `{{TEST_CMD}}` antes de commitar.

**Processo recomendado:**
```bash
# 1. Rodar testes
{{TEST_CMD}}

# 2. Verificar se todos passaram
# 3. Então commitar
git commit -m "mensagem"
```
