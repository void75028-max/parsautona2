<#
  Instala em modo silencioso: VC++ Redist x64, Parsec, ViGEmBus e PCSX2 nightly (Windows x64).
  Configura PCSX2 em modo portátil com caminhos relativos (independente de usuário),
  pula o assistente inicial, escaneia jogos, baixa capas automaticamente pelo serial da ISO,
  aplica config.json do Parsec (60 FPS) reiniciando o serviço e força GPU de Alto Desempenho.
  Requer execução como Administrador.

  Uso local:  powershell -ExecutionPolicy Bypass -File .\pcsx2-nightly.ps1
  Via GitHub: irm https://raw.githubusercontent.com/void75028-max/parsautona2/main/na2_auto.ps1 | iex
 
#>
param(
    [string]$Pasta   = "$env:USERPROFILE\PCSX2",
    [string]$IniPath = '',
    [string]$IniUrl  = '',
    [switch]$PularParsec,
    [switch]$PularViGEm
)

# =====================================================================
#  CONFIGURAÇÃO: edite só esta parte. Cada item aceita até 3 mirrors.
#  O script tenta o mirror 1, depois o 2, depois o 3 (para no primeiro que funcionar).
#  Deixe '' nos mirrors que não for usar.
#  Aceita MediaFire (link da página /file/...), GitHub (/blob/ ou raw), Dropbox ou link direto.
#  Arquivos .zip e .7z são extraídos. NÃO use .rar nem MEGA.
# =====================================================================

# Configurações do emulador
$LinkIni = @(
    'https://www.mediafire.com/file/mdnp9qq7v3k9nvp/inis.7z/file',   # mirror 1
    'https://github.com/void75028-max/ini/blob/main/inis.7z', # mirror 2
    ''                                                                 # mirror 3
)

# BIOS (basta o arquivo .bin da região do seu jogo)
$LinkBios = @(
    'https://www.dropbox.com/scl/fi/xcbl8ajtyhecma4i1slnk/SCPH-10000.bin?rlkey=0whh9nzwo262rpmj0phzpnuug&st=177up2it&dl=0',   # mirror 1
    'https://www.dropbox.com/scl/fi/u27kzz6vugqb57zdb42c4/SCPH-90006_BIOS_VX_HK-_220.BIN?rlkey=wxxirrxnamcgysdenm5tip0sn&st=05gff5sp&dl=0', # mirror 2
    'https://www.dropbox.com/scl/fi/4mnastrvgas4hbyhtb8z3/Sony-PlayStation-2-BIOS-E-v2.20-2006-02-10-SCPH-77008.bin?rlkey=y8a093eyqbmalxn1j1hpq5grp&st=rnr5ssxx&dl=0'   # mirror 3
)

# Jogo (ISO)
$LinkJogo = @(
    'https://www.mediafire.com/file/c6a939jh5c42vtx/1fase_linkados.ISO/file',   # mirror 1
    'https://www.dropbox.com/scl/fi/ynkb5hktktblx1wunhke7/LINKADOSSEMCHAMAR.ISO?rlkey=z4poze2mikfoiwk2pdo7nt1y9&st=5lxlzn0q&dl=0',   # mirror 2
    'https://huggingface.co/datasets/nnnna2/2/resolve/main/LINKADOSSEMCHAMAR.ISO'    # mirror 3
)

# Memory card (.ps2, .zip ou .7z)
$LinkMemoryCard = @(
    'https://github.com/void75028-max/mmc/blob/main/Mcd001.7z',   # mirror 1
    'https://www.mediafire.com/file/1dvqakrg33fh7d4/Mcd001.ps2/file',   # mirror 2
    'https://huggingface.co/datasets/nnnna2/2/resolve/main/Mcd001.7z'    # mirror 3
)

# Template de URL para capas (usa ${serial} no formato SLUS-20062)
$TemplateCapaUrl = 'https://raw.githubusercontent.com/xlenore/ps2-covers/main/covers/default/${serial}.jpg'
# =====================================================================

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Verificação de privilégios
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    throw 'Abra o PowerShell como Administrador (necessário para instalar drivers e serviços do ViGEmBus e Parsec).'
}

# Junta os mirrors preenchidos no formato "link1|link2|link3"
function JuntarMirrors($links) { (@($links) | Where-Object { $_ -and $_.Trim() }) -join '|' }
$Bios = @(); $Jogos = @(); $MemoryCards = @()
$x = JuntarMirrors $LinkBios;       if ($x) { $Bios        += $x }
$x = JuntarMirrors $LinkJogo;       if ($x) { $Jogos       += $x }
$x = JuntarMirrors $LinkMemoryCard; if ($x) { $MemoryCards += $x }
if (-not $IniUrl) { $IniUrl = JuntarMirrors $LinkIni }

# Definição de diretórios internos dentro de $Pasta (Modo Portátil / Caminhos Relativos)
$PastaBios     = Join-Path $Pasta 'bios'
$PastaMemcards = Join-Path $Pasta 'memcards'
$PastaJogos    = Join-Path $Pasta 'games'
$PastaInis     = Join-Path $Pasta 'inis'
$PastaCovers   = Join-Path $Pasta 'covers'
$tmp           = Join-Path $env:TEMP 'pcsx2-setup'

New-Item -ItemType Directory -Force -Path $tmp, $Pasta, $PastaBios, $PastaMemcards, $PastaJogos, $PastaInis, $PastaCovers | Out-Null

# Ativa modo portátil no PCSX2 para que todos os caminhos relativos funcionem em qualquer usuário
New-Item -ItemType File -Force -Path (Join-Path $Pasta 'portable.txt') | Out-Null

# 1) Extrator 7-Zip: usa o instalado; senão baixa o 7zr.exe (site oficial e, se falhar, GitHub)
$sz = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $sz) {
    Write-Host 'Preparando extrator 7-Zip...' -ForegroundColor Cyan
    $szDestino = Join-Path $tmp '7zr.exe'
    $fontes = @(
        'https://www.7-zip.org/a/7zr.exe',
        'https://github.com/ip7z/7zip/releases/latest/download/7zr.exe'
    )
    foreach ($f in $fontes) {
        try {
            Invoke-WebRequest $f -OutFile $szDestino -UseBasicParsing
            if ((Get-Item $szDestino).Length -gt 100KB) { $sz = $szDestino; break }
        } catch {
            Write-Host "Não consegui baixar o 7zr de $f, tentando a próxima fonte..." -ForegroundColor Yellow
        }
    }
    if (-not $sz) { throw 'Não consegui obter o extrator 7-Zip (7zr.exe) em nenhuma fonte.' }
}

# ---- Funções de Download ----
function Baixar($url, $destDir) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    
    # Converte link blob do GitHub para raw
    $url = $url -replace '^https://github\.com/([^/]+/[^/]+)/blob/', 'https://raw.githubusercontent.com/$1/'
    
    # Converte link do Dropbox para download direto (dl=1)
    if ($url -match 'dropbox\.com') {
        $url = $url -replace '([?&])dl=0', '${1}dl=1'
    }

    if ($url -match 'mega\.nz|mega\.co\.nz') {
        throw "Link do MEGA não suportado: $url"
    }

    if ($url -match 'mediafire\.com' -and $url -notmatch '//download\d*\.mediafire\.com') {
        $html = (Invoke-WebRequest $url -UseBasicParsing -Headers @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }).Content
        if ($html -match 'data-scrambled-url="([^"]+)"') {
            $direto = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Matches[1]))
        } elseif ($html -match 'href="(https?://download[^"]+)"') {
            $direto = $Matches[1]
        } else {
            throw "Não foi possível extrair o link direto do MediaFire em: $url"
        }
        $nome = if ($url -match '/file/[^/]+/([^/?]+)') { $Matches[1] } else { [IO.Path]::GetFileName(([uri]$direto).AbsolutePath) }
    } else {
        $direto = $url
        $nome   = [IO.Path]::GetFileName(([uri]$url).AbsolutePath)
    }

    $nome = [uri]::UnescapeDataString($nome)
    if ($nome -match '\.rar$') {
        throw "Arquivos .rar não são suportados ($nome). Compacte em .zip ou .7z."
    }

    $direto = $direto -replace '\[', '%5B' -replace '\]', '%5D'
    $arq    = Join-Path $destDir $nome
    Write-Host "Baixando $nome..."
    Invoke-WebRequest $direto -OutFile $arq -UseBasicParsing

    if ($arq -match '\.zip$') {
        Expand-Archive $arq -DestinationPath $destDir -Force
        Remove-Item $arq -Force
    } elseif ($arq -match '\.7z$') {
        & $sz x $arq "-o$destDir" -y | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Falha ao extrair $nome (código $LASTEXITCODE)." }
        Remove-Item $arq -Force
    }
}

function BaixarComMirrors($entrada, $destDir) {
    $mirrors = $entrada -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $n = 0
    foreach ($m in $mirrors) {
        $n++
        try {
            Baixar $m $destDir
            return
        } catch {
            Write-Host "Mirror $n/$($mirrors.Count) falhou: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    throw "Todos os mirrors falharam para: $entrada"
}

# ---- Função para extrair Serial da ISO e baixar a Capa ----
function ObterSerialEBaixarCapa($caminhoIso, $pastaDestinoCovers, $urlTemplate) {
    try {
        # Lê os primeiros 2 MB da ISO (onde fica o SYSTEM.CNF com o BOOT2 = cdrom0:\SLUS_XXX.XX;1)
        $fs = [System.IO.File]::OpenRead($caminhoIso)
        $tamanhoLeitura = [Math]::Min(2097152, $fs.Length)
        $buffer = New-Object byte[] $tamanhoLeitura
        [void]$fs.Read($buffer, 0, $tamanhoLeitura)
        $fs.Close()

        $textoCabecalho = [System.Text.Encoding]::ASCII.GetString($buffer)
        if ($textoCabecalho -match '([A-Z]{4})_(\d{3})\.(\d{2})') {
            $serial = "$($Matches[1])-$($Matches[2])$($Matches[3])"
            $urlCapa = $urlTemplate -replace '\$\{serial\}', $serial
            $arquivoCapa = Join-Path $pastaDestinoCovers "$serial.jpg"

            Write-Host "Serial detectado para $(Split-Path $caminhoIso -Leaf): $serial. Baixando capa..." -ForegroundColor Cyan
            Invoke-WebRequest $urlCapa -OutFile $arquivoCapa -UseBasicParsing
            Write-Host "Capa salva em: $arquivoCapa" -ForegroundColor Green
        } else {
            Write-Host "Não foi possível detectar o serial PS2 na ISO: $(Split-Path $caminhoIso -Leaf)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Aviso ao baixar capa para $(Split-Path $caminhoIso -Leaf): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 2) Descobre e baixa a nightly mais recente do PCSX2
Write-Host 'Buscando a versão nightly mais recente do PCSX2...' -ForegroundColor Cyan
$rel   = (Invoke-RestMethod 'https://api.github.com/repos/PCSX2/pcsx2/releases?per_page=1' -Headers @{ 'User-Agent' = 'pcsx2-script' })[0]
$asset = $rel.assets | Where-Object { $_.name -match 'windows-x64-Qt\.7z$' -and $_.name -notmatch 'symbols' } | Select-Object -First 1
if (-not $asset) { throw 'Pacote windows-x64-Qt.7z não encontrado na release mais recente.' }
Write-Host "Versão encontrada: $($rel.tag_name)"

$arqPCSX2 = Join-Path $tmp $asset.name
Write-Host "Baixando $($asset.name)..."
Invoke-WebRequest $asset.browser_download_url -OutFile $arqPCSX2 -UseBasicParsing

Write-Host 'Extraindo PCSX2...'
& $sz x $arqPCSX2 "-o$Pasta" -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Falha ao extrair PCSX2 (código $LASTEXITCODE)." }

# 3) Aplica o PCSX2.ini com CAMINHOS RELATIVOS (independente do nome de usuário)
$destIni = Join-Path $PastaInis 'PCSX2.ini'
$origem  = $null

if ($IniPath -and (Test-Path $IniPath)) {
    $origem = $IniPath
} elseif ($PSCommandPath -and (Test-Path (Join-Path (Split-Path $PSCommandPath) 'PCSX2.ini'))) {
    $origem = Join-Path (Split-Path $PSCommandPath) 'PCSX2.ini'
}

if ((Test-Path $destIni) -and ($origem -or $IniUrl)) {
    Copy-Item $destIni "$destIni.bak" -Force
}

if ($origem) {
    Copy-Item $origem $destIni -Force
    Write-Host "PCSX2.ini aplicado de: $origem" -ForegroundColor Green
} elseif ($IniUrl) {
    try {
        BaixarComMirrors $IniUrl $PastaInis
        $sub = Join-Path $PastaInis 'inis'
        if (Test-Path $sub) {
            Move-Item (Join-Path $sub '*') $PastaInis -Force
            Remove-Item $sub -Recurse -Force
        }
        Write-Host 'Configurações (ini) baixadas e aplicadas.' -ForegroundColor Green
    } catch {
        Write-Host "Aviso: Não foi possível aplicar o ini remoto: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Garante que o PCSX2.ini exista e aplica caminhos RELATIVOS + pula Wizard inicial
if (-not (Test-Path $destIni)) {
    @"
[UI]
SetupWizardIncomplete = false
ConfirmShutdown = false

[Folders]
Bios = bios
MemoryCards = memcards
Covers = covers
Snapshots = snaps
Savestates = sstates
Logs = logs
Cheats = cheats
Textures = textures
Cache = cache

[GameList]
RecursivePaths = games
"@ | Set-Content $destIni -Encoding UTF8
} else {
    $conteudoIni = Get-Content $destIni -Raw

    # Substitui caminhos absolutos por relativos à raiz do PCSX2
    $conteudoIni = $conteudoIni -replace '(?m)^Bios\s*=.*', 'Bios = bios'
    $conteudoIni = $conteudoIni -replace '(?m)^MemoryCards\s*=.*', 'MemoryCards = memcards'
    $conteudoIni = $conteudoIni -replace '(?m)^Covers\s*=.*', 'Covers = covers'

    if ($conteudoIni -match '(?m)^RecursivePaths\s*=') {
        $conteudoIni = $conteudoIni -replace '(?m)^RecursivePaths\s*=.*', 'RecursivePaths = games'
    } elseif ($conteudoIni -match '\[GameList\]') {
        $conteudoIni = $conteudoIni -replace '\[GameList\]', "[GameList]`r`nRecursivePaths = games"
    } else {
        $conteudoIni += "`r`n[GameList]`r`nRecursivePaths = games`r`n"
    }

    # Garante que o Setup Wizard não apareça na primeira abertura
    if ($conteudoIni -match '(?m)^SetupWizardIncomplete\s*=') {
        $conteudoIni = $conteudoIni -replace '(?m)^SetupWizardIncomplete\s*=.*', 'SetupWizardIncomplete = false'
    } elseif ($conteudoIni -match '\[UI\]') {
        $conteudoIni = $conteudoIni -replace '\[UI\]', "[UI]`r`nSetupWizardIncomplete = false"
    } else {
        $conteudoIni = "[UI]`r`nSetupWizardIncomplete = false`r`n`r`n" + $conteudoIni
    }

    Set-Content $destIni $conteudoIni -Encoding UTF8
}
Write-Host 'Caminhos relativos (bios, memcards, games, covers) aplicados no PCSX2.ini.' -ForegroundColor Cyan

# 4) Download de BIOS, Jogos, Capas e Memory Cards
foreach ($u in $Bios) {
    try { BaixarComMirrors $u $PastaBios } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
}

foreach ($u in $Jogos) {
    try { BaixarComMirrors $u $PastaJogos } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
}

# Escaneia as ISOs baixadas e baixa as capas automaticamente pelo serial
Get-ChildItem -Path $PastaJogos -Filter '*.iso' -Recurse | ForEach-Object {
    ObterSerialEBaixarCapa $_.FullName $PastaCovers $TemplateCapaUrl
}

if ($MemoryCards.Count -gt 0) {
    if ((Test-Path $PastaMemcards) -and (Get-ChildItem $PastaMemcards -File -ErrorAction SilentlyContinue)) {
        $bkp = "$PastaMemcards-backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Copy-Item $PastaMemcards $bkp -Recurse
        Write-Host "Backup dos memory cards atuais salvo em: $bkp" -ForegroundColor Yellow
    }
    foreach ($u in $MemoryCards) {
        try { BaixarComMirrors $u $PastaMemcards } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
    }
}

# Procura um arquivo do Parsec (ex.: parsecd.exe) em vários lugares: pastas conhecidas,
# busca dentro de Program Files / Program Files (x86), registro do Windows e Menu Iniciar.
function AcharParsec($arquivo) {
    $bases = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432, $env:APPDATA, $env:LOCALAPPDATA) | Where-Object { $_ } | Select-Object -Unique

    # 1) locais conhecidos
    foreach ($base in $bases) {
        $c = Join-Path $base "Parsec\$arquivo"
        if (Test-Path $c) { return $c }
    }
    # 2) busca dentro de qualquer pasta "Parsec" (inclusive subpastas)
    foreach ($base in $bases) {
        $dir = Join-Path $base 'Parsec'
        if (Test-Path $dir) {
            $f = Get-ChildItem $dir -Filter $arquivo -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($f) { return $f.FullName }
        }
    }
    # 3) registro de programas instalados
    $chaves = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    foreach ($k in (Get-ItemProperty $chaves -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Parsec*' })) {
        $dirs = @($k.InstallLocation)
        if ($k.DisplayIcon) { $dirs += (Split-Path (($k.DisplayIcon -replace ',-?\d+$', '') -replace '"', '') -ErrorAction SilentlyContinue) }
        foreach ($d in ($dirs | Where-Object { $_ })) {
            $f = Join-Path $d $arquivo
            if (Test-Path $f) { return $f }
        }
    }
    # 4) atalho do Parsec no Menu Iniciar (lê para onde ele aponta)
    $ws = New-Object -ComObject WScript.Shell
    foreach ($sm in @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs")) {
        foreach ($l in (Get-ChildItem $sm -Filter 'Parsec*.lnk' -Recurse -ErrorAction SilentlyContinue)) {
            $t = $ws.CreateShortcut($l.FullName).TargetPath
            if ($t -and (Test-Path $t) -and ((Split-Path $t -Leaf) -eq $arquivo)) { return $t }
        }
    }
    return $null
}

# 5) Instalação silenciosa de dependências e aplicativos (VC++, ViGEmBus, Parsec)
function InstalarSilencioso($nome, $url, $argumentos, $jaInstalado) {
    if ($jaInstalado) {
        Write-Host "$nome já está instalado, pulando."
        return
    }
    $exe = Join-Path $tmp ([IO.Path]::GetFileName(([uri]$url).AbsolutePath))
    Write-Host "Baixando $nome..."
    Invoke-WebRequest $url -OutFile $exe -UseBasicParsing
    Write-Host "Instalando $nome em modo silencioso..."
    $p = Start-Process $exe -ArgumentList $argumentos -Wait -PassThru -WindowStyle Hidden
    
    # 0 = sucesso, 3010 = sucesso (reinicialização recomendada), 1638 = versão mais nova já instalada
    if ($p.ExitCode -notin 0, 3010, 1638) {
        throw "$nome falhou com código de saída $($p.ExitCode)."
    }
    if ($p.ExitCode -eq 3010) {
        Write-Host "$nome instalado (reinicie o PC após concluir para ativar o driver)." -ForegroundColor Yellow
    } else {
        Write-Host "$nome instalado com sucesso." -ForegroundColor Green
    }
}

if (-not $PularViGEm) {
    InstalarSilencioso 'ViGEmBus' 'https://github.com/nefarius/ViGEmBus/releases/download/v1.22.0/ViGEmBus_1.22.0_x64_x86_arm64.exe' `
        @('/exenoui', '/qn', '/norestart') ($null -ne (Get-Service 'ViGEmBus' -ErrorAction SilentlyContinue))
}

# VC++ é exigido pelo PCSX2, então instala mesmo com -PularParsec
InstalarSilencioso 'VC++ Redistributable x64' 'https://aka.ms/vs/17/release/vc_redist.x64.exe' `
    @('/install', '/quiet', '/norestart') (Test-Path "$env:SystemRoot\System32\vcruntime140_1.dll")

if (-not $PularParsec) {
    InstalarSilencioso 'Parsec' 'https://builds.parsec.app/package/parsec-windows.exe' `
        @('/silent', '/shared') ([bool](AcharParsec 'parsecd.exe'))

    # Para o serviço e processos do Parsec antes de gravar config.json para evitar que o daemon sobrescreva o arquivo
    Stop-Service -Name 'Parsec' -Force -ErrorAction SilentlyContinue
    Get-Process -Name 'parsecd', 'pservice' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # Aplica config.json do Parsec (V-Sync OFF, Constant FPS OFF, 60 FPS, Approved Apps OFF)
    $ParsecConfigObj = @(
        "See https://parsec.app/config for documentation and example. JSON must be valid before saving or file be will be erased.",
        [ordered]@{
            client_vsync         = @{ value = $false }
            encoder_constant_fps = @{ value = $false }
            encoder_fps          = @{ value = 60 }
            host_approved_apps   = @{ value = $false }
        }
    )

    $JsonTexto  = $ParsecConfigObj | ConvertTo-Json -Depth 4
    $Utf8SemBom = New-Object System.Text.UTF8Encoding $false

    foreach ($dirParsec in @((Join-Path $env:ProgramData 'Parsec'), (Join-Path $env:APPDATA 'Parsec'))) {
        New-Item -ItemType Directory -Force -Path $dirParsec | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $dirParsec 'config.json'), $JsonTexto, $Utf8SemBom)
        # Remove config.txt legado caso exista para não conflitar com config.json
        Remove-Item (Join-Path $dirParsec 'config.txt') -Force -ErrorAction SilentlyContinue
    }

    # Reinicia o serviço do Parsec para carregar o novo config.json com 60 FPS
    Start-Service -Name 'Parsec' -ErrorAction SilentlyContinue
    Write-Host 'config.json do Parsec aplicado (60 FPS) e serviço reiniciado.' -ForegroundColor Green
}

# 6) Força "Alto Desempenho" (GPU Dedicada) no Windows para PCSX2 e Parsec
$RegGpu = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
New-Item -Path $RegGpu -Force | Out-Null

$ExecutaveisAltoDesempenho = @(
    (Join-Path $Pasta 'pcsx2-qt.exe'),
    (AcharParsec 'parsecd.exe'),
    (AcharParsec 'pservice.exe')
) | Where-Object { $_ }

foreach ($exe in $ExecutaveisAltoDesempenho) {
    if (Test-Path $exe) {
        New-ItemProperty -Path $RegGpu -Name $exe -Value 'GpuPreference=2;' -PropertyType String -Force | Out-Null
        Write-Host "Definido como Alto Desempenho na GPU: $(Split-Path $exe -Leaf)" -ForegroundColor Cyan
    }
}

# 7) Criação de atalhos na Área de Trabalho
function CriarAtalho($nome, $alvo) {
    if (-not $alvo -or -not (Test-Path $alvo)) {
        Write-Host "Atalho de $nome não criado: executável não encontrado em $alvo" -ForegroundColor Yellow
        return
    }
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desktop "$nome.lnk"))
    $lnk.TargetPath       = $alvo
    $lnk.WorkingDirectory = Split-Path $alvo
    $lnk.Save()
    Write-Host "Atalho criado na Área de Trabalho: $nome" -ForegroundColor Green
}

CriarAtalho 'PCSX2' (Join-Path $Pasta 'pcsx2-qt.exe')
if (-not $PularParsec) {
    $exeParsec = AcharParsec 'parsecd.exe'
    if ($exeParsec) {
        CriarAtalho 'Parsec' $exeParsec
    } else {
        # Plano B: copia o atalho que o próprio instalador criou no Menu Iniciar
        $lnkMenu = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs") |
            ForEach-Object { Get-ChildItem $_ -Filter 'Parsec*.lnk' -Recurse -ErrorAction SilentlyContinue } | Select-Object -First 1
        if ($lnkMenu) {
            Copy-Item $lnkMenu.FullName (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Parsec.lnk') -Force
            Write-Host 'Atalho do Parsec copiado do Menu Iniciar.' -ForegroundColor Green
        } else {
            Write-Host 'Parsec não encontrado. Arquivos .exe nas pastas do Parsec (me envie esta lista):' -ForegroundColor Yellow
            Get-ChildItem @("$env:ProgramFiles\Parsec", "${env:ProgramFiles(x86)}\Parsec", "$env:APPDATA\Parsec") -Recurse -Filter *.exe -ErrorAction SilentlyContinue |
                ForEach-Object { Write-Host "  $($_.FullName)" }
        }
    }
}

# 8) Limpeza de arquivos temporários
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "`nInstalação concluída! Abra o emulador em: $Pasta\pcsx2-qt.exe" -ForegroundColor Green
