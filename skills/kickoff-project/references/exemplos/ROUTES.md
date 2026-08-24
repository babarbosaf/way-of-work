# Árvore de rotas, Chutaí

Mapa completo das telas do app. Complementa o PRD (referência de navegação e estrutura de URLs).

## Pré-autenticação

Sem bottom nav. Duas portas de entrada: convite (única forma de criar conta) e login (reentrada).

| Rota | Descrição |
|---|---|
| `/` | Abertura sem sessão e sem convite. CTA "Entrar" → `/login`. Texto secundário: "Novas contas são por convite" |
| `/entrar/:codigo` | Deep link de convite. Código válido + sem sessão → `/cadastro`. Código válido + com sessão → sheet "Entrar no grupo X?" → `/grupo/liga`. Código inválido/expirado/cheio/encerrado → `/entrar/erro` |
| `/entrar/erro` | Motivo do código inválido. Instrui pedir novo link |
| `/cadastro` | Única tela de cadastro, acessível apenas com token de convite. Campos: nome, apelido, email, senha. Atalhos: Google, Apple |
| `/cadastro/email-confirmacao` | Confirmação de email (se aplicável) |
| `/boas-vindas` | Onboarding pós-cadastro (6 passos, somente primeira vez) |
| `/boas-vindas/1` | Palpites |
| `/boas-vindas/2` | Grupo e Liga |
| `/boas-vindas/3` | Pergunta Plus |
| `/boas-vindas/4` | Álbum |
| `/boas-vindas/5` | Streak e missões |
| `/boas-vindas/6` | Boas-vindas ao grupo "X" |
| `/login` | Email + senha, Google, Apple, link mágico. Link "Esqueci a senha" |
| `/login/link-magico` | Insere email → Supabase dispara magic link (`signInWithOtp`) |
| `/recuperar-senha` | Envia email com link de reset |

## Pós-autenticação (bottom nav)

5 abas. Sino de notificações no header de cada aba.

### Aba 1, Início (passiva, informacional)

Sem CTAs, sem ações. Espaço de contexto sobre a Copa.

| Rota | Descrição |
|---|---|
| `/inicio` | Hero da Copa, calendário do dia (read-only), próximos jogos da semana, resultados recentes, info do bolão |
| `/inicio/calendario` | Calendário completo da Copa |
| `/inicio/jogo/:id` | Detalhe informativo: escalações prováveis, histórico, sede |
| `/inicio/regras` | Regras completas, pontuação, multiplicadores |
| `/inicio/copa` | Mapa geográfico das 16 sedes (pins por lat/long), lista de estádios com capacidade, seleções classificadas agrupadas por continente e chaveamento do mata-mata |

### Aba 2, Palpites (transacional)

Sub-abas: Jogos, Torneio.

| Rota | Descrição |
|---|---|
| `/palpites` | Default → `/palpites/jogos` |
| `/palpites/jogos` | Lista. Sub-filtros: Hoje, Próximos, Encerrados. Filtro por fase |
| `/palpites/jogos/:id` | Placar exato + V/E/D + Pergunta Plus. Contador regressivo. Indicador "X amigos palpitaram, Y ainda não". Histórico do confronto |
| `/palpites/jogos/:id/ao-vivo` | Placar ao vivo, escalações, gols com minuto, snippet do ranking do grupo |
| `/palpites/jogos/:id/resultado` | Pós apito final. Seu palpite vs resultado real. Pontuação detalhada. Quem do grupo acertou |
| `/palpites/torneio` | Long-term picks. Banner de contagem regressiva para 17/06 |
| `/palpites/torneio/campeao` | Pick do campeão |
| `/palpites/torneio/vice` | Pick do vice |
| `/palpites/torneio/terceiro` | Pick do 3º lugar |
| `/palpites/torneio/quarto` | Pick do 4º lugar |
| `/palpites/torneio/artilheiro` | Pick do artilheiro |
| `/palpites/torneio/bola-de-ouro` | Pick do melhor jogador |
| `/palpites/torneio/jovem-revelacao` | Pick do melhor jogador jovem (sub 21) |
| `/palpites/historico` | Histórico pessoal de palpites |

### Aba 3, Grupo

Sub-abas: Liga, Estatísticas.

| Rota | Descrição |
|---|---|
| `/grupo` | Default → `/grupo/liga` |
| `/grupo/liga` | Ranking com pontuação. Indicador de critério de desempate. Filtros: geral, por fase, por dia |
| `/grupo/liga/membro/:id` | Perfil público do membro com estatísticas |
| `/grupo/estatisticas` | Estatísticas do grupo (PRD §8): termômetro, quem palpitou hoje + cutucada, destaques do dia, raio X dos jogos, zebra/consenso, álbum do grupo |
| `/grupo/mural` | Removida (12/06/2026). Redirect → `/grupo/estatisticas` |
| `/grupo/info` | Nome, descrição, admin, lista de membros, **sair do grupo** |
| `/grupo/trocar` | Seletor (quando o usuário está em mais de um grupo) |
| `/grupo/entrar` | Inserir código de convite manualmente |

### Aba 4, Álbum

Coleção, drop diário, missões, trocas.

| Rota | Descrição |
|---|---|
| `/album` | Progresso geral X/154. Indicador "Y pacotes para abrir". Cards das 4 coleções |
| `/album/drop-diario` | Resgate do dia |
| `/album/drop-diario/abertura` | Animação de abrir pacote |
| `/album/drop-diario/resumo` | Figurinhas novas vs repetidas |
| `/album/missoes` | Ações que geram pacote extra. Pacotes ganhos hoje |
| `/album/colecao/:slug` | Grid com slots vazios e figurinhas obtidas |
| `/album/figurinha/:id` | Detalhe: repetidas que tenho, quem do grupo tem |
| `/album/repetidas` | Todas as duplicadas |
| `/album/trocas` | Hub de trocas. Sub-abas: Ofertas recebidas, Trocas ativas, Histórico |
| `/album/trocas/nova` | Escolher membro do grupo |
| `/album/trocas/nova/:userId` | Matchmaking entre "Tenho" e "Quero" |
| `/album/trocas/:id` | Detalhe com confirmação dupla |
| `/album/listas` | Gerenciar listas Tenho e Quero |

### Aba 5, Perfil

| Rota | Descrição |
|---|---|
| `/perfil` | Nome, apelido, avatar. Streak atual e máximo. Estatísticas. Milestones |
| `/perfil/streak` | Calendário visual de manutenção |
| `/perfil/editar` | Apelido, avatar |
| `/perfil/notificacoes` | Preferências de push por categoria |
| `/perfil/configuracoes` | Idioma, fuso, tema, contas conectadas |
| `/perfil/ajuda` | Regras, FAQ, "Ver tour novamente" (reabre `/boas-vindas`) |
| `/perfil/sobre` | Termos, privacidade, versão |
| `/perfil/sair` | Logout |
| `/perfil/deletar-conta` | LGPD: confirmar deleção de conta |

## Públicas (sem sessão)

Acessíveis a qualquer pessoa, sem login. Pensadas para compartilhamento.

| Rota | Descrição |
|---|---|
| `/calendario` | Calendário público da Copa. Botões de assinar (Google Agenda, Apple/Outlook via webcal, baixar/copiar .ics) e lista de jogos por dia com link de transmissão da Cazé TV |
| `/calendario/copa.ics` | Feed iCalendar assinável. Lido do cache Supabase a cada request (mata-mata e URLs de transmissão entram conforme são definidos) |

## Camada global

| Rota | Descrição |
|---|---|
| `/notificacoes` | Histórico cronológico. Aberta via sino no header de qualquer aba |

### Deep links de push

Ver seção 15 do PRD para o mapeamento completo de evento → rota.
