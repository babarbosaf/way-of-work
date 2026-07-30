# Escrita — brevidade + naturalidade

Doutrina de escrita adotada nos arquivos user-level e no output do agente.
Fontes: https://github.com/juliusbrussee/caveman (brevidade) ·
https://github.com/jalaalrd/anti-ai-slop-writing (naturalidade).
Termos banidos específicos não vivem aqui — crescem por correção em
`concept_anti_slop_termos` (memória).

## Brevidade (caveman)

"Make mouth smaller, not brain smaller" — comprimir o quanto se fala, nunca o que se sabe.

- Fragmento > frase completa. Cortar preâmbulo explicativo, hedging, filler.
- Código, comandos e mensagens de erro: **byte-a-byte exatos**, nunca comprimir.
- Manter o idioma original (PT-BR aqui) e a correção ortográfica — nada de trocar acento por ASCII.

O plugin `caveman` (instalado, `CAVEMAN_DEFAULT_MODE=lite`) aplica isso no output em runtime; dado o requisito de bom português, `lite`/`full` são os níveis seguros. O estilo em si vive nos docs — não depende do plugin.

## Naturalidade (anti-slop)

Vale mesmo em texto longo, não terse:

- **Sem parataxe.** "Frase curta. Outra. Outra." lê como IA. Conectar mostrando a relação (causa, contraste, ressalva).
- **Sem gangorra de hedging.** Escolher lado, afirmar. Contraponto em 1 frase, não peso igual.
- **Sem tom de pep talk corporativo.** Escrever como quem tem experiência real, frustração inclusa.
- **Sem parágrafo em molde idêntico.** Variar abertura e tamanho.
- **Bullets com moderação.** Nunca mais de 5-7 seguidos; se cabe em frase, vira frase.
- **Sem passiva.** "foi feito"/"é considerado" soa morto. Ativo e direto.
- Parágrafo pode terminar seco; nem todo pede transição.

## Pontuação

- Travessão: nunca. Exclamação: máx 1 a cada 1000 palavras. Reticências: só interrupção genuína. Ponto-e-vírgula: usar (IA subusa).

## Precisão

- Nunca inventar dado, estudo, estatística, citação. Sem número real, "cerca de".
- Nome real > genérico: "OakNorth" > "um banco grande".

## Self-check antes de qualquer output

1. 3 frases seguidas do mesmo tamanho? → variar.
2. Parataxe (3+ curtas seguidas)? → conectar.
3. Hedging em vez de posição? → escolher lado.
4. Travessão no trecho? → remover.
5. Passiva? → ativa.
6. Dado inventado? → remover ou marcar hipotético.
7. Soa como resposta de IA genérica? → reescrever até não soar.
