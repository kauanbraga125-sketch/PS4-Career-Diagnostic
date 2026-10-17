# Horda Zumbi — Melhorias de sprites para atualização posterior

Este arquivo documenta os pedidos gráficos do usuário, mas **não devem ser implementados na rodada de programação descrita no prompt principal**. A ideia é fazer as folhas de animação separadamente, revisar visualmente, corrigir quadros e só então integrá-las ao APK.

## Personagens e NPCs
1. Corrigir sprites de **todos os NPCs**, tanto os que aparecem no fundo/backstage quanto os civis que capturamos. Existem quadros com membros deformados, ausentes ou inconsistentes.
2. Usar a nova animação de corrida do zumbi (a que já foi criada e revisada anteriormente) como **referência de qualidade e fluidez**, não como instrução para substituir estilos de todos os NPCs sem avaliação.
3. Revisar proporções, continuidade entre quadros, braços, pernas, cabelo e acessórios para evitar troca de lado, resíduos de recorte ou teletransporte de membros.
4. Atualizar a animação e o enquadramento do **motorista da moto**.
5. Criar NPCs animados **dentro dos carros**: passageiros ou motorista reagindo e gritando “HELP!”, coerentes com o tamanho dos veículos e visíveis pelas janelas.
6. Criar **animação diferenciada para a captura/conversão de civis**, além do efeito de programação (ex.: susto, contato com a horda e transformação curta) sem bloquear fluidez da corrida.
7. Dar vida ao zumbi com **piscadas, abertura de boca, expressão cômica variável**, camiseta e shorts reagindo ao movimento/vento. Manter pés fixos e ritmo do ciclo de corrida; não criar quadros com alterações bruscas entre frames.
8. Se for redesenhar NPCs do zero, primeiro gerar folhas inteiras coerentes (sem sprites divididos em blocos quando isso produzir artefatos), exibir prévias e validar com o usuário antes de integrar.

## Menu inicial e visuais
- O efeito de boneco flutuando no menu inicial **já foi corrigido**; preservar.
- É possível melhorar posteriormente a composição do menu, mas não mexer nesta rodada sem solicitação adicional.
- O mercado que não permitia clicar/comprar **já foi corrigido**; preservar.

## Processo para próxima rodada
Gerar folhas de sprites > revisar continuidade > eliminar resíduos > conferir acessórios e alinhamento > validar visualmente > implementar e testar em jogo > compilar APK.
