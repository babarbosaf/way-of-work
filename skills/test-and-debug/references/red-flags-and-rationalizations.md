# Red flags e rationalizations — test-and-debug

## Red flags

- 🚩 `try/except` amplo "escondendo" o erro → investigue a causa
- 🚩 "Funciona na minha máquina" → documente diferença de ambiente
- 🚩 Corrigindo sintoma sem entender causa → bug volta diferente
- 🚩 Removendo o teste que falha → nunca
- 🚩 Teste sempre passa independente da implementação → testando framework, não código
- 🚩 `pytest.skip` sem data e justificativa → bugs silenciosos
- 🚩 Teste depende de ordem de execução → isolamento quebrado
- 🚩 Mocks em excesso de lógica interna → testando implementação, não contrato
- 🚩 Logs de debug em prod → remover após uso

## Rationalizations

| Desculpa | Por que não aceitar |
|---|---|
| "Adiciono testes depois" | "Depois" nunca vem; custo sobe 3x |
| "Código simples demais para testar" | Código simples é o mais fácil de testar |
| "Já testei manualmente" | Manual não é regressão |
| "Vou resolver depois, é raro" | Bugs raros viram críticos no pior momento |
| "É problema da API externa" | Adicione handling para o caso externo mesmo assim |
