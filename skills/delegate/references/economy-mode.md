# Modo economia (sessão inteira)

Ativa quando o usuário sinaliza pressão de consumo — "modo economia",
"economiza", "otimiza o consumo", "seja eficiente nesta sessão", "tô perto do
limite (5h/semanal)". Uma vez ativo, vale até o fim da sessão (ou "desliga o
modo economia"):

- **Rotear agressivamente** pros workers grátis tudo que couber num task-type
  (scan, review, second-opinion, boilerplate) — inclusive tarefas que fora do
  modo você faria inline por conveniência.
- **Claude fica só com o core**: decisão, integração de código, síntese final
  e o que depende do contexto vivo da conversa.
- **Opção A continua valendo** pra tasks de spec: o modo economia não promove
  task sem marcador `delega:` — mas pedido ad-hoc explícito do usuário sempre
  pode ser despachado (o pedido É a decisão).
- **Cascata esgotada (exit 2) → fallback interno mais barato que dá conta**:
  mecânico/varredura simples → subagente haiku effort low; leitura/auditoria →
  sonnet low; escalar só se o resultado voltar fraco (1 escalada máx). Nunca
  opus/fable em modo economia sem pedido explícito. Tarefa pesada → avisar o
  custo antes de assumir.
- **Scans grandes: fatiar.** Auditoria de sistema inteiro num prompt só estoura
  timeout do worker — despachar um `scan` por subsistema e sintetizar os
  resultados no orquestrador.
