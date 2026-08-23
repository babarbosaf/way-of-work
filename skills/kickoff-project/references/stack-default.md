# Stack default

O padrão da casa. É o ponto de partida, não uma
amarra. Confirmar na Fase 0 da entrevista se o projeto mantém ou troca. Se trocar,
capturar a stack nova e adaptar as seções transversais do PRD, o CONVENTIONS.md e a seção
de tooling do design, mantendo o mesmo nível de profundidade.

## Visão conceitual

A stack default assume um produto web lendo de um Postgres gerenciado, com o trabalho
pesado fora do caminho do usuário. Dados externos nunca são consultados direto pelo
navegador: rotinas agendadas mantêm um cache local atualizado, e o app lê só desse cache.
Cada tela busca o que precisa em poucas idas ao banco, protegidas por RLS.

## Camadas

- **Front.** React com Vite (SPA). Interatividade no cliente; dado sensível nunca chega
  ao bundle.
- **Backend e dados.** Supabase (Postgres gerenciado). Acesso a dado sensível protegido
  por RLS (regras de visibilidade no próprio banco). Leituras de tela consolidadas em
  funções de banco (RPC) quando a tela pede mais de uma consulta. DDL e queries
  administrativas via Management API. Dados analíticos em camadas medalhão
  (`bronze` → `silver` → gold), com só a camada gold exposta pela API.
- **Workers.** Python para coleta, ETL e jobs pesados, rodando na infra da casa.
  Agendamento leve (sync de cache, push) por `pg_cron` + edge functions no Supabase.
- **Segredos.** Supabase Vault (ADR-0002). Nada de segredo versionado; `.env` é fallback
  de transição, não fonte.
- **Funcionalidade com IA generativa.** Padrão LLM-in-Edge (ADR-0006): a chamada ao
  modelo vive em edge function, nunca no cliente.
- **Deploy.** Funções e front na mesma região do banco (`sa-east-1`) para evitar custo de
  roundtrip cross-region.

## Ao trocar a stack

Se o projeto usa outra stack, o método não muda: a entrevista, a anatomia dos documentos
e a régua de profundidade continuam iguais. O que muda é o conteúdo das seções
transversais do PRD, o CONVENTIONS.md e a seção de tooling do design. Descrever a stack
nova no mesmo nível: quais peças, como os dados fluem, qual a cadência de atualização,
qual a estratégia de performance.
