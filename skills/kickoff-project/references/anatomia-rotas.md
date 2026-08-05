# Anatomia do documento de rotas

Descreve o mapa de telas. Exemplo canônico em `exemplos/ROUTES.md` (Chutaí).

O documento de rotas se DERIVA do PRD. Cada feature do PRD implica telas; cada estado de
uma feature implica uma rota. Escrever este documento depois do PRD, lendo feature por
feature e perguntando "quais telas isso exige, e em que estados?".

## Função

É o esqueleto de navegação que amarra o PRD. Serve para:

- Enumerar toda tela do produto antes de construir qualquer uma.
- Registrar a lógica condicional de navegação (o que acontece quando o código é válido e
  não há sessão, quando há sessão, quando expirou).
- Dar a estrutura de URLs, que orienta a organização do código depois.

## Estrutura

Agrupar as rotas por estado de acesso e contexto de navegação, não em uma lista única.
Grupos típicos:

- **Pré-autenticação.** Portas de entrada (convite, cadastro, login, recuperação,
  onboarding). Sem navegação principal.
- **Pós-autenticação.** As abas da navegação principal. Uma subseção por aba. Se há bottom
  nav ou sidebar, cada aba vira um grupo com suas sub-rotas e sub-abas.
- **Públicas.** Acessíveis sem sessão, pensadas para compartilhamento.
- **Camada global.** Rotas abertas de qualquer contexto (ex.: central de notificações
  aberta pelo sino em qualquer aba).

Dentro de cada grupo, uma tabela `Rota | Descrição`.

## O que vai na descrição de cada rota

A descrição não é o nome da tela. É o que a tela faz e como ela se comporta:

- O conteúdo principal da tela.
- A lógica condicional de entrada e saída quando houver ("código válido mais sem sessão
  leva para cadastro; código válido mais com sessão abre a folha de confirmação").
- Redirecionamentos e defaults ("`/grupo` redireciona para `/grupo/liga`").
- Guardas de estado ("tela de palpite fica inacessível após o início do jogo, redireciona
  para ao-vivo ou resultado").

## Convenções

- **Parâmetros de rota** com dois-pontos (`/palpites/jogos/:id`) ou colchetes, consistente
  com a stack. Manter o mesmo estilo do exemplo dentro de um mesmo documento.
- **Rotas removidas** ficam registradas com a data e o redirect ("Removida em 12/06/2026.
  Redirect para `/grupo/estatisticas`"). Preserva a memória da navegação.
- **Sub-abas** anotadas no grupo da aba.
- **Deep links de notificação** mapeados no fim, referenciando a seção do PRD que descreve
  o evento (evento leva a rota).

## Como derivar do PRD

Percorrer o PRD e, para cada feature:

1. Listar as telas que ela exige.
2. Para cada tela, listar os estados que viram rotas distintas (pré-jogo, ao-vivo,
   resultado; lista, detalhe, edição).
3. Encaixar cada rota no grupo de acesso correto.
4. Escrever a lógica condicional de navegação que o PRD já definiu nas regras e edge cases.

O documento de rotas fica completo quando toda feature do PRD tem suas telas mapeadas e
todo estado relevante tem uma rota.
