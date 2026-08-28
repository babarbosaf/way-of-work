# DESIGN.md, Chutaí Design System

Sistema de design "**Neon Night**" do Chutaí. Cobre as constraints do produto, tokens, padrões de componentes, princípios de layout e como construir telas novas sem cair no AI slop.

Quando este doc divergir do código real, **o código vence**. Atualize este arquivo no mesmo PR que mudar tokens, fontes, ou patterns globais.

Incômodo visual ainda não corrigido não entra aqui: vai como linha `[papercut]` no `TODOS.md` e volta como constraint na próxima passada de design. Aqui só o que já é norma.

---

## 1. Identidade

Mobile-first bolão social brasileiro pra Copa do Mundo 2026. **Playful-confiante com energia esportiva**, sem cair em samba-clichê nem "AI purple sports app".

**Vibe references:**
- Amazon Music dark + cyan accent
- Coinbase / One Banking dark + accent saturado
- Sleeper sports app pra densidade visual e tipo grande
- How We Feel pra moodboard de cards coloridos sticker-y

**Dial values** (do skill `design-taste-frontend`):
- `DESIGN_VARIANCE: 7`, assimetria controlada, cards com tamanhos variados
- `MOTION_INTENSITY: 6`, micro-interações spring-y, hover lifts
- `VISUAL_DENSITY: 3`, espaçoso, focado em hierarquia clara

**Modo de cor:** **DARK MODE LOCKED no MVP**. Não há light mode. `<html class="dark" style="color-scheme: dark">` no `src/app/layout.tsx`. Tokens light em `:root` são placeholders; as cores reais vivem em `:root, .dark` no `src/app/globals.css`.

---

## 2. Constraints

O que todo desenho do Chutaí precisa satisfazer, antes de qualquer discussão de estética.
Tokens dizem *como* pintar; isto diz *o que precisa caber*. Proposta se avalia contra esta
lista, não contra gosto.

**Workflows a suportar** (ordem de frequência, e é ela que autoriza destaque):

1. Palpitar no próximo jogo antes do fechamento.
2. Ver a própria posição na liga do grupo.
3. Conferir resultado do palpite do jogo que acabou.
4. Abrir drop diário do álbum.
5. Trocar figurinha repetida.

Pedido de "deixa X mais destacado" só entra se mover X nesta ordem, ou se a ordem mudou.

**Estados obrigatórios** (todo card de lista, form e stat trata os seis):

- Vazio (grupo sem membros, sem palpite feito, álbum zerado).
- Carregando (skeleton com a mesma altura do conteúdo real, sem salto de layout).
- Erro (mensagem curta em português, com ação de retry).
- Um item só (não pode parecer grade quebrada).
- Muitos itens (lista de 40 membros, scroll sem perder o header sticky).
- Texto longo (nome de time e apelido de usuário truncam com ellipsis, nunca quebram o card).

**Pisos invioláveis:**

- Contraste WCAG AA, 4.5:1 em texto de corpo, 3:1 em texto grande.
- Área de toque mínima 44x44px em qualquer alvo tocável.
- `motion-safe:` em todo transform e scale, sem exceção.
- Densidade máxima: 1 ação primária visível por tela.
- Números métricos sempre `tabular-nums`.

---

## 3. Tokens

Todos os tokens estão definidos em `src/app/globals.css` como CSS custom properties OKLCH. Tailwind v4 expõe via `@theme inline`.

### 3.1 Cores

Use **sempre as utilities Tailwind tokenizadas**, nunca hex/oklch direto em componentes:

| Token | OKLCH | Uso |
|---|---|---|
| `bg-background` | `oklch(0.14 0.005 270)` | Fundo da página. Near-black com leve viés azulado. |
| `bg-card` | `oklch(0.19 0.005 270)` | Superfície de cards. Cinza escuro elevado. |
| `bg-popover` | `oklch(0.21 0.005 270)` | Modals, dropdowns. |
| `bg-muted` | `oklch(0.22 0.005 270)` | Fundo de chips/badges neutros. |
| `bg-secondary` | `oklch(0.24 0.005 270)` | Variantes secundárias. |
| `text-foreground` | `oklch(0.97 0.003 90)` | Texto primário (off-white). |
| `text-muted-foreground` | `oklch(0.68 0.008 90)` | Texto secundário. |
| `bg-primary` / `text-primary` | `oklch(0.91 0.23 130)` | **Lime neon, único acento brand.** |
| `text-primary-foreground` | `oklch(0.14 0.005 270)` | Texto sobre primary (near-black). |
| `bg-destructive` / `text-destructive` | `oklch(0.68 0.22 25)` | Erros, ações destrutivas. |
| `ring-border` | `oklch(1 0 0 / 8%)` | Bordas/anéis de 1px nos cards. |
| `bg-success` / `text-success` | `oklch(0.91 0.23 130)` | **Igual ao primary.** Reservado pra estados "palpite aberto", "acertou". |

**Regra de cor:** Lime é o **único acento**. Não introduza azul, vermelho, amarelo neon. Se precisar de mais hierarquia, varie **intensidade** (`bg-primary/15`, `bg-primary/30`, `bg-primary`) ou **chroma** (use neutrals mais claros/escuros).

**Glow pattern** (recorrente nos heroes):
```tsx
<div
  className="pointer-events-none absolute -right-24 -top-24 size-64 rounded-full bg-primary/20 blur-3xl"
  aria-hidden
/>
```

### 3.2 Tipografia

**Fonte única:** `Geist` (sans). `Geist Mono` para números tabulares e código. Outfit foi removido por ser excessivamente friendly contra o vibe techy-neon.

Variáveis CSS (em `globals.css`):
- `--font-sans-app` → Geist
- `--font-mono-app` → Geist Mono
- `--font-display` aponta pro mesmo Geist (sem alternative display por enquanto)

Tailwind utilities: `font-sans`, `font-mono`, `font-display` (alias de sans).

**Headlines globais** (no `@layer base` do `globals.css`):
- `h1`–`h4` recebem `letter-spacing: -0.025em` e `line-height: 1.05` automaticamente
- Use sempre `tracking-tight` ou tighter para reforçar

**Escala recomendada:**

| Uso | Classes | Notas |
|---|---|---|
| Hero gigante (números display) | `text-[5.5rem] font-black leading-[0.85] tracking-[-0.04em]` | "2026" no /inicio |
| Hero média (headline) | `text-[2.6rem] font-black leading-[0.95] tracking-[-0.03em]` | "Convite", "Recuperar senha" |
| Section header | `text-[22px] font-black tracking-tight` | "Próximos jogos", "Coleções" |
| Card title destaque | `text-[20px] font-black tabular-nums` | Valor em stat card |
| Card title médio | `text-[17px] font-black tracking-tight` | "Regras", "A Copa" |
| Card title compact | `text-[14px] font-black tracking-tight` | Item de coleção |
| Body principal | `text-[14px] font-medium leading-snug` | Descrições, textos corridos |
| Body secundário | `text-[12px] text-muted-foreground` | Helper text |
| Eyebrow | `text-[11px] font-bold uppercase tracking-[0.18em] text-muted-foreground` | Pré-headline. **Use no máximo 1 a cada 3 sections**. |
| Eyebrow forte | `text-[10px] font-bold uppercase tracking-wider text-primary` | Pill de status lime |
| Caption | `text-[11px] text-muted-foreground` | Time-ago, sub-info |
| Mini label | `text-[10px] font-medium uppercase tracking-wider text-muted-foreground` | Sob números em stats |

**Números tabulares:** sempre `tabular-nums` quando o número for métrico/estatístico. Evita "dança" de largura ao mudar de 9 pra 10.

**Italics:** raramente. Quando usar em headline display com `y/g/j/p/q`, garanta `leading-[1.1]` mínimo e `pb-1` reserve no wrapper (italic descender clearance).

### 3.3 Radius

Base `--radius: 1.25rem`. Escala derivada (via `@theme inline`):

| Tamanho | Valor | Uso |
|---|---|---|
| `rounded-sm` | 0.625rem | Sub-elementos pequenos |
| `rounded-md` | 0.9375rem | Inputs, chips médios |
| `rounded-lg` | 1.25rem | (raro) |
| `rounded-xl` | 1.75rem | Cards menores (stats, chips grandes) |
| `rounded-2xl` | 2.25rem | Cards padrão |
| `rounded-3xl` | 3rem | Cards grandes (jogos, ações) |
| `rounded-[2rem]` | 2rem | Hero cards principais |
| `rounded-full` | full | **Pills, badges, botões CTA, ícone-chips circulares** |

**Regra de forma:** o sistema é **soft + pill**. Botões CTA são SEMPRE `rounded-full`. Cards são `rounded-2xl` ou `rounded-3xl`. Badges/pills são `rounded-full`. Chips de ícone quadrados são `rounded-xl` ou `rounded-2xl`. **Nunca misture sharp e soft** numa mesma tela (zero radius bate em pill é inconsistente).

### 3.4 Motion

Sempre wrap em `motion-safe:` quando for transform/scale. CSS-only (sem `motion/react`) é suficiente pra interações atuais.

**Padrões recorrentes:**

```tsx
// Card hover lift
"transition-all motion-safe:hover:-translate-y-0.5 motion-safe:hover:ring-primary/40 motion-safe:active:translate-y-0 motion-safe:active:scale-[0.995]"

// CTA pill button
"transition-all motion-safe:hover:-translate-y-0.5 motion-safe:active:translate-y-0 motion-safe:active:scale-[0.98]"

// Icon arrow slide on group hover
"transition-transform motion-safe:group-hover:translate-x-0.5"

// Bottom nav icon press
"transition-transform motion-safe:group-active:scale-90"
```

Easing fica default (Tailwind ease-in-out). Durations default (150ms). Não over-engineerize.

### 3.5 Sombras

Cards normais: `shadow-sm`. Featured cards e CTAs lime: `shadow-lg shadow-primary/20` ou `shadow-xl shadow-primary/30` (lime tinted, NÃO black puro).

Sticker stack figurinhas: `shadow-2xl` + `ring-[3px] ring-card` ou `ring-background` (sticker peeking).

---

## 4. Patterns de Componentes

Os patterns abaixo são repetidos em múltiplas telas. Quando criar algo novo, **prefira ESTENDER um pattern existente** a inventar uma variante visual.

### 4.1 Hero card

Pattern: card grande com glow no canto, conteúdo em camada `relative` por cima.

```tsx
<section className="relative overflow-hidden rounded-[2rem] bg-card p-6 ring-1 ring-border">
  {/* Glow lime */}
  <div
    className="pointer-events-none absolute -right-24 -top-24 size-64 rounded-full bg-primary/20 blur-3xl"
    aria-hidden
  />
  {/* Decoração opcional (figurinhas, ícone gigante) */}

  <div className="relative flex flex-col gap-7">
    {/* Eyebrow pill */}
    <span className="inline-flex w-fit items-center gap-2 rounded-full bg-primary/15 px-3 py-1.5 text-[11px] font-bold uppercase tracking-wider text-primary">
      <FireIcon className="size-3.5" weight="fill" aria-hidden />
      Faltam 14 dias
    </span>

    {/* Headline + subtext */}
    <div>
      <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-muted-foreground">
        Copa do Mundo
      </p>
      <h1 className="mt-1 text-[5.5rem] font-black leading-[0.85] tracking-[-0.04em] text-foreground">
        2026
      </h1>
      <p className="mt-4 max-w-[260px] text-[14px] leading-relaxed text-muted-foreground">
        Subtext breve, máximo 20 palavras.
      </p>
    </div>

    {/* CTA pill */}
    <CtaButton href="/palpites/torneio">Palpitar torneio</CtaButton>
  </div>
</section>
```

**Hero stack discipline:** máximo **4 elementos textuais** (eyebrow, headline, subtext, CTA). Nada de "trust strip" ou tagline sob o CTA dentro do hero.

### 4.2 Card list item (JogoCard, RankRow, NotifRow, etc)

Pattern: link block com hover lift + ring lime no hover.

```tsx
<Link
  href="..."
  className="group block rounded-3xl bg-card ring-1 ring-border transition-all motion-safe:hover:-translate-y-0.5 motion-safe:hover:ring-primary/40 motion-safe:active:translate-y-0 motion-safe:active:scale-[0.995]"
>
  <article className="flex items-center gap-4 p-4">
    {/* Slot esquerdo: badge/avatar/numero */}
    {/* Conteúdo flex-1 */}
    {/* Slot direito: CTA arrow circular + status pill */}
  </article>
</Link>
```

**Estrutura típica do conteúdo:**
- Slot esquerdo: 9-12 size identifier (rank badge, avatar, data stamp)
- Conteúdo: 2 linhas de texto (título bold + subtitle muted)
- Slot direito: pill de status (lime tinted) + CaretRight ou círculo lime com ArrowRight

### 4.3 Stat card

Identidade visual única por stat. NÃO faça 4 stats idênticas. Veja `/inicio` `StatsRow`:

- **Stat destacado (Pontos):** card maior com gradient `from-card to-primary/10`, delta pill, sparkline SVG
- **Stat com timeline (Streak):** mini-barras representando dias
- **Stat com progresso (Palpites):** progress bar horizontal
- **Stat com ring (Figurinhas):** mini-anel SVG

```tsx
// Mini progress bar
<div className="h-1.5 overflow-hidden rounded-full bg-muted">
  <div className="h-full rounded-full bg-primary" style={{ width: `${pct}%` }} aria-hidden />
</div>

// Mini ring SVG (radius=9, stroke=2.5)
<svg width="22" height="22" viewBox="0 0 22 22" aria-hidden>
  <circle cx="11" cy="11" r="9" fill="none" stroke="currentColor" strokeWidth="2.5" className="text-muted" />
  <circle
    cx="11" cy="11" r="9" fill="none"
    stroke="currentColor" strokeWidth="2.5" strokeLinecap="round"
    strokeDasharray={`${dash} ${circumference}`}
    transform="rotate(-90 11 11)"
    className="text-primary"
  />
</svg>

// Mini streak bars
<div className="mt-2 flex gap-0.5">
  {dias.map((on, i) => (
    <span key={i} className={`h-1.5 flex-1 rounded-full ${on ? "bg-primary" : "bg-muted"}`} aria-hidden />
  ))}
</div>
```

### 4.4 CTA pill button

**Primário (lime preenchido):**

```tsx
<Link
  href="..."
  className="group inline-flex w-full items-center justify-center gap-2 rounded-full bg-primary px-6 py-4 text-[15px] font-bold text-primary-foreground shadow-lg shadow-primary/20 transition-all motion-safe:hover:-translate-y-0.5 motion-safe:active:translate-y-0 motion-safe:active:scale-[0.98]"
>
  Label
  <ArrowRightIcon className="size-4 transition-transform motion-safe:group-hover:translate-x-0.5" weight="bold" aria-hidden />
</Link>
```

**Secundário (dark com ring):**

```tsx
<Link
  className="inline-flex w-full items-center justify-center gap-2 rounded-full bg-card px-5 py-3 text-[13px] font-bold text-foreground ring-1 ring-border transition-colors hover:bg-muted/40"
>
  Label
</Link>
```

**Filter pill ativa/inativa:**

```tsx
// Ativa
"shrink-0 rounded-full bg-primary px-4 py-1.5 text-[12px] font-bold text-primary-foreground"

// Inativa
"shrink-0 rounded-full bg-card px-4 py-1.5 text-[12px] font-bold text-muted-foreground ring-1 ring-border transition-colors hover:text-foreground"
```

### 4.5 Pill / Badge

Sempre `rounded-full`, sempre uppercase tracking-wider para status:

```tsx
// Status lime (palpite aberto, etc)
<span className="inline-flex items-center gap-1.5 rounded-full bg-primary/15 px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-primary">
  <span className="size-1.5 rounded-full bg-primary" aria-hidden />
  Aberto
</span>

// Status sólido (Você)
<span className="rounded-full bg-primary px-2 py-0.5 text-[9px] font-black uppercase tracking-wider text-primary-foreground">
  Você
</span>

// Neutral
<span className="rounded-full bg-muted px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-muted-foreground">
  Label
</span>
```

### 4.6 Input (DarkInput)

Não use shadcn `<Input>`. Use o pattern dark:

```tsx
<input
  className="block w-full rounded-2xl bg-card px-4 py-3.5 text-[14px] font-medium text-foreground placeholder:text-muted-foreground/70 ring-1 ring-border transition-colors focus:outline-none focus:ring-2 focus:ring-primary"
/>
```

**Label:**

```tsx
<label className="block text-[11px] font-bold uppercase tracking-wider text-muted-foreground">
  Email
</label>
```

### 4.7 Avatar / Flag chip

**Avatar com iniciais (Perfil hero, Liga RankRow, Estatísticas):**

```tsx
<span className="inline-flex size-10 items-center justify-center rounded-full bg-muted text-[13px] font-black text-foreground" aria-hidden>
  IA
</span>

// Variante destacada
<span className="inline-flex size-20 items-center justify-center rounded-3xl bg-primary text-[28px] font-black text-primary-foreground shadow-xl shadow-primary/30" aria-hidden>
  IA
</span>
```

**Flag chip circular** (usa `flag-icons` + `.fis` squared variant):

```tsx
<span
  className="relative inline-flex size-7 shrink-0 overflow-hidden rounded-full ring-2 ring-border"
  aria-hidden
>
  <span
    className={`fi fi-${iso} fis`}
    style={{ width: "100%", height: "100%", fontSize: "28px", lineHeight: "28px" }}
  />
</span>
```

Use o helper `toIso2(country_code)` de `src/lib/country-codes.ts` pra converter FIFA 3-letter → ISO 2-letter.

### 4.8 Icon-mark dentro de card

Pattern: chip pequeno com ícone Phosphor.

```tsx
// Lime
<span className="inline-flex size-9 items-center justify-center rounded-xl bg-primary/15 text-primary">
  <TargetIcon className="size-4" weight="fill" aria-hidden />
</span>

// Neutral
<span className="inline-flex size-9 items-center justify-center rounded-xl bg-muted text-foreground">
  <SoccerBallIcon className="size-4" weight="fill" aria-hidden />
</span>

// Sólido lime (chip CTA)
<span className="inline-flex size-10 items-center justify-center rounded-2xl bg-primary text-primary-foreground shadow-lg shadow-primary/20">
  <PackageIcon className="size-5" weight="fill" aria-hidden />
</span>
```

**Decoração de fundo** (ícone gigante translucent atrás do conteúdo):

```tsx
<Icon
  className="absolute -right-4 -bottom-4 size-24 text-primary/10"
  weight="duotone"
  aria-hidden
/>
```

---

## 5. Ícones

Use **`@phosphor-icons/react`**. Lucide está banida (foi removida quando migramos).

**Import:**

```tsx
// Server components / Server Component-safe (default)
import { ArrowRightIcon, FireIcon, type Icon } from "@phosphor-icons/react/dist/ssr";

// Client components (qualquer um, mas SSR é compatível com tudo)
import { ArrowRightIcon } from "@phosphor-icons/react";
```

**Naming convention:** o suffix `Icon` é o nome canônico do Phosphor v2 (ex: `ArrowRightIcon`, não `ArrowRight`). Sempre use o suffix.

**Weights:**
- `fill`, padrão para ícones em status pills, badges, CTAs (sólido)
- `regular`, texto inline, navegação muda
- `duotone`, decoração de fundo, ícones grandes muted
- `bold`, setinhas (Caret, Arrow) e ações

**Tamanhos:**
- Inline em texto: `size-3` ou `size-3.5`
- Em chips/badges: `size-4` ou `size-5`
- Em ícone-mark cards: `size-5` ou `size-7`
- Decoração de fundo: `size-20` até `size-32`

---

## 6. Layout

### 6.1 Padrão de página

```tsx
<div className="flex flex-col gap-5 px-4 pb-6 pt-4">
  {/* Sections com gap-5 entre elas */}
</div>
```

Mobile-first. Largura máxima implícita pelo container do `(app)/layout.tsx`. **Não use `max-w-7xl`** ou containers fluidos, o app é mobile, design vai assim.

### 6.2 Hierarquia visual de sections

1. **Hero card.** Primeiro, com glow + decoração + CTA forte
2. **Stats / métricas.** Segundo, dá contexto do estado do usuário
3. **Listas funcionais.** Terceiro (jogos, eventos)
4. **Quick actions.** Último, 2-up com tratamentos distintos

### 6.3 Sticky elements

**Bottom nav** (`src/components/app/bottom-nav.tsx`): sticky bottom, `bg-card/95 backdrop-blur`, respeita `env(safe-area-inset-bottom)`.

**App header** (`src/components/app/app-header.tsx`): sticky top, `bg-background/85 backdrop-blur`, max altura 64px.

**Sticky CTA** (palpite-form, etc): `sticky bottom-16` com gradient fade-out da página:

```tsx
<div className="sticky bottom-16 z-30 -mt-20 px-4 pb-4 pt-6 bg-gradient-to-t from-background via-background to-transparent">
  <button className="...CTA pill...">Salvar</button>
</div>
```

---

## 7. Anti-Slop Checklist

Antes de commit, valide:

- [ ] **Zero em-dashes (`—`)** em qualquer lugar visível (headlines, body, pills, buttons, alt text). Use `.` ou `,`.
- [ ] **Um único accent color (lime)**. Não introduziu azul/vermelho/amarelo aleatório.
- [ ] **Hierarquia de shape consistente:** botões CTA pill, cards rounded-2xl/3xl, badges pill. Sem mixing sharp/soft.
- [ ] **Cards não são todos idênticos.** Se tem 4 stats, varie o micro-visual (sparkline, bars, ring, progress). Se tem N jogos, primeiro pode ser `featured`.
- [ ] **Cada card revela sua função visualmente** (sparkline pra trending, ring pra completion, mini-bars pra timeline, social proof pra game).
- [ ] **Sem fake screenshots div-based** simulando UI. Use foto real (picsum), ícone, ou tipo.
- [ ] **Sem decorative dots** em listas ou nav (só pra status semântico real).
- [ ] **Sem version label** nos heroes ("v0.6", "BETA", "NOVO") a menos que seja launch real.
- [ ] **Sem section-numbering eyebrows** ("01 / FEATURES", "02 / SOCIAL").
- [ ] **Hero stack ≤ 4 elementos** (eyebrow, headline, subtext, CTA).
- [ ] **Máximo 1 eyebrow a cada 3 sections.**
- [ ] **Real image se houver hero visual.** Picsum-seed determinístico (`picsum.photos/seed/<key>/...`).
- [ ] **Phosphor icons,** não Lucide, não SVG hand-rolled.
- [ ] **Tabular nums (`tabular-nums`)** em qualquer número métrico.
- [ ] **Reduced motion respeitado** via `motion-safe:` prefix em todo transform/scale.
- [ ] **Contraste WCAG AA** mínimo: texto sobre lime tem `text-primary-foreground` (near-black), texto muted sobre dark passa em 4.5:1.
- [ ] **Passe de subtração feito.** Elemento por elemento, "preciso disso?". Cópia extra, divisória, ícone decorativo, badge, card que só preenche grade. Removeu zero = justifique.
- [ ] **Os seis estados da seção 2** conferidos no `/showcase`, não só o happy path.

---

## 8. Como criar uma nova tela

1. **Identifique o pattern dominante:** é hero + lista? hero + form? lista pura? dashboard de stats?
2. **Reuse o esqueleto** do `src/app/(app)/inicio/page.tsx` ou `palpites/jogos/page.tsx` como ponto de partida.
3. **Hero card primeiro:** copie o pattern da seção 4.1.
4. **Sections com gap-5** entre si. Headers de section são `h2 className="text-[22px] font-black tracking-tight"`.
5. **Cards de lista:** use `JogoCard` se for jogo, ou crie um por extensão do mesmo padrão (`group block rounded-3xl bg-card ring-1 ring-border transition-all...`).
6. **CTAs sempre pill lime.** Secundários são pill ring border.
7. **Antes do PR, rode o checklist da seção 7.**

### Smoke test rápido

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/sua-nova-rota
```

Deve retornar `200`. Olhe `tail -30` do log do dev server pra confirmar zero `⨯ Error`.

---

## 9. Como criar um componente novo

### Showcase primeiro

Componente novo nasce em `/showcase`, nunca direto na tela real. Monte lá com dado fake e
os seis estados obrigatórios da seção 2 visíveis lado a lado. Isolado ele é manipulável e
comparável; dentro da tela, cada ajuste arrasta regra de negócio e custa mais.

```tsx
// src/app/showcase/page.tsx, uma section por componente
<ShowcaseSection title="JogoCard">
  <JogoCard {...mockJogo} />
  <JogoCard {...mockJogo} timeCasa="Bósnia e Herzegovina" />   {/* texto longo */}
  <JogoCardSkeleton />                                          {/* carregando */}
  <JogoCardEmpty />                                             {/* vazio */}
</ShowcaseSection>
```

Só depois de aprovado no showcase o componente entra na tela.

### Quando criar um componente vs inline

- **Inline:** uso único, < 50 linhas, sem props complexas. Mantém o page.tsx legível.
- **Componente em `src/components/app/<nome>.tsx`:** reusado em ≥ 2 telas, ou ≥ 80 linhas isolado.

### Estrutura de arquivo padrão

```tsx
// src/components/app/meu-card.tsx
import { ArrowRightIcon } from "@phosphor-icons/react/dist/ssr";
import Link from "next/link";

type MeuCardProps = {
  href: string;
  title: string;
  subtitle?: string;
  variant?: "default" | "featured";
};

export function MeuCard({ href, title, subtitle, variant = "default" }: MeuCardProps) {
  return (
    <Link
      href={href}
      className="group block rounded-3xl bg-card p-4 ring-1 ring-border transition-all motion-safe:hover:-translate-y-0.5 motion-safe:hover:ring-primary/40 motion-safe:active:translate-y-0 motion-safe:active:scale-[0.995]"
    >
      {/* ... */}
    </Link>
  );
}
```

**Princípios:**
- Server component por padrão. Adicione `"use client"` SOMENTE se usar hooks (useState, useEffect, etc).
- Props tipadas explicitamente.
- Variantes via prop `variant`, NÃO via multiple components separados (a menos que sejam genuinamente diferentes).
- Aria-hidden em todos os ícones decorativos.
- Use tokens (`bg-card`, `text-foreground`, etc), nunca hex direto.

### Componentes compartilhados atuais

| Arquivo | Função |
|---|---|
| `src/components/app/jogo-card.tsx` | Card de jogo (compact + featured) |
| `src/components/app/palpite-form.tsx` | Form de palpite (stepper, Pergunta Plus, sticky CTA) |
| `src/components/app/app-header.tsx` | Header com grupo chip + sino notif |
| `src/components/app/bottom-nav.tsx` | Tab bar 5-aba |
| `src/components/app/sub-nav.tsx` | Sub-tabs (Liga/Estatísticas, Jogos/Torneio/Histórico) |
| `src/components/app/placeholder.tsx` | Placeholder pra rotas ainda não implementadas |
| `src/components/pre-auth/onboarding-step.tsx` | Step de boas-vindas |

### Helpers utilitários

| Arquivo | Função |
|---|---|
| `src/lib/country-codes.ts` | `toIso2(FIFA code)` → ISO alpha-2 pro flag-icons |
| `src/lib/labels.ts` | `FASE_LABEL`, `FASE_LABEL_CURTO`, `MULTIPLICADOR_FASE` |
| `src/lib/data/jogos.ts` | Server-side data fetcher do Supabase cache |
| `src/lib/utils.ts` | `cn()` helper do shadcn |

---

## 10. Tooling

### Stack

- **Next.js 16** (App Router + RSC)
- **Tailwind v4** com `@theme inline` em globals.css
- **Geist + Geist Mono** via `next/font/google`
- **Phosphor Icons React v2** (`@phosphor-icons/react`)
- **flag-icons** (`fi fi-XX fis` para circular flags)
- **shadcn/ui Nova preset** (base, mas a maioria dos componentes foi customizada)
- **sonner** (toasts)

### Setup local

```bash
pnpm dev          # localhost:3000
pnpm lint
pnpm build        # smoke check antes de PR
```

### Quando adicionar dependência nova

Antes de `pnpm add <pacote>`:

1. **Cheque se Phosphor / Tailwind / Geist já cobre.** 90% das vezes cobre.
2. **Se for animação complexa**, use `motion/react` (não framer-motion legacy). Evite GSAP a menos que seja scroll-pinning real.
3. **Se for um component lib novo**, prefira shadcn/ui add (`pnpm dlx shadcn@latest add ...`), tem código próprio que você customiza.

---

## 11. O que NÃO fazer (lista negra do AI slop)

- ❌ `bg-gradient-to-br from-purple-500 to-pink-500`. AI gradient slop
- ❌ Inter como fonte default, banido
- ❌ Fraunces / Instrument Serif, banido
- ❌ Cream paper backgrounds (`#f5f1ea`, `#faf7f1`, etc), banido (era do skill premium-consumer ban)
- ❌ Drop shadow preto puro, use `shadow-primary/20` ou neutrals tintados
- ❌ "3 cards iguais lado a lado", sempre diferencie pelo menos um (size, content, treatment)
- ❌ Em-dash (`—`) em qualquer texto visível, `.`, `,` ou `:` no lugar
- ❌ Eyebrow em toda section, máximo 1 a cada 3
- ❌ Section numbering ("01 / FOO"), banido
- ❌ Logo wall genérico no hero ("Used by"), só sob a hero como section separada
- ❌ Pillar count rule violado: bento N items ≠ N cells
- ❌ Lucide icons, migramos pra Phosphor
- ❌ Light mode no MVP, dark locked

