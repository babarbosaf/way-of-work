# Ticket de QA Manual

Um ticket por rodada de `/execute`, no mesmo backend dos outros. Já existe um pra
esta spec: enriquecer, nunca duplicar. Título: `QA Manual: <spec-slug>`.

## Regra dos cenários

- **MECE.** Cada comportamento observável da spec cai em exatamente um cenário.
  Teste: pegar cada critério de aceite da spec e apontar o cenário que o cobre;
  critério sem cenário ou cenário sem critério é buraco.
- **Testável por humano.** Passos que uma pessoa executa na interface ou CLI real,
  resultado esperado observável. "Verificar que funciona" não é cenário.
- **Veredito por cenário.** `validado por agente` quando um teste automatizado ou
  execução real cobriu; `pendente humano` quando exige olho, ambiente ou dado que
  o agente não tem. O que dá pra validar sozinho, valida e marca, com o comando
  ou evidência ao lado.

## Molde

```
QA Manual: <spec-slug>

Contexto: <link da spec e da PR>
Ambiente: <onde testar, credencial ou dado necessário>

Cenários:

QA-01 <título curto>
  Dado:     <estado inicial>
  Quando:   <passos numerados>
  Então:    <resultado observável>
  Cobre:    <critério de aceite da spec>
  Veredito: validado por agente (<comando ou evidência>) | pendente humano

QA-02 ...

Fora do QA manual (coberto só por suíte): <lista curta, com o teste que cobre>
```

## Ordem

Cenários pendentes primeiro, do mais arriscado pro menos. Quem abre o ticket
começa pelo que só ele pode fazer.
