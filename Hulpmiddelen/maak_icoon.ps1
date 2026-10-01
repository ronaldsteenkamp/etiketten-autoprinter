# Maakt Etiketten_autoprinter.ico (16 t/m 256 px) en een voorbeeld-PNG.
# Ontwerp: afgeronde tegel met blauw-indigo verloop en glans, een wit etiket
# (licht gedraaid, met ophanggaatje en tekstregels) en een groen vinkje.
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$doel = Join-Path $PSScriptRoot '..\Etiketten_autoprinter.ico'

function RR([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}
function C($a, $r, $g, $b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

function Teken([int]$s) {
    $bmp = New-Object System.Drawing.Bitmap $s, $s
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'; $g.InterpolationMode = 'HighQualityBicubic'
    $g.Clear([System.Drawing.Color]::Transparent)
    $k = $s / 256.0
    $klein = $s -le 24

    # --- Tegel met verloop ---
    $m = [Math]::Max(0.5, 6 * $k)
    $tegel = RR $m $m ($s - 2 * $m) ($s - 2 * $m) (54 * $k)
    $rect = New-Object System.Drawing.RectangleF 0, 0, $s, $s
    $verloop = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (C 255 56 132 255), (C 255 67 56 202), 55
    $g.FillPath($verloop, $tegel)

    # --- Glans bovenin ---
    if (-not $klein) {
        $g.SetClip($tegel)
        $gr = New-Object System.Drawing.RectangleF (-40 * $k), (-150 * $k), (336 * $k), (290 * $k)
        $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
        $gp.AddEllipse($gr)
        $glans = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.RectangleF 0, 0, $s, (140 * $k)), (C 90 255 255 255), (C 0 255 255 255), 90
        $g.FillPath($glans, $gp)
        $g.ResetClip()
        # dunne lichte rand
        $rand = New-Object System.Drawing.Pen (C 70 255 255 255), ([Math]::Max(1, 3 * $k))
        $g.DrawPath($rand, $tegel)
    }

    # --- Etiket (licht gedraaid) ---
    $st = $g.Save()
    $g.TranslateTransform(122 * $k, 124 * $k)
    $g.RotateTransform(-10)
    $ew = 150 * $k; $eh = 108 * $k
    $ex = -$ew / 2; $ey = -$eh / 2
    if (-not $klein) {
        $schaduw = RR ($ex + 4 * $k) ($ey + 10 * $k) $ew $eh (16 * $k)
        $g.FillPath((New-Object System.Drawing.SolidBrush (C 60 15 23 42)), $schaduw)
    }
    $etiket = RR $ex $ey $ew $eh (16 * $k)
    $g.FillPath((New-Object System.Drawing.SolidBrush (C 255 255 255 255)), $etiket)
    if (-not $klein) {
        # ophanggaatje
        $gat = 16 * $k
        $g.FillEllipse((New-Object System.Drawing.SolidBrush (C 255 79 70 229)), ($ex + 18 * $k), (-$gat / 2), $gat, $gat)
        # tekstregels
        $pen = New-Object System.Drawing.Pen (C 255 148 163 184), (11 * $k)
        $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
        $g.DrawLine($pen, ($ex + 50 * $k), ($ey + 30 * $k), ($ex + 128 * $k), ($ey + 30 * $k))
        $pen2 = New-Object System.Drawing.Pen (C 255 203 213 225), (11 * $k)
        $pen2.StartCap = 'Round'; $pen2.EndCap = 'Round'
        $g.DrawLine($pen2, ($ex + 50 * $k), ($ey + 56 * $k), ($ex + 108 * $k), ($ey + 56 * $k))
        $g.DrawLine($pen2, ($ex + 50 * $k), ($ey + 80 * $k), ($ex + 90 * $k), ($ey + 80 * $k))
    } else {
        $pen = New-Object System.Drawing.Pen (C 255 148 163 184), ([Math]::Max(1, 14 * $k))
        $g.DrawLine($pen, ($ex + 30 * $k), ($ey + 40 * $k), ($ex + 120 * $k), ($ey + 40 * $k))
    }
    $g.Restore($st)

    # --- Groen vinkje-badge rechtsonder ---
    $bx = 186 * $k; $by = 186 * $k; $br = $(if ($klein) { 54 } else { 50 }) * $k
    $g.FillEllipse((New-Object System.Drawing.SolidBrush (C 255 255 255 255)), ($bx - $br - 7 * $k), ($by - $br - 7 * $k), (2 * ($br + 7 * $k)), (2 * ($br + 7 * $k)))
    $bRect = New-Object System.Drawing.RectangleF ($bx - $br), ($by - $br), (2 * $br), (2 * $br)
    $groen = New-Object System.Drawing.Drawing2D.LinearGradientBrush $bRect, (C 255 52 211 153), (C 255 5 150 105), 90
    $g.FillEllipse($groen, $bRect)
    $vp = New-Object System.Drawing.Pen (C 255 255 255 255), ([Math]::Max(1.6, 15 * $k))
    $vp.StartCap = 'Round'; $vp.EndCap = 'Round'; $vp.LineJoin = 'Round'
    $pts = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF ($bx - 22 * $k), ($by + 1 * $k)),
        (New-Object System.Drawing.PointF ($bx - 6 * $k), ($by + 17 * $k)),
        (New-Object System.Drawing.PointF ($bx + 24 * $k), ($by - 15 * $k)))
    $g.DrawLines($vp, $pts)

    $g.Dispose()
    return $bmp
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

$maten = 16, 20, 24, 32, 40, 48, 64, 128, 256
$pngs = @()
foreach ($s in $maten) {
    $b = Teken $s
    if ($s -ge 256) {
        $ms = New-Object IO.MemoryStream
        $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $b.Save((Join-Path $PSScriptRoot '..\ui\icoon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
        $pngs += , ($ms.ToArray())
    } else {
        $pngs += , (AlsDib $b)
    }
    $b.Dispose()
}
$out = New-Object IO.MemoryStream; $bw = New-Object IO.BinaryWriter $out
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$maten.Count)
$off = 6 + 16 * $maten.Count
for ($i = 0; $i -lt $maten.Count; $i++) {
    $s = $maten[$i]; $b = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$b); $bw.Write([byte]$b); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([UInt16]1); $bw.Write([UInt16]32)
    $bw.Write([UInt32]$pngs[$i].Length); $bw.Write([UInt32]$off); $off += $pngs[$i].Length
}
foreach ($p in $pngs) { [byte[]]$pb = $p; $bw.Write($pb, 0, $pb.Length) }
$bw.Flush()
[IO.File]::WriteAllBytes([IO.Path]::GetFullPath($doel), $out.ToArray())
"Icoon geschreven: " + [IO.Path]::GetFullPath($doel)

