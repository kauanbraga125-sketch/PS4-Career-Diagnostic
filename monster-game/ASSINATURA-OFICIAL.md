# Noite da Horda — lançamento oficial Android

O código oficial fica na branch `main`. O workflow de publicação é
[`.github/workflows/noite-da-horda-release.yml`](../../.github/workflows/noite-da-horda-release.yml).

## Por que esta configuração funciona

O Android identifica atualizações pelo **package name**, **certificado de assinatura** e
`version/code`. O pacote oficial permanente é `com.kauan.noitedahorda`.
A primeira instalação oficial terá `version/name=0.8.13` e `version/code=31`.
Nas versões futuras altere **ambos** no `monster-game/export_presets.cfg`, mantenha
o mesmo pacote e reutilize exatamente a mesma chave de assinatura.

## 1. Gere uma chave permanente *no seu computador* (uma única vez)

Instale um JDK (o projeto usa JDK 17) e, em uma pasta privada no Windows, execute:

```powershell
keytool -genkeypair -v -keystore noite-da-horda-release.jks -alias horda -keyalg RSA -keysize 3072 -validity 10000
```

Escolha uma senha forte e guarde-a num gerenciador de senhas. A senha da chave deve ser
igual à senha do keystore para o exportador Android do Godot. Anote o alias `horda`.
**Mantenha uma segunda cópia segura do arquivo `.jks` fora do GitHub.**
Se perder a chave, os aparelhos que instalaram a versão oficial podem deixar de aceitar
atualizações assinadas por uma chave diferente.

## 2. Configure os GitHub Actions Secrets

No repositório, abra **Settings > Secrets and variables > Actions > New repository secret**
e cadastre:

- `HORDA_SIGNING_KEYSTORE_B64`: todo o conteúdo Base64 do arquivo `.jks`.
  No PowerShell:
  ```powershell
  [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path .\noite-da-horda-release.jks)))
  ```
  Copie a saída somente para o campo Secret do GitHub, nunca para um arquivo público ou chat.
- `HORDA_SIGNING_ALIAS`: `horda` (ou o alias efetivamente usado).
- `HORDA_SIGNING_PASSWORD`: a senha privada.

Base64 **não é criptografia**: somente o GitHub Secret protege o conteúdo.
Nunca faça commit do keystore, do Base64 ou da senha no repositório.

## 3. Publique a primeira versão oficial

Depois de cadastrar os três segredos, abra **Actions > Noite da Horda Android —
lançamento oficial > Run workflow** e selecione **main**.

O workflow:
1. Importa e testa o jogo no Godot 4.5.1.
2. Interrompe o processo se os segredos estiverem ausentes ou a assinatura falhar.
3. Compila com `--export-release` e a chave armazenada nos Secrets.
4. Verifica assinatura, pacote, versão e SHA256.
5. Publica o APK na aba **Releases**, com tag `v0.8.13`, e mantém um artefato temporário de 90 dias.

**Não clique para publicar antes de configurar os Secrets:** a compilação oficial
será bloqueada de propósito.

## Atenção ao progresso existente

A v0.8.12/0.8.13 de teste foi compilada com identificadores e chaves diferentes.
O APK oficial não tem garantia de sobrescrever essas instalações nem de acessar seus
dados privados. **Não desinstale a versão com seu progresso** antes de salvá-lo.

O novo sistema de backup via área de transferência existe na v0.8.13, mas não na
v0.8.12 antiga. Uma migração do jogo antigo exige procedimento separado.

## Próximas versões

A assinatura é a **mesma chave**, não uma chave nova a cada build. Alterne somente os
números `version/name` e `version/code`, atualize as notas da release e execute o
workflow de novo. O usuário poderá instalar o APK novo por cima do oficial anterior
sem perder o progresso, desde que a assinatura e o pacote continuem idênticos.
