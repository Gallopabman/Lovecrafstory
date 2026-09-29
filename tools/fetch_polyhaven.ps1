# Descarga modelos CC0 de Poly Haven (glTF 1K) a assets/models/props/polyhaven/<id>/.
# Para el look PS1 solo se usa la textura de color: se reduce a 256 px y las demás
# (normal, rugosidad, AO) se reemplazan por imágenes de 4x4 para no inflar el repo.
# Uso: powershell -File tools/fetch_polyhaven.ps1 [-Ids id1,id2,...]
param([string[]]$Ids = @(
	"metal_office_desk", "SchoolChair_01", "plastic_monobloc_chair_01", "modern_arm_chair_01",
	"steel_frame_shelves_01", "worn_metal_rack", "wooden_bookshelf_worn", "ClassicNightstand_01",
	"vintage_wooden_drawer_01", "cardboard_box_01", "wooden_crate_01", "metal_trash_can", "trashbag",
	"Sofa_01", "ArmChair_01", "CoffeeTable_01", "WoodenTable_03", "side_table_01", "Television_01",
	"television_02", "potted_plant_04", "portable_generator", "barrel_stove", "scandinavian_masonry_heater",
	"boombox", "vintage_microwave", "electric_stove", "old_bed_frame", "vintage_day_bed", "wheelchair_01",
	"medical_box", "mounted_fluorescent_lights", "WetFloorSign_01", "wall_clock", "security_camera_01",
	"desk_lamp_arm_01", "wooden_broom", "drawer_cabinet"
))

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Join-Path $PSScriptRoot "..\assets\models\props\polyhaven"
New-Item -ItemType Directory -Force $root | Out-Null

function Save-Resized([string]$path, [int]$size) {
	$src = [System.Drawing.Image]::FromFile($path)
	$w = [Math]::Min($size, $src.Width); $h = [Math]::Max(1, [int]($src.Height * $w / $src.Width))
	$bmp = New-Object System.Drawing.Bitmap $w, $h
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.InterpolationMode = "HighQualityBicubic"
	$g.DrawImage($src, 0, 0, $w, $h)
	$g.Dispose(); $src.Dispose()
	$format = if ($path.EndsWith(".png")) { [System.Drawing.Imaging.ImageFormat]::Png } else { [System.Drawing.Imaging.ImageFormat]::Jpeg }
	$bmp.Save($path, $format); $bmp.Dispose()
}

foreach ($id in $Ids) {
	$dir = Join-Path $root $id
	if (Test-Path (Join-Path $dir "$id.gltf")) { Write-Output "ya está: $id"; continue }
	try {
		$files = Invoke-RestMethod -UseBasicParsing "https://api.polyhaven.com/files/$id"
		$entry = $files.gltf."1k".gltf
		New-Item -ItemType Directory -Force $dir | Out-Null
		Invoke-WebRequest -UseBasicParsing $entry.url -OutFile (Join-Path $dir "$id.gltf")
		foreach ($inc in $entry.include.PSObject.Properties) {
			$out = Join-Path $dir $inc.Name
			New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
			Invoke-WebRequest -UseBasicParsing $inc.Value.url -OutFile $out
			if ($inc.Name -match "\.(jpg|png)$") {
				if ($inc.Name -match "_diff_") { Save-Resized $out 256 } else { Save-Resized $out 4 }
			}
		}
		Write-Output "ok: $id"
	} catch {
		Write-Output "ERROR $id : $_"
	}
}
