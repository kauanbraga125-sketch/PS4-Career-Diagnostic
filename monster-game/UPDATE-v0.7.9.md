# Noite da Horda 0.7.9

O zumbi do menu usa 48 quadros inteiros: respiração, piscada, olhares para ambos os lados, sorriso e irritação. A paleta é ajustada por material ao primeiro quadro aprovado, com escala uniforme e apoio dos pés fixo. As expressões aparecem entre períodos de respiração e usam transições com mistura de alfa pré-multiplicado, evitando oscilações de opacidade.

O menu ganhou uma placa de título, botões separados com acabamento ameixa/dourado, ícones correspondentes à arte e destaque maior para Jogar. Texto, progresso, botões, caldeirão, almas e personagens continuam independentes e animados.

## Base e compatibilidade

O repositório estava em 0.7.1. Os scripts e recursos novos da 0.7.8 foram recuperados do APK Local fornecido pelo usuário antes de aplicar esta atualização. O renderizador de corrida desenhada da 0.7.8 e suas expressões/correções dos pés continuam ativos. Os recursos originais já presentes no repositório foram preservados.

O APK Local tem pacote `com.kauan.noitedahorda.local`, versionCode 17 e a mesma chave da versão 0.7.8. Nenhuma chave de assinatura está no repositório.

## Verificação

- Importação e compilação pelo Godot 4.5.1.
- Menu renderizado em três proporções; verificação de áreas de toque e de sobreposição.
- As seis ações, navegação dos botões e ocultação do personagem ao sair do menu.
- Inicialização da partida com o renderizador de sprites completos da 0.7.8.
- Integridade ZIP, scripts compilados, conteúdo do atlas e assinatura APK v2/v3.

O teste em aparelho Android físico ainda deve ser feito.

Para renderizar e verificar o menu, com display gráfico disponível:

```sh
HORDE_V79_OUTPUT=/caminho/para/capturas godot --path monster-game --audio-driver Dummy --script res://tools/menu_v79_check.gd
```

Para exportar os recursos e montar uma atualização usando um APK Local existente:

```sh
godot --headless --path monster-game --export-pack Android recursos.zip
GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$SENHA_DA_CHAVE" python monster-game/tools/rebuild_android.py \
  --template NoiteDaHorda-v0.7.8-local.apk --resources recursos.zip \
  --output NoiteDaHorda-v0.7.9-menu-local.apk --keystore "$CHAVE_LOCAL" \
  --signer-classpath '/caminho/apksigner/*'
```

O empacotador mantém as bibliotecas Android originais, atualiza o manifesto e substitui os recursos por arquivos exportados pelo Godot. A chave precisa ser fornecida separadamente.
