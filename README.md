 # PCSX2 + Parsec: instalação automática

Este programa prepara seu computador para jogar jogos de PlayStation 2 e transmitir o jogo para outro dispositivo pelo Parsec. Ele baixa e instala tudo sozinho. Você só precisa colar um comando.

## Como usar

**1. Abra o PowerShell como Administrador**
- Clique no menu Iniciar e digite `PowerShell`.
- Clique com o botão direito em "Windows PowerShell" e escolha **Executar como administrador**.

**2. Cole este comando e aperte Enter**


```powershell
irm https://raw.githubusercontent.com/void75028-max/parsautona2/main/pcsx2-nightly.ps1 | iex
```

**3. Espere terminar**
Quando aparecer "Instalação concluída!", abra o atalho **PCSX2** na Área de Trabalho.

## Outras formas de executar

**Sem instalar o Parsec** (se você só quer o emulador):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/void75028-max/parsautona2/main/pcsx2-nightly.ps1 | iex))) -PularParsec
```

**Sem aplicar o Modo Desempenho** (veja o aviso abaixo):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/void75028-max/parsautona2/main/pcsx2-nightly.ps1 | iex))) -PularDesempenho
```

**Instalar em outra pasta:**

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/void75028-max/parsautona2/main/pcsx2-nightly.ps1 | iex))) -Pasta "D:\Jogos\PCSX2"
```

Você pode juntar as opções, por exemplo: `-PularParsec -PularDesempenho`.

## O que será instalado

- O emulador PCSX2 (sempre a versão mais nova).
-   o jogo e as configurações, já prontos para usar.
- O Parsec, para transmitir o jogo.
- Um driver de controle virtual (ViGEmBus), para usar controles pelo Parsec.
- Dois atalhos na Área de Trabalho: PCSX2 e Parsec.

Tudo do emulador fica dentro de uma única pasta (`PCSX2`, dentro da sua pasta de usuário). Para remover, basta apagar essa pasta.

## Avisos importantes

**O Modo Desempenho muda configurações do Windows.** Ele deixa o computador em "alto desempenho", impede a tela de apagar e o PC de dormir (quando está na tomada) e libera a pasta do PCSX2 no antivírus do Windows. Isso gasta mais energia  
caso não queira  use `-PularDesempenho`.
- Funciona diferente em cada PC. Em alguns, uma ou outra parte não é aplicada  

**Reinicie o PC  

**Pode demorar.** O jogo é um arquivo grande. Se a internet estiver lenta, o download leva um bom tempo. Não feche a janela.






