# Noite da Horda 0.7.0

Base: versão Local 0.6 recuperada, preservando as três músicas, sons anteriores e migração do save 6. APK Local: com.kauan.noitedahorda.local, versionCode 8, mesma assinatura da versão anterior. A chave privada não faz parte do repositório.

## Mudanças combinadas

- Salto em ondinha por posição no mundo e fila por integrante. Basta o líder aterrissar para aceitar o próximo salto. Soltar acaba com a sustentação da onda; seguidores que começam depois disso fazem o salto curto normal. Outra pressão não sustenta uma onda antiga. Salto duplo comprado preservado.
- Corrigidos pivôs e sobreposições de cabeça, pescoço, braços e pernas nas poses de corrida, salto, captura e menu.
- Veículos permanecem sólidos até serem virados. Salto parcial não libera caminhão; a câmera avança, integrantes bloqueados ficam para trás e perder o último encerra a corrida.
- Carros em sentido contrário desde antes do primeiro túnel, esporádicos, com buzina e antecipação, evitando surgimento sobre buracos.
- Buracos curtos/longos, sequências de até três, plataformas intermediárias e morrinhos. Dimensões acompanham a velocidade e não exigem salto duplo ainda não comprado.
- Civis menos frequentes. Até o túnel 2, orçamento de 30 almas, raramente 34 (aproximadamente uma semente em 29), incluindo NPCs pendentes e passageiros. Toda captura visível continua dando uma alma; não se cortam recompensas na conversão.
- Um candidato a balão a cada 15 NPCs. Balão pequeno no personagem e com duração limitada; removida a grande caixa no HUD.
- Moedas aumentadas de 33 para 45 unidades, conservando espessura e rotação.
- Menu inicial mostra zumbi e Mosca disponíveis, sem oferta de Mascarado sobre os personagens. Compras anteriores preservadas.
- Mercado em lista vertical contínua com arrasto, roda do mouse, barra de rolagem e recorte. Categorias, cabeçalho e Voltar fixos; detalhes e compras reais.
- Coleção com cartões individuais e personagem selecionado grande e animado. Poderes separados e estado real de desbloqueio.
- Missões com trio de cartões, ícones adequados, progresso e recompensas. Pausa com missões à esquerda e Continuar dourado. Mundo e enquadramento congelados enquanto a interface anima; comparação de pixels verifica o cenário parado e as almas em movimento.
- Resultados: “A horda caiu. As almas permanecem.”, frasco à esquerda, quatro estatísticas à direita, ritual e ações. Nível e progresso juntos; crédito de recompensas continua sendo liquidado uma única vez.
- Frasco com **61 sprites de enchimento**, de 0 a 100%, em atlas. A animação parte do progresso anterior, mostra o estado cheio ao subir de nível e conserva excedentes. Fluxo sonoro apenas durante enchimento.
- **12 poses novas**: quatro tentativas de fuga no carro, quatro poses no ônibus e quatro poses exclusivas do motoqueiro. Passageiros maiores, diferentes fases e tipos alternados no ônibus. Recortes medidos para não mostrar partes de outro quadro.
- Configurações preservam os três volumes e compartilham tipografia, bordas e famílias sonoras com o restante.

## Som

60 MP3 originais preservados no pacote recebido. Foram feitas 60 cópias OGG independentes com filtros, compressão suave, normalização e limitação de picos. Nomes completos, hashes, eventos, variantes e medições: `assets/audio/v7/manifest.json`.

Variações alternam com limite de repetição; não se empilham. Comemoração combina uma guitarra VIT_01 com **uma** multidão VIT_02, em volumes diferentes. Confirmar/selecionar, voltar, comprar e negar têm famílias próprias. Passos normais/pesados, pousos, salto, conversão, baixa, queda, impacto, moeda, alma, poder, término e frasco têm seus eventos.

Um motor próximo, um fluxo de frasco, um loop de passos por tipo. Ambientes usam crossfade. Música reduz sob eventos importantes; canais de música/efeitos/vozes independentes e limitador final.

**Pendente conforme o TXT enviado:** AMB_01 (1 arquivo), AMB_02 (4) e AMB_03 (2) exigem identificação por escuta. Esses sete arquivos foram tratados e catalogados, sem atribuição definitiva de cenário. AMB_00 apoia a cidade e AMB_04 os túneis. Não se afirma que indústria e aeroporto tenham novos ambientes próprios confirmados.

## Verificação e reprodução

545 verificações automatizadas: progressão, economia, migração, pagamentos únicos, captura, buracos, colisões, câmera, salto a 30/60/120 fps, ondas, soltura, orçamento de almas, balões e carga dos 60 clipes. Capturas reais em 16:9, telefone largo e tablet; arrasto e mundo parado na pausa. Desempenho em celular físico ainda não foi medido.

Godot 4.5.1: importar e executar `--self-test`. `--v7-preview` captura as telas; `tools/bake_jar.gd` recompõe 61 estados. `HORDE_AUDIO_SOURCE` aponta aos originais para `tools/prepare_audio_v7.py`. O relatório do APK verifica pacote, versão, assinatura anterior, integridade, alinhamento, artes/sons e ausência de permissão de internet.
