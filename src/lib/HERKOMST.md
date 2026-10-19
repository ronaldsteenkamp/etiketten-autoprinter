# Herkomst van src\lib

Bibliotheken van anderen die in de app (en de .exe) worden meegenomen. Werk deze
lijst bij als je een bestand vervangt, en controleer dan de controlewaarde.

| Bestand | Versie | Bron | Licentie | SHA-256 |
|---|---|---|---|---|
| `WebView2\WebView2.ahk` | 2.0.5 (29-04-2025, WebView2 SDK 1.0.2903.40) | thqby, [ahk2_lib](https://github.com/thqby/ahk2_lib) | MIT (`LICENSE-ahk2_lib.txt`) | `3192ab02c276e06ea4fc16524128b2ecb02bddbbade79f118f5a76d61e4604fc` |
| `Promise.ahk` | 1.0.10 (09-01-2025) | thqby, ahk2_lib | MIT | `9369562490fb509943b93fd603fa553c42347f5fbd108dacc6079ea7759a4c30` |
| `ComVar.ahk` | geen versienummer in het bestand | thqby, ahk2_lib | MIT | `4102d3bfc358b17565547aee155214367f7ea8110db1d81ccde6398054ab3215` |
| `WebView2\32bit\WebView2Loader.dll` | 1.0.3595.46 | Microsoft, NuGet-pakket [Microsoft.Web.WebView2](https://www.nuget.org/packages/Microsoft.Web.WebView2/) (`build\native\x86`) | Microsoft (zie het NuGet-pakket) | `88a23a619ee7f2f4d2e476533aeb59b6fef917baa3eecf369a1c14f7446c649c` |

Controleren (PowerShell, in `src\lib`):

```
Get-FileHash WebView2\WebView2.ahk, Promise.ahk, ComVar.ahk, WebView2\32bit\WebView2Loader.dll | Select Hash, Path
```

De app moet 32-bit blijven (Pharmacom draait op 32-bit Java), dus alleen de 32-bit
`WebView2Loader.dll`.
