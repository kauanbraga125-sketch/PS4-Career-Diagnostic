# Noite da Horda — Android alpha 0.1

Nova base 2D para Kauan, independente do Porto Livre e do plugin FIFA/PS4. Corrida lateral com recrutamento de criaturas, transformações temporárias, moedas e melhorias permanentes. Arte cartoon criada para este jogo.

## Primeira versão

- Menu animado, loja com quatro melhorias ilustradas, catálogo de monstros, ajuda, pausa e resultado.
- Zumbi e esqueleto coletáveis, até doze integrantes. Os sprites têm espera, quatro poses de corrida e salto, com transparência real.
- Cristal violeta: transforma toda a horda em moscas mutantes que flutuam sobre buracos e atravessam perigos. Máscara: transforma o grupo em mascarados que destroem obstáculos. As criaturas coletadas voltam ao normal após o bônus.
- Salto com altura conforme o tempo de toque, salto duplo a partir do nível 2 de Pulo Ágil, caixas, carros, espinhos e buracos. Carros podem ser destruídos com cinco integrantes.
- Quatro compras: primeira horda (50 moedas × próximo nível), pulo (65), ímã (70), metamorfose (80); cada uma até o nível 3. Carteira inicial: 120 moedas. Não há anúncios, pagamento real ou compras de dinheiro.
- Moedas ficam na carteira mesmo ao perder. Três desafios dão recompensas únicas; recorde, compras, carteira e preferência de som são salvos localmente com backup.
- Duas músicas originais de sintetizador e onze efeitos de pulo, moeda, recrutamento, transformação, compra, aterrissagem e impactos. Tudo funciona offline.

## Jogar

Celular em paisagem. Toque em qualquer lugar da pista, ou no botão PULAR, para saltar; segure para pular mais alto. Ao comprar Pulo Ágil nível 2, toque outra vez no ar. O botão II pausa. O menu SOM liga/desliga música e efeitos. No computador, espaço pula e Esc pausa.

Esta versão inclui quatro criaturas; Michael Myers e outros personagens citados no conceito ainda não foram adicionados. O mascarado tem inspiração visual no terror clássico; os nomes de franquias não são usados como título do jogo. O mapa inicial é um cemitério com percurso contínuo, não uma campanha completa com vários cenários.

## Plataforma e validação

Godot 4.5.1, renderizador Compatibility, Android 7+ e OpenGL ES 3.0, ARMv7/ARM64. Meta de 60 FPS configurada; ainda não há benchmark em telefone físico. Texturas compartilhadas em atlas, horda limitada a doze sprites e limpeza de entidades/partículas.

```sh
godot --headless --path monster-game --editor --import
godot --headless --path monster-game -- --self-test
```

A suíte verifica compras e limites, moedas sem cobrança duplicada, recrutamento misto, salto/aterrissagem, transformações e retorno à forma original, travessia de buracos, morte/retry, desafios, pausa, save/backup e limites durante corrida prolongada. O workflow também renderiza imagens reais do jogo, exporta o APK e verifica sua assinatura v2/v3 e SHA-256.

Build: `.github/workflows/noite-da-horda-android.yml`, branch `game/monster-rush-android`. APK de desenvolvimento assinado; chave mantida em cache de CI. O vencimento do cache pode exigir reinstalação. Pacote Android `com.kauan.noitedahorda`, separado do Porto Livre.

## Arte e som

Consulte [ASSETS.md](ASSETS.md). Todos os recursos já estão no repositório; a compilação não precisa gerar arte novamente. `prepare_art.py` lê limites de transparência para criar regiões de atlas; não modifica as imagens. `compose_audio.py` reproduz as composições originais usando NumPy e FFmpeg.
