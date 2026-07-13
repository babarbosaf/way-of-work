# Matriz atividade × ranking de modelos

Referência quando a cascata automática não decide sozinha (fallback pós-exit-2,
subagente interno, override pedido pelo usuário). Cada linha é uma atividade;
a ordem na célula é o ranking daquela atividade (1º = tenta primeiro). Regra:
**descer na cascata da atividade, nunca pular pra "modelo melhor" de outra
linha** — capacidade sobrando é desperdício de quota.

| atividade | 1º | 2º | 3º | 4º | fallback sessão |
|---|---|---|---|---|---|
| `implement` (código autocontido) | codex gpt-5.4 | agy Claude Sonnet 4.6 (Thinking) | codex gpt-5.5 (lógica pesada) | agy Gemini 3.1 Pro (High) | Sonnet medium |
| `review` (spec/diff adversarial) | codex gpt-5.4 | agy Gemini 3.1 Pro (High) | agy Claude Opus 4.6 (Thinking) | codex gpt-5.5 | Sonnet medium |
| `second-opinion` (arquitetura, debug travado) | codex gpt-5.5 | agy Claude Opus 4.6 (Thinking) | codex gpt-5.4 | agy Gemini 3.1 Pro (High) | Opus high (pedido explícito) |
| `scan` (varredura, sumarização) | agy Gemini 3.5 Flash (High) | agy GPT-OSS 120B (Medium) | agy Gemini 3.1 Pro (Low) | codex gpt-5.3 | Haiku low |
| `boilerplate` (testes mecânicos, scaffolding, conversão) | agy GPT-OSS 120B (Medium) | agy Gemini 3.5 Flash (Medium) | codex gpt-5.3 | codex gpt-5.4 | Haiku low |
| docs/redação técnica | agy Gemini 3.5 Flash (High) | agy Claude Sonnet 4.6 (Thinking) | agy Gemini 3.1 Pro (High) | — | Sonnet medium |
| infra mecânica (plist, shell simples, config) | agy Gemini 3.5 Flash (Medium) | codex gpt-5.3 | agy GPT-OSS 120B (Medium) | — | Haiku low |

Notas de operação:
- **`claude_api` (`DELEGATE_ANTHROPIC_API_KEY`) está FORA do ranking**: pago
  dedicado, só entra quando o Benedito declarar explicitamente na conversa
  ("usa a key", "pode usar claude_api"). Nunca como fallback automático.
- **Fallback sessão** (subagente Claude do plano) só quando a task exige o
  harness Claude (tools/MCP/skills) ou a cascata externa esgotou — nunca como
  primeira opção pra task que worker grátis resolve.
- Quota dos bolsões agy: `claude_gpt` (Opus/Sonnet/GPT-OSS) enche rápido;
  `gemini` costuma ter folga — em empate de capacidade, preferir a coluna
  Gemini.
- codex default é gpt-5.4 (`~/.codex/config.toml`); 5.5/5.3 são override
  pontual de config.
- A cascata automática por task-type continua em `model-policy.json`; esta
  matriz não a substitui — alimenta escolhas manuais e o
  `/refresh-model-rankings`, único caminho pra promover mudança daqui pra
  policy. Atividades sem task-type na policy (docs, infra mecânica) roteiam
  por esta matriz diretamente.
