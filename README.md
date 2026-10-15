# Horda Zumbi — Noite da Horda

Jogo de corrida 2D para Android, feito com Godot 4.5.1.

**[Baixar Noite da Horda 0.7.0](https://github.com/kauanbraga125-sketch/horda-zumbi/releases/tag/noite-da-horda-v0.7.0)** · [Código do jogo](monster-game) · [Mudanças da versão](monster-game/UPDATE-v0.7.md)

O APK, as imagens e o código desta versão ficam publicados no GitHub. A release é um download permanente, separado dos arquivos temporários das compilações.

## Jogar no Android

Na página da versão, baixe **NoiteDaHorda-v0.7.0.apk**. Quem já usa a edição Local deve instalar por cima, sem desinstalar, para manter o progresso. A versão publicada preserva o pacote `com.kauan.noitedahorda.local` e a assinatura da edição Local anterior.

![Menu da versão 0.7](https://github.com/kauanbraga125-sketch/horda-zumbi/releases/download/noite-da-horda-v0.7.0/NoiteDaHorda-v0.7.0-menu.png)

## Código e compilação

O projeto está em [monster-game](monster-game). Abra `monster-game/project.godot` com Godot 4.5.1.

```sh
godot --headless --path monster-game --editor --import
godot --headless --path monster-game -- --self-test
godot --path monster-game
```

O [workflow Android](.github/workflows/noite-da-horda-android.yml) executa testes, gera capturas e compila o APK no GitHub Actions. Ele roda em alterações do jogo na branch `main` e nas branches de desenvolvimento indicadas no workflow.

A compilação de desenvolvimento do Actions usa `com.kauan.noitedahorda`; o APK compatível com as instalações Local usa `com.kauan.noitedahorda.local` e a chave Local correspondente. As chaves privadas de assinatura não fazem parte do repositório público.

## Documentação

- [Projeto Android](monster-game/README.md)
- [Atualização 0.7 e verificações](monster-game/UPDATE-v0.7.md)
- [Arte, áudio e créditos](monster-game/ASSETS.md)
- [Documentação anterior do CareerTrace](docs/CareerTrace-v2110.md)
