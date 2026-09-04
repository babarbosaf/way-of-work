# Infra e migração de schema

Artefato de fidelidade é o que afirma que dois ambientes são equivalentes: baseline,
prova de equivalência, snapshot de prod. Ele só vale se o reconhecimento veio antes.

## Reconhecer antes de afirmar

- **Versão real do servidor**, lida do servidor, não do que o projeto declara.
- **Enumeração dinâmica de objetos.** Lista escrita à mão envelhece entre uma rodada e a
  seguinte.
- **Tipos invisíveis a `information_schema`.** Extensão, tipo composto, domínio e enum
  não aparecem onde se costuma olhar, e o artefato passa verde sem cobri-los.

## CI e prod não são sonda

Descobrir o ambiente rodando a migração contra ele troca leitura barata por incidente
caro, e o resultado ainda vem incompleto: o primeiro erro aborta antes de revelar o
segundo. Reconhecimento é consulta de leitura, feita antes, com o resultado guardado.
