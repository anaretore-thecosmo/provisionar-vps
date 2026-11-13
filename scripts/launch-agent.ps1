# Launcher universal: uma aba = um projeto + um agente.
# Nunca altera a VPS, e nunca executa automaticamente comandos como root.
param(
    [Parameter(Mandatory=$true)][string]$Manifest,
    [Parameter(Mandatory=$true)][string]$ProjectId,
    [Parameter(Mandatory=$true)][ValidateSet('codex','claude')][string]$AgentId
)
$ErrorActionPreference = 'Stop'
try {
    $config = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
    $project = @($config.projects | Where-Object { $_.id -ceq $ProjectId })
    if ($project.Count -ne 1) { throw "Projeto não encontrado ou duplicado: $ProjectId" }
    $p = $project[0]
    if ($null -eq $p.agents.PSObject.Properties[$AgentId]) { throw 'Agente não habilitado neste projeto' }
    $executable = if ($AgentId -eq 'claude') { 'claude' } else { 'codex' }
    Write-Host "PERFIL: $AgentId | $($p.name) | $($p.location)" -ForegroundColor Cyan
    if ($p.sensitivity -eq 'sensitive') {
        Write-Host 'AMBIENTE SENSÍVEL: não enviar dados pessoais/credenciais aos modelos.' -ForegroundColor Yellow
    }
    if ($p.location -eq 'local') {
        if (-not (Test-Path -LiteralPath $p.workdir -PathType Container)) { throw 'Diretório local ausente; revise o manifesto' }
        if (-not (Get-Command $executable -ErrorAction SilentlyContinue)) { throw "Instale e autentique $executable antes de abrir a aba" }
        Set-Location -LiteralPath $p.workdir
        & $executable
    } elseif ($p.location -eq 'ssh') {
        if ($p.ssh_alias -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,80}$') { throw 'Alias SSH inválido' }
        if ($p.workdir -cnotmatch '^/[a-zA-Z0-9_./-]+$' -or $p.workdir.Split('/') -contains '..') { throw 'Caminho remoto inseguro' }
        if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) { throw 'Cliente SSH ausente' }
        # Trust on first use NÃO é automatizado; fingerprint deve ser verificado antes.
        $remoteCommand = "cd -- '$($p.workdir)' && exec $executable"
        & ssh -tt -o BatchMode=yes -o StrictHostKeyChecking=yes $p.ssh_alias $remoteCommand
        if ($LASTEXITCODE -ne 0) { throw "Falha SSH ou $executable remoto indisponível (código $LASTEXITCODE)" }
    } else { throw 'Modo inválido (local ou ssh)' }
} catch {
    Write-Host "ABERTURA BLOQUEADA: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
