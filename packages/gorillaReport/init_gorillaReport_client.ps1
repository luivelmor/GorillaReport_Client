<#
.SYNOPSIS
    1 - Instala powershell 7
    2 - Crea los directorios de gorillaReport en el cliente.
    3 - Descarga el modulo GRmodule.psm1  y el parser en python del servidor de gorilla.
    4 - Hace disponible el módulo gorillaReport.psm1 para todos los scripts de powershell.
    5 - Descarga scripts para realizar reportes.

.DESCRIPTION
    1 - Instala powershell 7

    2 - Crea los directorios de gorillaReport en el cliente. 
        En el directorio home del usuario crea un directorio llamado gorillaReport, y los subdirectorios:
        - gorillaReport\scripts: directorio para los scripts de gorillaReport
        - gorillaReport\modules: directorio para los módulos de gorillaReport
        - gorillaReport\logs: directorio para los logs de gorillaReport
        - gorillaReport\reports: directorio para los informes de gorillaReport
        - gorillaReport\temp: directorio para los archivos temporales de gorillaReport

    3 - Descarga el modulo GRmodule.psm1 del servidor gorillaserver y lo guarda en la carpeta de modules del cliente.
        Si el modulo ya existe y no coincide el hash del fichero, lo sobreescribe.  
        Tambien descarga el script en python que parsea el fichero de logs de gorilla.      

    4 - Añade la ruta del módulo gorillaReport a la variable de entorno PSModulePath. Si la ruta ya está en la variable de entorno no hace nada.
        De esta forma, el módulo estará disponible de forma global y permanente para todos los scripts de powershell.
        Con esto conseguimos que los scripts de gorillaReport puedan importar el módulo de scripts de gorillaReport, teniendo acceso a variables y funciones definidas en él.
        Variables de entorno:
        - GR_SCRIPTS_PATH: ruta de los scripts de gorillaReport
        - GR_SCRIPTS_MODULE: directorio del módulo de scripts de gorillaReport

.NOTES
    Autores: Luis Vela Morilla, Juan Antonio Fernández Ruiz
    Fecha: 2023-03-03
    Versión: 1.0
    Email:  luivelmor@us.es | juanafr@us.es
    Licencia: GNU General Public License v3.0. https://www.gnu.org/licenses/gpl-3.0.html
#>

#Gorilla Server DNS Name or IP
$gorillaserver = "https://gorillaserver"


##########################################
### 0 - añadir DNS servidor al cliente ###
##########################################
$hosts_content = Get-Content -Path "C:\Windows\System32\drivers\etc\hosts"
if( !($hosts_content -contains "10.1.21.2   gorillareport") ){
    Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "10.1.21.2   gorillareport"
    Write-Host "10.1.21.2   gorillareport -> se ha anadido al fichero \etc\hosts"    
}

#########################################
### 1 - Instala el software necesario ###
#########################################
$homedir = $env:USERPROFILE
# 1.1 - Instalamos powershell 7
If ( !(Test-Path "C:\Program Files\PowerShell\7\pwsh.exe") ) {
    # copiamos el script
    $file = "https://github.com/PowerShell/PowerShell/releases/download/v7.3.4/PowerShell-7.3.4-win-x64.msi"
    $outputFile = "$homedir\AppData\Local\Temp\PowerShell-7.3.4-win-x64.msi"
    # descargamos los ficheros
    Invoke-WebRequest -Uri $file -OutFile $outputFile
    # instalamos
    msiexec.exe /i "$homedir\AppData\Local\Temp\PowerShell-7.3.4-win-x64.msi" /qn
}
else {
    Write-Host "Powershell 7 ya esta instalado"
}


###############################################################
### 2 - Crea los directorios de gorillaReport en el cliente ###
###############################################################

# 2.1 - Crea el directorio gorillaReport
$gorillaReportDir = "gorillaReport"

if (-not (Test-Path -Path "$homedir\$gorillaReportDir" -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path "$homedir\$gorillaReportDir" -ErrorAction Stop | Out-Null
        Write-Host "Directorio $gorillaReportDir creado correctamente."
    }
    catch {
        throw "Error al crear el directorio: $_"
    }
}
else {
    Write-Host "El directorio $gorillaReportDir ya existe."
}

# 2.2 - Crea los subdirectorios de gorillaReport
$subdirectories = @("scripts", "modules", "logs", "reports", "temp")

foreach ($subdir in $subdirectories) {
    if (-not (Test-Path -Path "$homedir\$gorillaReportDir\$subdir" -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path "$homedir\$gorillaReportDir\$subdir" -ErrorAction Stop | Out-Null
            Write-Host "Directorio $homedir\$gorillaReportDir\$subdir creado correctamente."
        }
        catch {
            throw "Error al crear el directorio: $_"
        }
    }
    else {
        Write-Host "El directorio $homedir\$gorillaReportDir\$subdir ya existe."
    }
}

# 2.3 - Crea un fichero de log para gorillaReport
$log_file = "$homedir\$gorillaReportDir\logs\gorillareport.log"
if (-not (Test-Path -Path $log_file -PathType Leaf)) {
    try {
        New-Item -ItemType File -Path $log_file -ErrorAction Stop | Out-Null
        Write-Host "Archivo $log_file creado correctamente."
    }
    catch {
        throw "Error al crear el archivo: $_"
    }
}
else {
    Write-Host "El archivo $log_file ya existe."
}



###########################################################################################
### 3 - Descarga el modulo GRmodule.psm1  y el parser en python del servidor de gorilla ###
###########################################################################################

# Directorio home del usuario
$homedir = $env:USERPROFILE
# Directorio de gorillaReport
$gorillaReportDir = "gorillaReport"
# Directorio donde se guardan los modulos de gorillaReport
$gr_modules_path = "$homeDir\$gorillaReportDir\modules"
#Directorio donde se guarda el módulo GRModule.psm1
$gr_module_dir = "$gr_modules_path\GRModule"
# Nombre del modulo
$gr_module_name = "GRModule.psm1"
#path al fichero GRModule.psm1
$GRModule_path = "$gr_module_dir\$gr_module_name"

# 3.1 - Creamos directorio en el cliente para el módulo GRModule.psm1, si no existe
If (-not (Test-Path -Path $gr_module_dir -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path $gr_module_dir -ErrorAction Stop | Out-Null
        Write-Host "Directorio $gr_module_dir creado correctamente."
    }
    catch {
        throw "Error al crear el directorio: $_"
        exit 1
    }
}
else {
    Write-Host "El directorio $gr_module_dir ya existe."
}

# 3.2 - descarga de ficheros (sin certificado, AuthBasic in gorilla server)

pwsh -Command {
    # NOTA: es necesario duplicar las siguientes variables dentro del bloque pwsh -Command {...}
    #Gorilla Server DNS Name or IP
    $gorillaserver = "https://gorillaserver"
    # Directorio home del usuario
    $homedir = $env:USERPROFILE
    # Directorio de gorillaReport
    $gorillaReportDir = "gorillaReport"
    # Directorio donde se guardan los modulos de gorillaReport
    $gr_modules_path = "$homeDir\$gorillaReportDir\modules"
    #Directorio donde se guarda el módulo GRModule.psm1
    $gr_module_dir = "$gr_modules_path\GRModule"
    # Nombre del modulo
    $gr_module_name = "GRModule.psm1"
    #path al fichero GRModule.psm1
    $GRModule_path = "$gr_module_dir\$gr_module_name"

    # certificado pfx (requiere contraseña en windows ltsc)
    $pass = ConvertTo-SecureString -String 'asdf' -AsPlainText -Force
    $client_pfx_cert = Get-PfxCertificate -FilePath "C:\ProgramData\gorilla\cliente_gorillaserver.pfx" -Password $pass
    
    $HASH = ''
    If ( (Test-Path $GRModule_path) ) {
        $HASH = (Get-FileHash $GRModule_path).Hash
    }

    Write-Host "Hash del fichero $GRModule_path : $HASH"

    # si no existe el archivo ó si el hash no coincide con la plantilla del servidor
    If ($HASH -ne "a2a91f5e93d9529c956e0211ad446408ce425c29a1903b05566bd2c27492d701") {
        $file = "$gorillaserver/packages/gorillaReport/modules/GRModule/GRModule.psm1"       
        Invoke-WebRequest -Uri $file -OutFile $GRModule_path -Certificate $client_pfx_cert
    }
    else {
        Write-Host "El fichero $GRModule_path ya existe y no es necesario descargarlo."
    }

    # 3.3 - descarga scripts de python (parser)
    If (!(Test-Path "$gr_modules_path\python_gorilla_parser")) {
        New-Item -ItemType Directory -Path "$gr_modules_path\python_gorilla_parser" -ErrorAction Stop | Out-Null
        Write-Host "Directorio " + "$gr_modules_path\python_gorilla_parser" + "creado correctamente."
    }
    else {
        Write-Host "El directorio " + "$gr_modules_path\python_gorilla_parser" + " ya existe."
    }

    # descargamos los ficheros
    $file1 = "$gorillaserver/packages/gorillaReport/modules/python_gorilla_parser/main.py"
    $outputFile1 = "$homedir\gorillaReport\modules\python_gorilla_parser\main.py"

    $file2 = "$gorillaserver/packages/gorillaReport/modules/python_gorilla_parser/my_functions.py"
    $outputFile2 = "$homedir\gorillaReport\modules\python_gorilla_parser\my_functions.py"

    if (!(Test-Path $file1)) { Invoke-WebRequest -Uri $file1 -OutFile $outputFile1 -Certificate $client_pfx_cert }
    if (!(Test-Path $file2)) { Invoke-WebRequest -Uri $file2 -OutFile $outputFile2 -Certificate $client_pfx_cert }
}


#############################################################################################
### 4 - Hace disponible el módulo gorillaReport.psm1 para todos los scripts de powershell ###
#############################################################################################

# home de usuario
$homedir = $env:USERPROFILE
# directorio de gorillaReport
$gorillaReportDir = "gorillaReport"
# directorio de módulos de gorillaReport
$gr_module_path = "$homeDir\$gorillaReportDir\modules"


# 4.1 - Verificar si el archivo de perfil existe
if (!(Test-Path $PROFILE)) {
    # Si el archivo de perfil no existe, crearlo
    New-Item -ItemType File -Path $PROFILE -Force
}

# 4.2 - Agregar el directorio personalizado a la variable PSModulePath
if (-not ($env:PSModulePath -split ';' | Select-String -SimpleMatch $gr_module_path)) {
    $env:PSModulePath += ";$gr_module_path"
    # Agregar el comando a $PROFILE para que los cambios sean permanentes
    Add-Content $PROFILE "`n`$env:PSModulePath += `";$gr_module_path`""
    # Mostrar la nueva lista de directorios de módulos
    Write-Host "La variable `$env:PSModulePath ahora contiene:`n$env:PSModulePath"
}
else {
    Write-Host "La variable `$env:PSModulePath ya contiene $gr_module_path :`n$env:PSModulePath"
}
#Cualquier script puede importar el módulo GRmodule.psm1 con el siguiente comando:
#Import-Module GRModule

###################################################
### 5 - Descarga scripts para realizar reportes ###
###################################################

pwsh -Command {
    # NOTA: es necesario duplicar las siguientes variables dentro del bloque pwsh -Command {...}
    #Gorilla Server DNS Name or IP
    $gorillaserver = "https://gorillaserver"
    # home de usuario
    $homedir = $env:USERPROFILE

    # certificado pfx (requiere contraseña en windows ltsc)
    $pass = ConvertTo-SecureString -String 'asdf' -AsPlainText -Force
    $client_pfx_cert = Get-PfxCertificate -FilePath "C:\ProgramData\gorilla\cliente_gorillaserver.pfx" -Password $pass
    
    $file1 = "$gorillaserver/packages/gorillaReport/scripts/register_gorilla_report.ps1"
    $outputFile1 = "$homedir\gorillaReport\scripts\register_gorilla_report.ps1"

    $file2 = "$gorillaserver/packages/gorillaReport/scripts/register_client.ps1"
    $outputFile2 = "$homedir\gorillaReport\scripts\register_client.ps1"

    $file3 = "$gorillaserver/packages/gorillaReport/scripts/send_report_pwsh7.ps1"
    $outputFile3 = "$home\gorillaReport\scripts\send_report_pwsh7.ps1"

    $file4 = "$gorillaserver/packages/gorillaReport/scripts/register_basic_info.ps1"
    $outputFile4 = "$homedir\gorillaReport\scripts\register_basic_info.ps1"

    $file5 = "$gorillaserver/packages/gorillaReport/scripts/gorilla_report.ps1"
    $outputFile5 = "$homedir\gorillaReport\scripts\gorilla_report.ps1"

    if (!(Test-Path $outputFile1)) { Invoke-WebRequest -Uri $file1 -OutFile $outputFile1 -Certificate $client_pfx_cert}
    if (!(Test-Path $outputFile2)) { Invoke-WebRequest -Uri $file2 -OutFile $outputFile2 -Certificate $client_pfx_cert}
    if (!(Test-Path $outputFile3)) { Invoke-WebRequest -Uri $file3 -OutFile $outputFile3 -Certificate $client_pfx_cert}
    if (!(Test-Path $outputFile4)) { Invoke-WebRequest -Uri $file4 -OutFile $outputFile4 -Certificate $client_pfx_cert}
    if (!(Test-Path $outputFile5)) { Invoke-WebRequest -Uri $file5 -OutFile $outputFile5 -Certificate $client_pfx_cert}
}

Start-Sleep -Seconds 5
