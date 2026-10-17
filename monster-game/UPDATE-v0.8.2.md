# Noite da Horda 0.8.2

O mercado usa a referência aprovada: letreiro ilustrado, quatro melhorias
visíveis em uma grade de duas colunas, ícones maiores, descrição do benefício,
nível com cristais e botão de compra com preço. Monstros, Poderes e Cenários
seguem o mesmo acabamento; os poderes têm rolagem por toque.

## Correções

- As áreas de toque dos produtos são registradas pelo mesmo desenho principal
  que limpa e registra os demais controles. O desenho dos cartões no painel
  recortado não altera essa lista. Isso corrige a perda dos controles a cada
  quadro, que impedia abrir detalhes e comprar no mercado anterior.
- Compras são confirmadas ao soltar o toque no botão inicial. Arrastar cancela
  a compra e permite rolar; um segundo dedo não assume o toque ativo. Botões
  fora do recorte, bloqueados e já completos não aceitam compras.
- IDs numéricos de monstros e poderes são convertidos para inteiros ao ler o
  JSON. Antes, `1 in [1.0]` falhava e um desbloqueio comprado podia desaparecer
  ao reabrir o jogo. Valores de moedas e melhorias existentes são preservados.
- Metamorfose aparece entre as quatro melhorias e aplica os dois segundos
  adicionais por nível, somados às melhorias específicas de Fly e Mascarado.

## Arte e validação

`assets/art/market-art-v82.png` é um atlas RGBA original gerado a partir da
referência, com letreiro, tênis, ímã, poção e igreja. O arquivo foi copiado sem
edição de pixels; os recortes são AtlasTexture no motor. Os retratos reutilizam
o zumbi aprovado. Textos, valores, estado dos botões e animações são independentes.

`tools/market_v82_check.gd` testa a tela renderizada em três proporções, compras
por eventos de toque atravessando vários quadros, débitos, limites, saldo
insuficiente, múltiplos dedos, desbloqueios das quatro categorias, rolagem sem
compra acidental, salvamento e recarga, duração dos poderes, retorno ao menu e
entrada na corrida. A checagem não substitui o teste no aparelho físico.

Pacote Local `com.kauan.noitedahorda.local`, versão 0.8.2, código 20, ARMv7 e
ARM64. A compilação usa o APK 0.8.1 e sua mesma chave. A opção de sobrepor
recursos de `tools/rebuild_android.py` conserva os demais arquivos originais,
incluindo arte, animação aprovada, áudios e bibliotecas nativas.
