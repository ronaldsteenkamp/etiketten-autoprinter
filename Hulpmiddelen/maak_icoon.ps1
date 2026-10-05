# Maakt Etiketten_autoprinter.ico (16 t/m 256 px) en ui\icoon.png uit de
# SVG-ontwerpen in deze map:
#   icoon.svg        - vliegend etiket met barcode (32 px en groter)
#   icoon-klein.svg  - vereenvoudigd (16-24 px), blijft herkenbaar
# De SVG's worden met Microsoft Edge (headless) op 512 px gerenderd en daarna
# met hoge kwaliteit verkleind.
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$hier = $PSScriptRoot
$doel = [IO.Path]::GetFullPath((Join-Path $hier '..\Etiketten_autoprinter.ico'))
$png = [IO.Path]::GetFullPath((Join-Path $hier '..\ui\icoon.png'))

$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw "Microsoft Edge niet gevonden" }

function Render([string]$Svg, [int]$Px) {
    $tmp = Join-Path $env:TEMP ("icoon_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $tmp | Out-Null
    $html = Join-Path $tmp 'i.html'
    $uri = ([Uri](Resolve-Path $Svg).Path).AbsoluteUri
    "<html><body style='margin:0;background:transparent'><img src='$uri' style='width:${Px}px;height:${Px}px;display:block'></body></html>" | Set-Content $html -Encoding UTF8
    $uit = Join-Path $tmp 'i.png'
    $args = @('--headless', '--disable-gpu', '--hide-scrollbars', "--user-data-dir=$tmp\profiel",
        '--default-background-color=00000000', "--window-size=$Px,$Px", "--screenshot=$uit", ([Uri]$html).AbsoluteUri)
    Start-Process $edge -ArgumentList $args -Wait -WindowStyle Hidden
    if (-not (Test-Path $uit)) { throw "Renderen mislukt: $Svg" }
    $b = [System.Drawing.Bitmap]::FromFile($uit)
    $kopie = New-Object System.Drawing.Bitmap $b
    $b.Dispose()
    Remove-Item $tmp -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    return $kopie
}

function Verklein($Bron, [int]$s) {
    $b = New-Object System.Drawing.Bitmap $s, $s
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'; $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($Bron, (New-Object System.Drawing.Rectangle 0, 0, $s, $s))
    $g.Dispose()
    return $b
}

# Kleine maten als klassieke 32-bit bitmap (werkt overal), 256 als PNG.
function AlsDib($b) {
    $s = $b.Width
    $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
    $w.Write([UInt32]40); $w.Write([Int32]$s); $w.Write([Int32]($s * 2)); $w.Write([UInt16]1); $w.Write([UInt16]32)
    $w.Write([UInt32]0); $w.Write([UInt32]0); $w.Write([Int32]0); $w.Write([Int32]0); $w.Write([UInt32]0); $w.Write([UInt32]0)
    for ($y = $s - 1; $y -ge 0; $y--) {
        for ($x = 0; $x -lt $s; $x++) { $c = $b.GetPixel($x, $y); $w.Write([byte]$c.B); $w.Write([byte]$c.G); $w.Write([byte]$c.R); $w.Write([byte]$c.A) }
    }
    $rij = [int]([Math]::Ceiling($s / 32.0) * 4)
    [byte[]]$masker = New-Object byte[] ($rij * $s)   # AND-masker (leeg: alfa bepaalt)
    $w.Write($masker, 0, $masker.Length)
    $w.Flush()
    return , ([byte[]]$ms.ToArray())
}

$groot = Render (Join-Path $hier 'icoon.svg') 512
$klein = Render (Join-Path $hier 'icoon-klein.svg') 512

$maten = 16, 20, 24, 32, 40, 48, 64, 128, 256
$data = @()
foreach ($s in $maten) {
    $b = Verklein $(if ($s -le 24) { $klein } else { $groot }) $s
    if ($s -ge 256) {
        $ms = New-Object IO.MemoryStream
        $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $b.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
        $data += , ($ms.ToArray())
    } else {
        $data += , (AlsDib $b)
    }
    $b.Dispose()
}
$groot.Dispose(); $klein.Dispose()

$out = New-Object IO.MemoryStream; $bw = New-Object IO.BinaryWriter $out
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$maten.Count)
$off = 6 + 16 * $maten.Count
for ($i = 0; $i -lt $maten.Count; $i++) {
    $s = $maten[$i]; $bb = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$bb); $bw.Write([byte]$bb); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([UInt16]1); $bw.Write([UInt16]32)
    $bw.Write([UInt32]$data[$i].Length); $bw.Write([UInt32]$off); $off += $data[$i].Length
}
foreach ($p in $data) { [byte[]]$pb = $p; $bw.Write($pb, 0, $pb.Length) }
$bw.Flush()
[IO.File]::WriteAllBytes($doel, $out.ToArray())
"Icoon geschreven: $doel"
"Voorbeeld: $png"
