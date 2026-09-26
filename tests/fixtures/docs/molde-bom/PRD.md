# PRD: x

## 1. Visão geral

`previsto`

```
FONTE ──lê──▶ BANCO ──serve──▶ LEITOR
```

## 2. Busca

`no ar`

### Propósito

Achar um item sem saber onde ele está.

### Fluxo

Quem procura digita, e a lista filtra a cada tecla. Sem resultado, a mesma lista
oferece a busca no acervo inteiro.

### Regras

| Quando | O produto garante |
|---|---|
| a consulta tem menos de três letras | a lista não filtra, e diz por quê |
| a consulta não casa com nada | devolve lista vazia, nunca erro |

## Relacionado

- [CONVENTIONS.md](CONVENTIONS.md): regras.
- [README.md](README.md): mapa.
- [AGENTS.md](AGENTS.md): agente.
