# Network Share Guide: Desktop 003 → Server

**Purpose:** Share the "RW Working FIle" folder from Desktop 003 so adwpc-main can access it

---

## Step 1: On Desktop 003 - Share the Folder

### Option A: Share via File Explorer (Easiest)

1. **Open File Explorer** on Desktop 003
2. **Navigate to** the "RW Working FIle" folder
   - Usually: `C:\Users\WPC-DESKTOP-003\OneDrive - woodyspaper.com\RW Working FIle`
   - Or: `C:\Users\WPC-DESKTOP-003\Desktop\RW Working FIle`

3. **Right-click** on "RW Working FIle" folder
4. **Select:** "Properties"
5. **Click:** "Sharing" tab
6. **Click:** "Share..." button
7. **In the sharing dialog:**
   - Select "Everyone" or "Administrator" from dropdown
   - Click "Add"
   - Set permission level to "Read" (or "Read/Write" if you want to copy files back)
   - Click "Share"
   - Note the network path (e.g., `\\DESKTOP-003\RW Working FIle`)

8. **Click:** "Advanced Sharing" button
   - Check "Share this folder"
   - Note the "Share name" (e.g., "RW Working FIle")
   - Click "Permissions"
   - Give "Everyone" or "Administrator" at least "Read" permission
   - Click "OK" twice

9. **Click:** "Network and Sharing Center" link
   - Expand "Private" network profile
   - Turn ON "Network Discovery"
   - Turn ON "File and Printer Sharing"
   - Save changes

---

### Option B: Share via PowerShell (Faster)

**On Desktop 003, run in PowerShell (as Administrator):**

```powershell
# Find the folder path
$folderPath = "C:\Users\WPC-DESKTOP-003\OneDrive - woodyspaper.com\RW Working FIle"
# Or try: $folderPath = "C:\Users\WPC-DESKTOP-003\Desktop\RW Working FIle"

# Check if folder exists
if (Test-Path $folderPath) {
    # Share the folder
    $shareName = "RWWorkingFile"
    New-SmbShare -Name $shareName -Path $folderPath -ReadAccess "Everyone"
    
    Write-Host "Folder shared as: \\$env:COMPUTERNAME\$shareName" -ForegroundColor Green
} else {
    Write-Host "Folder not found at: $folderPath" -ForegroundColor Red
    Write-Host "Please find the correct path first" -ForegroundColor Yellow
}
```

---

## Step 2: Find Desktop 003's Computer Name

**On Desktop 003, run:**

```powershell
$env:COMPUTERNAME
```

**Common names:**
- `WPC-DESKTOP-003`
- `DESKTOP-003`
- `DESKTOP003`

---

## Step 3: On adwpc-main - Access the Share

### Option A: Map Network Drive

**On adwpc-main, run in PowerShell:**

```powershell
# Replace DESKTOP-003 with actual computer name
$computerName = "DESKTOP-003"  # or "WPC-DESKTOP-003"
$shareName = "RWWorkingFile"   # or "RW Working FIle"

# Try to map the drive
$networkPath = "\\$computerName\$shareName"

# Test connection first
if (Test-Path $networkPath) {
    Write-Host "Share is accessible!" -ForegroundColor Green
    
    # Map to Z: drive
    net use Z: $networkPath /persistent:yes
    
    Write-Host "Mapped to Z: drive" -ForegroundColor Green
    Write-Host "Access at: Z:\" -ForegroundColor Cyan
} else {
    Write-Host "Cannot access: $networkPath" -ForegroundColor Red
    Write-Host "Check:" -ForegroundColor Yellow
    Write-Host "  1. Desktop 003 is on same network" -ForegroundColor White
    Write-Host "  2. Sharing is enabled" -ForegroundColor White
    Write-Host "  3. Computer name is correct" -ForegroundColor White
}
```

### Option B: Access Directly (No Mapping)

**On adwpc-main, run:**

```powershell
# Replace with actual computer name and share name
$networkPath = "\\DESKTOP-003\RWWorkingFile"

# Test access
if (Test-Path $networkPath) {
    Write-Host "Share accessible!" -ForegroundColor Green
    Get-ChildItem $networkPath | Select-Object Name
} else {
    Write-Host "Cannot access share" -ForegroundColor Red
}
```

---

## Step 4: Copy Files from Network Share

**Once share is accessible, on adwpc-main:**

```powershell
# Set paths
$networkPath = "\\DESKTOP-003\RWWorkingFile"  # Adjust computer/share name
$destPath = "c:\Users\Administrator.ADWPC-MAIN\OneDrive - woodyspaper.com\Desktop\WP_Testcode\legacy_imports"

# Create destination folders
New-Item -ItemType Directory -Path "$destPath\pricing" -Force | Out-Null
New-Item -ItemType Directory -Path "$destPath\customers" -Force | Out-Null
New-Item -ItemType Directory -Path "$destPath\tax" -Force | Out-Null
New-Item -ItemType Directory -Path "$destPath\..\legacy_docs" -Force | Out-Null

# Copy pricing files
Copy-Item "$networkPath\CounterPoint Transistion\CP Imports\IM_PRC_RUL.csv" -Destination "$destPath\pricing\" -ErrorAction SilentlyContinue
Copy-Item "$networkPath\CounterPoint Transistion\CP Imports\IM_PRC_RUL_BRK_import.csv" -Destination "$destPath\pricing\" -ErrorAction SilentlyContinue
Copy-Item "$networkPath\CounterPoint Transistion\CP Imports\IM_PRC_GRP.csv" -Destination "$destPath\pricing\" -ErrorAction SilentlyContinue

# Copy customer file
Copy-Item "$networkPath\CounterPoint Transistion\CP Imports\Customer Spreadsheet 846.xlsx" -Destination "$destPath\customers\" -ErrorAction SilentlyContinue

# Copy tax file
Copy-Item "$networkPath\CounterPoint Transistion\CP Imports\TAX_CODES_IMPORT_FL_COUNTIES.xlsx" -Destination "$destPath\tax\" -ErrorAction SilentlyContinue

# Copy documentation files
Copy-Item "$networkPath\Process Documentation\Address Guidelines.docx" -Destination "$destPath\..\legacy_docs\" -ErrorAction SilentlyContinue
Copy-Item "$networkPath\Process Documentation\Customer Pricing Discounts.xlsx" -Destination "$destPath\..\legacy_docs\" -ErrorAction SilentlyContinue

# Verify
Write-Host "`nCopied files:" -ForegroundColor Cyan
Get-ChildItem $destPath -Recurse | Select-Object Name
Get-ChildItem "$destPath\..\legacy_docs" | Select-Object Name
```

---

## Troubleshooting

### Issue: "Cannot access network path"

**Solutions:**
1. **Check Windows Firewall:**
   ```powershell
   # On Desktop 003, allow file sharing
   Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Enabled True
   ```

2. **Check Network Discovery:**
   - On Desktop 003: Settings → Network & Internet → Network and Sharing Center
   - Turn ON "Network Discovery" and "File and Printer Sharing"

3. **Check Computer Name:**
   ```powershell
   # On Desktop 003
   $env:COMPUTERNAME
   ```

4. **Try IP Address instead:**
   ```powershell
   # On Desktop 003, get IP address
   ipconfig | Select-String "IPv4"
   
   # On adwpc-main, use IP instead of computer name
   $networkPath = "\\192.168.1.XXX\RWWorkingFile"
   ```

### Issue: "Access Denied"

**Solutions:**
1. **Use Administrator account** on both machines
2. **Check share permissions** - ensure "Everyone" or your account has Read access
3. **Try with credentials:**
   ```powershell
   net use \\DESKTOP-003\RWWorkingFile /user:Administrator
   ```

---

## Quick Test Script

**On adwpc-main, run this to test and copy:**

```powershell
# Test network share access
$computers = @("DESKTOP-003", "WPC-DESKTOP-003", "DESKTOP003")
$shareNames = @("RWWorkingFile", "RW Working FIle", "RWWorkingFIle")

$found = $false
foreach ($comp in $computers) {
    foreach ($share in $shareNames) {
        $path = "\\$comp\$share"
        Write-Host "Trying: $path" -NoNewline
        if (Test-Path $path) {
            Write-Host " ✅ FOUND!" -ForegroundColor Green
            $found = $true
            $networkPath = $path
            break
        } else {
            Write-Host " ❌" -ForegroundColor Red
        }
    }
    if ($found) { break }
}

if ($found) {
    Write-Host "`nShare is accessible at: $networkPath" -ForegroundColor Green
    Write-Host "You can now copy files from this location" -ForegroundColor Cyan
} else {
    Write-Host "`nCould not find network share" -ForegroundColor Red
    Write-Host "Make sure sharing is enabled on Desktop 003" -ForegroundColor Yellow
}
```

---

**Ready to set up the share?** Start with Step 1 on Desktop 003!
