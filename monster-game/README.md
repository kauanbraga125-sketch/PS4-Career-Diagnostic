# Noite da Horda — Android alpha 0.2

Corrida 2D de monstros para Kauan. Esta atualização concentra-se em movimento, efeitos, decisões durante a corrida e progressão. O projeto fica separado do Porto Livre e dos arquivos FIFA/PS4.

## Movimento e efeitos

- Os quatro monstros usam novas peças bitmap articuladas: pernas alternadas, joelhos conectados, balanço dos braços, corpo e cabeça, poses de subida/queda, compressão ao aterrissar e asas batendo. O pé de apoio permanece na linha do chão.
- Poeira animada nos passos, na saída do salto, na aterrissagem e nos impactos; brilhos, ondas de transformação, fragmentos, moedas voando até o contador e sombras que diminuem com a altura.
- Moedas giram; cristais, máscaras, escudos e poções flutuam, oscilam e têm luzes orbitando. Os bônus reagem à coleta.
- Frenesi e velocidade elevada deixam cópias que desaparecem e linhas de vento atrás da horda. Efeitos limitados a 240 partículas e oito cópias.
- Três camadas pintadas de parallax: colinas/castelo distante, vila/ponte e árvores/cemitério próximo. Chão em movimento, lanternas oscilando, brilho das luzes, grama, vaga-lumes e morcegos animados.

## Jogar

Android em paisagem. Toque na pista ou em PULAR; segure para saltar mais alto. Pulo Ágil nível 2 libera salto duplo. II pausa; SOM liga/desliga áudio. No computador, espaço e Esc.

- Zumbis e esqueletos encontrados na pista juntam-se à horda, até doze membros.
- Carro: quatro membros no chão conseguem virá-lo. O indicador muda de cor conforme a força disponível; o veículo tomba e libera um recruta e oito moedas. Com menos membros, pule por cima.
- Cristal: transforma o grupo em moscas. O botão vira SUBIR; segure para subir e solte para descer. Asas animadas, altura limitada à área de jogo e breve recuperação sobre buracos quando o bônus termina.
- Máscara: transforma o grupo em mascarados que quebram obstáculos.
- Poção: Frenesi de cinco segundos, velocidade 18% maior e moedas coletadas em dobro. Não concede invencibilidade.
- Salto dos seguidores usa posições do percurso, acompanhando o líder mesmo quando a velocidade muda. Percurso com nove tipos de trechos e recrutamento, obstáculos e moedas indicando trajetórias.

## Compras e missões

Carteira inicial: 120 moedas. Quatro melhorias permanentes, até três níveis: Primeira Horda (50 moedas × próximo nível), Pulo Ágil (65), Ímã de Moedas (70) e Metamorfose (80).

Só o visual de zumbi começa desbloqueado. Visuais do líder: esqueleto 240, mascarado 650 e mosca 950 moedas. Comprar equipa o visual; selecionar um comprado é grátis. Os visuais compartilham a física comum. Poderes especiais dependem dos bônus encontrados na pista, que podem ser experimentados antes da compra.

Três missões ativas por capítulo. Doze modelos de objetivos, incluindo virar carros, saltos seguros, formar horda, distância, moedas, transformações e frenesi. Ao completar o trio, novos objetivos aparecem. Quantidades aumentam após os quatro primeiros capítulos; progresso e recompensas são salvos.

Moedas ficam com você ao perder. Save local com escrita atômica e backup. Atualizações da alpha 0.1 preservam carteira, melhorias, recorde e recompensas já recebidas. Sem anúncios, pagamentos reais ou conexão obrigatória.

## Recursos e limites atuais

Quatro monstros, um tema de cemitério e duas músicas originais com onze efeitos sonoros offline. Outros personagens e regiões do conceito ainda não foram adicionados. Arte e prompts documentados em [ASSETS.md](ASSETS.md), [art-prompts.json](art-prompts.json) e [art-prompts-v2.json](art-prompts-v2.json).

Godot 4.5.1, Compatibility, Android 7+, OpenGL ES 3.0, ARMv7/ARM64. Meta de 60 FPS; desempenho em telefone físico ainda não foi medido. Pacote `com.kauan.noitedahorda`, versionCode 2. APK de desenvolvimento assinado com chave mantida no cache do workflow.

## Verificação

```sh
godot --headless --path monster-game --editor --import
godot --headless --path monster-game -- --self-test
```

Testes de conexões da animação, voo com toque, carros com três/quatro membros, frenesi, recrutamento, pulos e buracos, compras, missões renováveis, save/migração, pausa, morte/retry e limites de entidades/efeitos.

O workflow `.github/workflows/noite-da-horda-android.yml` renderiza capturas e um vídeo de 360 quadros do jogo real com entradas simuladas, exporta o APK e verifica assinatura v2/v3 e SHA-256. O vídeo de demonstração usa a música original e não é um benchmark de FPS.

`prepare_rigs.py` mede transparência e prepara regiões de atlas sem alterar os pixels gerados. `prepare_art.py` e `compose_audio.py` reproduzem os metadados da arte original e a síntese dos sons.
