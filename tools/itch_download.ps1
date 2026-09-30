# Descarga los archivos de un pack gratuito ("name your price") de itch.io, con el mismo
# flujo que el botón "No thanks, just take me to the downloads" (sin cuenta).
# Uso: powershell -File tools/itch_download.ps1 -User quaternius -Slug downtown-city-megakit -Out <carpeta> [-Filter <regex>]
# Sin -Out solo lista los archivos disponibles.
param(
	[Parameter(Mandatory)] [string]$User,
	[Parameter(Mandatory)] [string]$Slug,
	[string]$Out = "",
	[string]$Filter = "."
)
$ErrorActionPreference = "Stop"
$base = "https://$User.itch.io/$Slug"
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$purchase = Invoke-WebRequest -UseBasicParsing -WebSession $session "$base/purchase"
$token = [regex]::Match($purchase.Content, 'name="csrf_token" value="([^"]*)"').Groups[1].Value
$resp = Invoke-WebRequest -UseBasicParsing -WebSession $session -Method Post -Body @{ csrf_token = $token } "$base/download_url"
$downloadPage = ($resp.Content | ConvertFrom-Json).url
$page = (Invoke-WebRequest -UseBasicParsing -WebSession $session $downloadPage).Content
$uploads = [regex]::Matches($page, 'data-upload_id="(\d+)"[\s\S]{0,600}?title="([^"]*)"[\s\S]{0,300}?file_size"><span>([^<]*)')
foreach ($u in $uploads) {
	$id = $u.Groups[1].Value; $name = $u.Groups[2].Value; $size = $u.Groups[3].Value
	Write-Output "UPLOAD $id | $name | $size"
	if ($Out -and $name -match $Filter) {
		New-Item -ItemType Directory -Force $Out | Out-Null
		$file = Invoke-WebRequest -UseBasicParsing -WebSession $session -Method Post -Body @{ csrf_token = $token } "$base/file/${id}?source=game_download"
		$url = ($file.Content | ConvertFrom-Json).url
		# Los corchetes ("[Standard]") son comodines para PowerShell: se reemplazan.
		$target = Join-Path $Out ($name -replace '[\[\]]', '_')
		Invoke-WebRequest -UseBasicParsing $url -OutFile $target
		Write-Output "  descargado: $target"
	}
}
