#Requires -Version 5.1

function Invoke-WinstBrowserClickStep {
    <#
    .SYNOPSIS
        在无头浏览器里按一步 click 规则定位元素并点击；返回 @{ Clicked; Skipped; Error }。
    .DESCRIPTION
        候选元素由页面脚本列出（a / button / input / [role=button] / [id] / [class] 且不是 display:none），
        匹配沿用 link 的同一套规则。
        命中多个时**按面积从小到大**试：小的更具体（按钮里的文字节点常包在按钮内），
        点之前先 scrollIntoView 并确认「该坐标上真的是它或它的子元素」（被别的图层挡住就换下一个候选）。
    #>
    param($Session, $Spec)

    $probeExpression = @'
(() => {
  var base = "a, button, input, [role=button], [id], [class]";
  var nodes = Array.prototype.slice.call(document.querySelectorAll(base));
  window.__winstClickables = nodes;
  var out = [];
  for (var i = 0; i < nodes.length; i++) {
    var el = nodes[i];
    var style = window.getComputedStyle(el);
    if (!style || style.display === "none" || style.visibility === "hidden") { continue; }
    var rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) { continue; }
    out.push({
      i: i,
      tag: el.tagName,
      id: el.id || "",
      cls: (typeof el.className === "string" ? el.className : ""),
      text: (el.textContent || "").replace(/\s+/g, " ").trim().slice(0, 120),
      href: (typeof el.href === "string" ? el.href : ""),
      area: Math.round(rect.width) * Math.round(rect.height)
    });
  }
  return JSON.stringify(out);
})()
'@

    $raw = Get-WinstDevToolsValue -Session $Session -Expression $probeExpression
    $candidates = @()
    if ($raw) {
        # 注意：不能写成 @($raw | ConvertFrom-Json)——ConvertFrom-Json 把整个数组当**一个**对象写进管道，
        # 外层 @() 只是把它包起来，于是「候选列表」变成 1 个元素（那个数组本身），
        # 后续 $candidate.id 会触发成员枚举、把整页的 id 拼成一串，匹配结果全错。
        $parsed = $null
        try { $parsed = $raw | ConvertFrom-Json } catch { $parsed = $null }
        if ($null -ne $parsed) { $candidates = @($parsed) }
    }
    if ($candidates.Count -eq 0) { return @{ Clicked = $false; Skipped = $true; Error = '页面上没有可点的元素' } }

    $matched = @()
    foreach ($candidate in $candidates) {
        $anchor = @{
            Href  = [string]$candidate.href
            Class = [string]$candidate.cls
            Id    = [string]$candidate.id
            Text  = [string]$candidate.text
        }
        if (Test-AnchorMatches -Anchor $anchor -Spec $Spec) { $matched += $candidate }
    }
    if ($matched.Count -eq 0) { return @{ Clicked = $false; Skipped = $true; Error = '没有元素符合条件' } }

    $ordered = @($matched | Sort-Object -Property @{ Expression = { [int]$_.area } })
    $blocked = ''
    foreach ($candidate in $ordered) {
        $index = [int]$candidate.i
        $clickExpression = @"
(() => {
  var el = (window.__winstClickables || [])[$index];
  if (!el) { return JSON.stringify({ ok: false, reason: '元素已不在页面上' }); }
  // 滚动必须用 instant：页面若开了平滑滚动（scroll-behavior: smooth），动画期间量到的坐标是旧的，
  // 等鼠标事件发过去时按钮已经挪走，点中的就是别的元素（如 Google 下载页会点到旁边的折叠面板）
  try { el.scrollIntoView({ block: 'center', inline: 'center', behavior: 'instant' }); }
  catch (e) { try { el.scrollIntoView({ block: 'center', inline: 'center' }); } catch (e2) { } }
  var rect = el.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) { return JSON.stringify({ ok: false, reason: '元素没有尺寸' }); }
  var x = rect.left + rect.width / 2;
  var y = rect.top + rect.height / 2;
  if (x < 1 || y < 1 || x > window.innerWidth - 1 || y > window.innerHeight - 1) { return JSON.stringify({ ok: false, reason: '元素不在可视区域内' }); }
  var hit = document.elementFromPoint(x, y);
  var reachable = (hit === el) || (hit && el.contains(hit));
  if (!reachable) {
    var info = hit ? (hit.tagName + '#' + (hit.id || '') + '.' + String(hit.className || '').slice(0, 40)) : '';
    return JSON.stringify({ ok: false, reason: '该坐标上被其它元素挡住：' + info });
  }
  return JSON.stringify({ ok: true, x: x, y: y });
})()
"@
        $prepared = Get-WinstDevToolsValue -Session $Session -Expression $clickExpression
        $target = $null
        if ($prepared) { try { $target = $prepared | ConvertFrom-Json } catch { $target = $null } }
        if ($null -eq $target -or -not $target.ok) {
            if ($target -and $target.reason) { $blocked = [string]$target.reason }
            continue
        }

        $x = [double]$target.x
        $y = [double]$target.y
        if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
            Write-Host ('  [verbose] 点击 <{0}#{1}>「{2}」于 {3},{4}' -f $candidate.tag, $candidate.id, ([string]$candidate.text), [int]$x, [int]$y) -ForegroundColor DarkGray
        }
        $null = Invoke-WinstDevToolsCommand -Session $Session -Method 'Input.dispatchMouseEvent' -Params @{ type = 'mouseMoved'; x = $x; y = $y }
        $null = Invoke-WinstDevToolsCommand -Session $Session -Method 'Input.dispatchMouseEvent' -Params @{ type = 'mousePressed'; x = $x; y = $y; button = 'left'; clickCount = 1 }
        $null = Invoke-WinstDevToolsCommand -Session $Session -Method 'Input.dispatchMouseEvent' -Params @{ type = 'mouseReleased'; x = $x; y = $y; button = 'left'; clickCount = 1 }
        return @{ Clicked = $true; Skipped = $false; Error = '' }
    }

    return @{ Clicked = $false; Skipped = $true; Error = $blocked }
}
