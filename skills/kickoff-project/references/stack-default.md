# Stack default

Ponto de partida, não amarra. Confirmar na Fase 0 da entrevista se o projeto mantém ou
troca. Se trocar, capturar a stack nova e adaptar as seções transversais do PRD, o
CONVENTIONS.md e a seção de tooling do design, mantendo o mesmo nível de profundidade.

## Onde vive a sua

Este arquivo é o molde. A stack que **você** repete de projeto em projeto vive em
`config/stack.local.md`, que é gitignored: ela é sua e não pertence ao template público.
Sem esse arquivo, a Fase 0 pergunta a stack do zero, e o exemplo abaixo serve de régua de
profundidade.

Uma stack default declarada responde seis coisas, e é isso que o arquivo local precisa
cobrir:

1. **Front.** Framework, build, o que roda no cliente e o que nunca pode chegar ao bundle.
2. **Backend e dados.** Onde o dado mora, como o acesso é restrito, como a tela lê.
3. **Trabalho pesado.** Linguagem e onde roda o que não cabe no caminho do usuário.
4. **Segredos.** Onde ficam e o que nunca é versionado.
5. **Funcionalidade com IA generativa,** se houver. Onde a chamada ao modelo vive.
6. **Deploy.** Onde roda cada peça e a relação de latência entre elas.

## Exemplo preenchido

Serve de régua de profundidade, não de prescrição. Um produto web lendo de um Postgres
gerenciado, com o trabalho pesado fora do caminho do usuário. Dados externos nunca são
consultados direto pelo navegador: rotinas agendadas mantêm um cache local atualizado, e o
app lê só desse cache. Cada tela busca o que precisa em poucas idas ao banco, protegidas
por RLS.

- **Front.** React com Vite (SPA). Interatividade no cliente; dado sensível nunca chega
  ao bundle.
- **Backend e dados.** Postgres gerenciado. Acesso a dado sensível protegido por RLS
  (regras de visibilidade no próprio banco). Leituras de tela consolidadas em funções de
  banco (RPC) quando a tela pede mais de uma consulta. DDL e queries administrativas via
  API de management. Dados analíticos em camadas medalhão (`bronze` → `silver` → gold),
  com só a camada gold exposta pela API.
- **Workers.** Python para coleta, ETL e jobs pesados, fora do caminho do usuário.
  Agendamento leve (sync de cache, push) por `pg_cron` e edge functions.
- **Segredos.** Cofre gerenciado do provedor. Nada de segredo versionado; `.env` é
  fallback de transição, não fonte.
- **Funcionalidade com IA generativa.** A chamada ao modelo vive em edge function, nunca
  no cliente.
- **Deploy.** Funções e front na mesma região do banco, pra evitar custo de roundtrip
  cross-region.

## Ao trocar a stack

O método não muda: a entrevista, a anatomia dos documentos e a régua de profundidade
continuam iguais. Muda o conteúdo das seções transversais do PRD, o CONVENTIONS.md e a
seção de tooling do design. Descrever a stack nova no mesmo nível: quais peças, como os
dados fluem, qual a cadência de atualização, qual a estratégia de performance.
