03 [S]  A mensagem do bloqueio entrega o comando, não a lição

O que construir: os dois guards trocam "grep primeiro, depois Read com
offset+limit" por rota explícita por degrau, com comando colável. Entre
`grep_max` e `worker_min`, a rota é grep mais Read paginado. Acima de
`worker_min`, é o `delegate.sh --task scan --paths ... --question "..."`, com os
paths do próprio comando já preenchidos.

Motivo: lição 3 do Portal. Bloqueio que ensina a paginar reduz o pico e mantém
os tokens na janela cara. Bloqueio que roteia troca de janela.

files:      hooks/read_size_guard.py
blocked_by: 01, 02, 04
delega:     não
verify:     bash tests/hooks.test.sh

Aceite:
- [x] arquivo entre os dois degraus: mensagem cita grep e Read paginado
- [x] arquivo acima do `worker_min`: mensagem cita `delegate.sh --task scan`
- [x] o comando sugerido já traz o path real do arquivo bloqueado
- [x] os dois hooks usam a mesma função de mensagem (sem texto duplicado)
