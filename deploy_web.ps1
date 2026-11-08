# deploy_web.ps1 - Automated build and deployment to live GitHub Pages URL
Write-Host "Building Flutter Web with --pwa-strategy=none --base-href /Vitaly/..." -ForegroundColor Cyan
flutter build web --pwa-strategy=none --base-href /Vitaly/ --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter web build failed!" -ForegroundColor Red
    exit 1
}

$timestamp = Get-Date -Format 'yyyyMMddHHmmss'
Write-Host "Applying cache busting timestamp v$timestamp..." -ForegroundColor Cyan

# 1. Update index.html
$indexPath = "build\web\index.html"
if (Test-Path $indexPath) {
    $content = Get-Content -Path $indexPath -Raw
    $content = $content -replace 'flutter_bootstrap\.js(\?v=[0-9]+)?', "flutter_bootstrap.js?v=$timestamp"
    Set-Content -Path $indexPath -Value $content -Encoding UTF8
}

# 2. Update flutter_bootstrap.js to cache-bust main.dart.js
$bootstrapPath = "build\web\flutter_bootstrap.js"
if (Test-Path $bootstrapPath) {
    $bContent = Get-Content -Path $bootstrapPath -Raw
    $bContent = $bContent -replace 'main\.dart\.js(\?v=[0-9]+)*', "main.dart.js?v=$timestamp"
    Set-Content -Path $bootstrapPath -Value $bContent -Encoding UTF8
}

# 3. Create a self-killing dummy service worker so old cached mobile service workers immediately self-destruct
$killerSw = @'
self.addEventListener('install', function(e) { self.skipWaiting(); });
self.addEventListener('activate', function(e) {
  self.registration.unregister().then(function() {
    return self.clients.matchAll();
  }).then(function(clients) {
    clients.forEach(client => client.navigate(client.url));
  });
});
'@
Set-Content -Path "build\web\flutter_service_worker.js" -Value $killerSw -Encoding UTF8

Write-Host "Ensuring vercel.json rewrite is in build/web..." -ForegroundColor Cyan
$vercelConfig = '{"cleanUrls": true, "rewrites": [{"source": "/(.*)", "destination": "/index.html"}]}'
Set-Content -Path "build\web\vercel.json" -Value $vercelConfig -Encoding UTF8

Write-Host "Pushing to GitHub Pages..." -ForegroundColor Cyan
Set-Location -Path "build\web"
git config user.name "rekarit"
git config user.email "rekar@users.noreply.github.com"
git add -A
git commit -m "Deploy latest updates with cache busting v$timestamp"
git push origin gh-pages
Set-Location -Path "..\.."

Write-Host "Successfully deployed to https://rekarit.github.io/Vitaly/" -ForegroundColor Green
