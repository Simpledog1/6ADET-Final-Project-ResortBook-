<#
  Backend integration test for the double-booking guard in pocketbase/pb_hooks.

  Starts a THROWAWAY PocketBase (its own temporary data folder, port 8097),
  imports pocketbase/pb_schema.json, loads pocketbase/pb_hooks, creates test
  records with made-up data, and sends real HTTP requests to the API, including
  simultaneous ones. It never touches your real pb_data.

  Usage (PowerShell, from the project folder):
    powershell -ExecutionPolicy Bypass -File pocketbase\tests\run-overlap-tests.ps1 -PocketBaseExe "G:\ADET FINALS\pocketbase_0.40.4_windows_amd64\pocketbase.exe"

  Add -NoHooks to run the same tests WITHOUT the hook (to see what fails).
#>
param(
  [Parameter(Mandatory)][string]$PocketBaseExe,
  [int]$Port = 8097,
  [switch]$NoHooks
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http

$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$work = Join-Path ([IO.Path]::GetTempPath()) ("rb_overlap_test_" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory $work | Out-Null
$BaseUrl = "http://127.0.0.1:$Port"
$pass = 0; $fail = 0

function Check([string]$name, [bool]$ok, [string]$detail = '') {
  if ($ok) { $script:pass++; Write-Host "  PASS  $name" -ForegroundColor Green }
  else { $script:fail++; Write-Host "  FAIL  $name  $detail" -ForegroundColor Red }
}

$client = New-Object System.Net.Http.HttpClient
function Send([string]$method, [string]$path, $body, [string]$token) {
  $req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::new($method)), "$BaseUrl$path"
  if ($token) { $req.Headers.TryAddWithoutValidation('Authorization', $token) | Out-Null }
  if ($null -ne $body) {
    $json = if ($body -is [string]) { $body } else { $body | ConvertTo-Json -Depth 6 }
    $req.Content = New-Object System.Net.Http.StringContent ($json, [Text.Encoding]::UTF8, 'application/json')
  }
  return $client.SendAsync($req)
}
function Call([string]$method, [string]$path, $body, [string]$token) {
  $r = (Send $method $path $body $token).Result
  $text = $r.Content.ReadAsStringAsync().Result
  [pscustomobject]@{ Status = [int]$r.StatusCode; Json = $(if ($text) { $text | ConvertFrom-Json } else { $null }) }
}

$pb = $null
try {
  # ---- throwaway server -----------------------------------------------------
  Copy-Item $PocketBaseExe (Join-Path $work 'pocketbase.exe')
  & (Join-Path $work 'pocketbase.exe') superuser upsert su@overlap.test SuperPass12345 --dir (Join-Path $work 'pb_data') | Out-Null
  # paths are quoted because they may contain spaces
  $pbArgs = @('serve', "--http=127.0.0.1:$Port", ('--dir="{0}"' -f (Join-Path $work 'pb_data')))
  if ($NoHooks) { $hooks = Join-Path $work 'no_hooks' } else { $hooks = Join-Path $repo 'pocketbase\pb_hooks' }
  $pbArgs += ('--hooksDir="{0}"' -f $hooks)
  $pb = Start-Process (Join-Path $work 'pocketbase.exe') -ArgumentList $pbArgs -WorkingDirectory $work -PassThru -WindowStyle Hidden
  $up = $false
  for ($i = 0; $i -lt 30 -and -not $up; $i++) { try { $up = (Invoke-WebRequest "$BaseUrl/api/health" -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200 } catch { Start-Sleep -Milliseconds 500 } }
  if (-not $up) { throw "The test PocketBase did not start on port $Port." }

  $su = (Call POST '/api/collections/_superusers/auth-with-password' @{ identity = 'su@overlap.test'; password = 'SuperPass12345' } $null).Json.token
  # send the schema file as-is (a PowerShell JSON round-trip can change it)
  $schema = Get-Content (Join-Path $repo 'pocketbase\pb_schema.json') -Raw
  $imp = Call PUT '/api/collections/import' ('{"collections":' + $schema + ',"deleteMissing":false}') $su
  if ($imp.Status -ne 204 -and $imp.Status -ne 200) { throw "schema import failed: $($imp.Status)" }

  Call POST '/api/collections/users/records' @{ email = 'staff@overlap.test'; password = 'StaffPass12345'; passwordConfirm = 'StaffPass12345' } $null | Out-Null
  $tok = (Call POST '/api/collections/users/auth-with-password' @{ identity = 'staff@overlap.test'; password = 'StaffPass12345' } $null).Json.token

  $ut = (Call POST '/api/collections/unit_types/records' @{ name = 'Cottage'; defaultCapacity = 4; isActive = $true } $tok).Json
  $st = (Call POST '/api/collections/stay_types/records' @{ name = 'Overnight'; checkInTime = '14:00'; checkOutTime = '12:00'; endsNextDay = $true; allowMultipleNights = $true; pricingBasis = 'per_night'; isActive = $true } $tok).Json
  $u1 = (Call POST '/api/collections/units/records' @{ name = 'Test Cottage 1'; unitType = $ut.id; capacity = 4; isActive = $true } $tok).Json
  $u2 = (Call POST '/api/collections/units/records' @{ name = 'Test Cottage 2'; unitType = $ut.id; capacity = 4; isActive = $true } $tok).Json

  function Booking([string]$unit, [string]$start, [string]$end, [string]$status = 'Reserved', [string]$guest = 'Test Guest') {
    @{ guestName = $guest; guestCount = 2; unit = $unit; stayType = $st.id; startAt = $start; endAt = $end; status = $status }
  }
  function Create($b) { Call POST '/api/collections/reservations/records' $b $tok }
  function Patch([string]$id, $b) { Call PATCH "/api/collections/reservations/records/$id" $b $tok }

  Write-Host ""
  Write-Host ("Running against a throwaway PocketBase " + $(if ($NoHooks) { 'WITHOUT hooks' } else { 'WITH pocketbase/pb_hooks' }))

  # Existing booking: 2030-01-10 14:00 -> 2030-01-12 12:00 UTC (2 nights) on unit 1
  $base = Create (Booking $u1.id '2030-01-10 14:00:00.000Z' '2030-01-12 12:00:00.000Z')
  Check 'setup booking saved' ($base.Status -eq 200) "status $($base.Status)"

  $r = Create (Booking $u1.id '2030-01-11 14:00:00.000Z' '2030-01-12 12:00:00.000Z')
  Check 'overlapping booking is rejected (400)' ($r.Status -eq 400) "status $($r.Status)"

  $r = Create (Booking $u1.id '2030-01-12 12:00:00.000Z' '2030-01-13 12:00:00.000Z')
  Check 'back-to-back after (starts when it ends) is accepted' ($r.Status -eq 200) "status $($r.Status)"
  $r = Create (Booking $u1.id '2030-01-09 14:00:00.000Z' '2030-01-10 14:00:00.000Z')
  Check 'back-to-back before (ends when it starts) is accepted' ($r.Status -eq 200) "status $($r.Status)"

  $r = Create (Booking $u1.id '2030-01-12 11:59:00.000Z' '2030-01-12 13:00:00.000Z')
  Check 'one-minute overlap at the end is rejected' ($r.Status -eq 400) "status $($r.Status)"

  $r = Create (Booking $u1.id '2030-01-11 00:00:00.000Z' '2030-01-11 06:00:00.000Z')
  Check 'multi-night: booking in the middle night is rejected' ($r.Status -eq 400) "status $($r.Status)"

  # Cross-midnight: Night Tour-style 19:00 -> 06:00 next day on unit 2
  $night = Create (Booking $u2.id '2030-02-01 19:00:00.000Z' '2030-02-02 06:00:00.000Z')
  $r = Create (Booking $u2.id '2030-02-02 05:00:00.000Z' '2030-02-02 08:00:00.000Z')
  Check 'cross-midnight: early-morning booking overlapping a night stay is rejected' ($r.Status -eq 400) "status $($r.Status)"
  $r = Create (Booking $u2.id '2030-02-02 06:00:00.000Z' '2030-02-02 17:00:00.000Z')
  Check 'cross-midnight: day booking starting at 06:00 checkout is accepted' ($r.Status -eq 200) "status $($r.Status)"

  $r = Create (Booking $u2.id '2030-01-11 00:00:00.000Z' '2030-01-11 06:00:00.000Z')
  Check 'same time on a different unit is accepted' ($r.Status -eq 200) "status $($r.Status)"

  $canc = Create (Booking $u1.id '2030-01-11 00:00:00.000Z' '2030-01-11 06:00:00.000Z' 'Cancelled')
  Check 'a Cancelled booking inside an existing one can be saved' ($canc.Status -eq 200) "status $($canc.Status)"
  $r = Patch $canc.Json.id @{ status = 'Reserved' }
  Check 'restoring that cancelled booking (conflict) is rejected' ($r.Status -eq 400) "status $($r.Status)"

  $free = Create (Booking $u1.id '2030-03-01 14:00:00.000Z' '2030-03-02 12:00:00.000Z' 'Cancelled')
  $r = Patch $free.Json.id @{ status = 'Reserved' }
  Check 'restoring a cancelled booking whose slot is free is accepted' ($r.Status -eq 200) "status $($r.Status)"

  # Cancelled bookings do not block: cancel the base booking, then book its time
  $tmp = Create (Booking $u2.id '2030-04-01 14:00:00.000Z' '2030-04-02 12:00:00.000Z')
  Patch $tmp.Json.id @{ status = 'Cancelled' } | Out-Null
  $r = Create (Booking $u2.id '2030-04-01 14:00:00.000Z' '2030-04-02 12:00:00.000Z')
  Check 'after cancelling, the same slot can be booked again' ($r.Status -eq 200) "status $($r.Status)"

  # Editing
  $r = Patch $base.Json.id @{ notes = 'edited'; guestName = 'Edited Guest' }
  Check 'edit of guest details/notes is accepted' ($r.Status -eq 200) "status $($r.Status)"
  $r = Patch $base.Json.id @{ endAt = '2030-01-12 11:00:00.000Z' }
  Check 'edit that only overlaps itself is accepted (excludes own id)' ($r.Status -eq 200) "status $($r.Status)"
  $r = Patch $base.Json.id @{ endAt = '2030-01-12 18:00:00.000Z' }
  Check 'edit that moves into another booking is rejected' ($r.Status -eq 400) "status $($r.Status)"
  $r = Patch $base.Json.id @{ unit = $u2.id }
  Check 'edit that moves to another unit with a clash is rejected' ($r.Status -eq 400) "status $($r.Status)"

  # Status transitions are not blocked
  $r = Patch $base.Json.id @{ status = 'Checked In' }
  Check 'Check In is accepted' ($r.Status -eq 200) "status $($r.Status)"
  $r = Patch $base.Json.id @{ status = 'Completed' }
  Check 'Mark Completed is accepted' ($r.Status -eq 200) "status $($r.Status)"

  # Concurrency: pairs of simultaneous creates for the same free slot
  $slots = 20; $doubled = 0; $accepted = 0
  for ($i = 1; $i -le $slots; $i++) {
    $d = '2031-{0:00}-{1:00}' -f ([int][Math]::Ceiling($i / 28)), (($i - 1) % 28 + 1)
    $b = Booking $u1.id "$d 06:00:00.000Z" "$d 20:00:00.000Z" 'Reserved' "Race $i"
    $t1 = Send POST '/api/collections/reservations/records' $b $tok
    $t2 = Send POST '/api/collections/reservations/records' $b $tok
    [System.Threading.Tasks.Task]::WaitAll(@($t1, $t2))
    $n = @($t1.Result, $t2.Result | ? { [int]$_.StatusCode -eq 200 }).Count
    $accepted += $n; if ($n -gt 1) { $doubled++ }
  }
  Check "concurrency: $slots slots x 2 simultaneous requests -> no slot double-booked ($accepted accepted)" ($doubled -eq 0) "$doubled slots double-booked"

  # Concurrency burst: 8 simultaneous requests for ONE slot
  $b = Booking $u2.id '2031-06-15 06:00:00.000Z' '2031-06-15 20:00:00.000Z' 'Reserved' 'Burst'
  $tasks = 1..8 | % { Send POST '/api/collections/reservations/records' $b $tok }
  [System.Threading.Tasks.Task]::WaitAll($tasks)
  $okCount = @($tasks | ? { [int]$_.Result.StatusCode -eq 200 }).Count
  Check "concurrency: 8 simultaneous requests for one slot -> exactly 1 accepted (got $okCount)" ($okCount -eq 1)

  # Final state check straight from the database API
  $all = (Call GET "/api/collections/reservations/records?perPage=500&filter=status!~'cancel'" $null $su).Json.items
  $overlaps = 0
  for ($a = 0; $a -lt $all.Count; $a++) { for ($c = $a + 1; $c -lt $all.Count; $c++) {
      $x = $all[$a]; $y = $all[$c]
      if ($x.unit -eq $y.unit -and [string]$x.startAt -lt [string]$y.endAt -and [string]$x.endAt -gt [string]$y.startAt) { $overlaps++ } } }
  Check "database contains no overlapping non-cancelled reservations ($($all.Count) checked)" ($overlaps -eq 0) "$overlaps overlapping pairs"
}
finally {
  if ($pb) { Stop-Process -Id $pb.Id -Force -ErrorAction SilentlyContinue }
  $client.Dispose()
}

Write-Host ""
Write-Host "$pass passed, $fail failed  (temporary data in $work)"
if ($fail -gt 0) { exit 1 }
