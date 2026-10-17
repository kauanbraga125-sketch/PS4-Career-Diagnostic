# Noite da Horda 0.7.1 — articulação do zumbi

O zumbi usa uma hierarquia de Skeleton2D/Bone2D, com quadril, tronco, cabeça e cadeias distintas para os braços e as pernas direitos e esquerdos. O menu, a coleção e a partida usam o mesmo personagem.

- Os ombros acompanham a inclinação do tronco; cotovelos, punhos, joelhos e tornozelos acompanham seus respectivos ossos pais.
- Cada recorte tem pontos de encaixe medidos, em vez de um pivô genérico para todas as peças. A escala dos membros preserva suas proporções.
- A camisa acompanha o tronco e o short acompanha o quadril, cobrindo o início das coxas. Recortes dos membros foram limpos para eliminar anéis de corte e roupa duplicada.
- O lado mais distante fica atrás do corpo, com sombreado discreto. Braços e pernas mantêm sua identidade durante os movimentos.
- O esqueleto permanece na árvore da cena para que o movimento de um osso invalide corretamente as posições de todos os seus filhos. Um único esqueleto reutilizável calcula as poses; não são criados novos nós a cada quadro.
- O apoio do pé, a articulação durante o salto e a independência entre as poses de diferentes integrantes têm verificações próprias.

A física do salto em ondas, os obstáculos, a economia, os sons e os menus da versão 0.7 não foram redesenhados nesta correção. O APK Local mantém o pacote e a chave anteriores, com versionCode 9 e versão 0.7.1.

Verificações: 1.021 verificações automatizadas passaram, incluindo os testes anteriores e a suíte anatômica `tests/zombie_rig_test.gd`. A análise dos pixels de 24 poses ampliadas confirmou uma única silhueta conectada em cada pose, sem membros visivelmente separados. Braços e pernas alternam em oposição durante a corrida. A revisão visual inclui o zumbi ampliado em oito poses, desenhos dos ossos e capturas reais do menu, corrida, salto e pouso. Desempenho em um telefone físico não foi medido nesta sessão.

Prévia isolada: `godot --path monster-game --script res://tests/rig_preview.gd`.
Prévia dentro do jogo: `godot --path monster-game -- --rig-preview`.

Arte complementar: `assets/art/rig-zombie-v71.png`; regiões medidas em `assets/art/zombie-rig-v71.json`; prompt e proveniência em `assets/art/rig-zombie-v71-source.json`. A cabeça, a camisa, o short e os pés originais foram preservados.
